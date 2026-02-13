import SceneKit

// MARK: - I2: Test Coverage Heatmap Visualization

struct TestCoverageVisualizationBuilder {

    // MARK: - Coverage Map

    static func buildCoverageMap(report: TestCoverageReport) -> SCNNode {
        let container = SCNNode()
        container.name = "testCoverageVisualization"

        let fileCoverages = Array(report.fileCoverages.prefix(20))
        guard !fileCoverages.isEmpty else { return container }

        // Build 3D heatmap columns
        let spacing: Float = 0.6
        let totalWidth = Float(fileCoverages.count - 1) * spacing
        let startX = -totalWidth / 2.0

        for (i, file) in fileCoverages.enumerated() {
            let columnNode = buildCoverageColumn(file: file, index: i, total: fileCoverages.count)
            columnNode.position = SCNVector3(startX + Float(i) * spacing, 0, 0)
            container.addChildNode(columnNode)
        }

        // Overall coverage indicator
        let overallNode = buildOverallCoverageIndicator(report: report)
        overallNode.position = SCNVector3(0, 3.0, 0)
        container.addChildNode(overallNode)

        // Base platform
        let baseWidth = CGFloat(totalWidth + 2.0)
        let basePlane = SCNBox(width: baseWidth, height: 0.03, length: 1.0, chamferRadius: 0.01)
        let baseMat = SCNMaterial()
        baseMat.diffuse.contents = NSColor(hex: "#30363D").withAlphaComponent(0.5)
        baseMat.emission.contents = NSColor(hex: "#30363D")
        baseMat.emission.intensity = 0.1
        basePlane.materials = [baseMat]
        let baseNode = SCNNode(geometry: basePlane)
        baseNode.position = SCNVector3(0, -0.02, 0)
        container.addChildNode(baseNode)

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 80.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    // MARK: - Coverage Column

    private static func buildCoverageColumn(file: FileCoverage, index: Int, total: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "coverageColumn_\(file.id.uuidString)"

        // Column height based on lines of code (normalized)
        let maxHeight: Float = 2.5
        let minHeight: Float = 0.3
        let normalizedHeight = min(maxHeight, max(minHeight, Float(file.totalLines) / 500.0 * maxHeight))

        // Covered portion (bottom part, green-ish)
        let coveredHeight = normalizedHeight * Float(file.coverage)
        if coveredHeight > 0.01 {
            let coveredGeo = SCNBox(width: 0.4, height: CGFloat(coveredHeight), length: 0.4, chamferRadius: 0.02)
            let coveredMat = SCNMaterial()
            let coveredColor = coverageColor(file.coverage)
            coveredMat.diffuse.contents = coveredColor.withAlphaComponent(0.8)
            coveredMat.emission.contents = coveredColor
            coveredMat.emission.intensity = 0.3
            coveredGeo.materials = [coveredMat]
            let coveredNode = SCNNode(geometry: coveredGeo)
            coveredNode.position = SCNVector3(0, coveredHeight / 2, 0)
            container.addChildNode(coveredNode)
        }

        // Uncovered portion (top part, red glow)
        let uncoveredHeight = normalizedHeight - coveredHeight
        if uncoveredHeight > 0.01 {
            let uncoveredGeo = SCNBox(width: 0.4, height: CGFloat(uncoveredHeight), length: 0.4, chamferRadius: 0.02)
            let uncoveredMat = SCNMaterial()
            let redColor = NSColor(hex: "#F44336")
            uncoveredMat.diffuse.contents = redColor.withAlphaComponent(0.6)
            uncoveredMat.emission.contents = redColor
            uncoveredMat.emission.intensity = 0.5
            uncoveredGeo.materials = [uncoveredMat]
            let uncoveredNode = SCNNode(geometry: uncoveredGeo)
            uncoveredNode.position = SCNVector3(0, coveredHeight + uncoveredHeight / 2, 0)
            container.addChildNode(uncoveredNode)

            // Pulsing glow for uncovered areas
            let pulse = SCNAction.customAction(duration: 2.0) { node, elapsed in
                let t = Float(elapsed) / 2.0
                let intensity = 0.4 + 0.3 * sin(t * Float.pi * 2)
                node.geometry?.materials.first?.emission.intensity = CGFloat(intensity)
            }
            uncoveredNode.runAction(.repeatForever(pulse))
        }

        // Coverage percentage label
        let pctStr = String(format: "%.0f%%", file.coverage * 100)
        let pctLabel = buildLabel(pctStr, color: coverageColor(file.coverage), fontSize: 0.08)
        pctLabel.position = SCNVector3(0, normalizedHeight + 0.15, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        pctLabel.constraints = [billboard]
        container.addChildNode(pctLabel)

        // File name floating label
        let displayName = String(file.fileName.prefix(15))
        let nameText = SCNText(string: displayName, extrusionDepth: 0.003)
        nameText.font = NSFont(name: "Menlo", size: 0.05) ?? NSFont.monospacedSystemFont(ofSize: 0.05, weight: .regular)
        nameText.flatness = 0.3
        let nameMat = SCNMaterial()
        nameMat.diffuse.contents = NSColor(hex: "#C9D1D9")
        nameMat.emission.contents = NSColor(hex: "#C9D1D9")
        nameMat.emission.intensity = 0.15
        nameText.materials = [nameMat]
        let nameNode = SCNNode(geometry: nameText)
        let (minBound, maxBound) = nameNode.boundingBox
        let nameWidth = maxBound.x - minBound.x
        nameNode.position = SCNVector3(-nameWidth / 2, -0.15, 0)
        nameNode.scale = SCNVector3(0.5, 0.5, 0.5)
        let nameBillboard = SCNBillboardConstraint()
        nameBillboard.freeAxes = .Y
        nameNode.constraints = [nameBillboard]
        container.addChildNode(nameNode)

        // Lines of code label
        let locStr = "\(file.totalLines) loc"
        let locLabel = buildLabel(locStr, color: NSColor(hex: "#8B949E"), fontSize: 0.04)
        locLabel.position = SCNVector3(0, -0.25, 0)
        let locBillboard = SCNBillboardConstraint()
        locBillboard.freeAxes = .Y
        locLabel.constraints = [locBillboard]
        container.addChildNode(locLabel)

        // Floating bob animation
        let bobDuration = 2.5 + Double(index % 4) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }

    // MARK: - Overall Coverage Indicator

    private static func buildOverallCoverageIndicator(report: TestCoverageReport) -> SCNNode {
        let container = SCNNode()
        container.name = "overallCoverage"

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        // Overall coverage ring
        let ring = SCNTorus(ringRadius: 0.4, pipeRadius: 0.04)
        let ringMat = SCNMaterial()
        let overallColor = coverageColor(report.overallCoverage)
        ringMat.diffuse.contents = overallColor.withAlphaComponent(0.7)
        ringMat.emission.contents = overallColor
        ringMat.emission.intensity = 0.6
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = CGFloat.pi / 2
        container.addChildNode(ringNode)

        // Rotate ring
        let rotateRing = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 5.0)
        ringNode.runAction(.repeatForever(rotateRing))

        // Overall percentage text
        let overallStr = String(format: "%.1f%%", report.overallCoverage * 100)
        let overallLabel = buildLabel(overallStr, color: overallColor, fontSize: 0.15)
        overallLabel.position = SCNVector3(0, 0, 0)
        let lblBillboard = SCNBillboardConstraint()
        lblBillboard.freeAxes = .Y
        overallLabel.constraints = [lblBillboard]
        container.addChildNode(overallLabel)

        // Test stats label
        let statsStr = "\(report.passedTests)/\(report.totalTests) tests passed"
        let statsLabel = buildLabel(statsStr, color: NSColor(hex: "#8B949E"), fontSize: 0.06)
        statsLabel.position = SCNVector3(0, -0.3, 0)
        let statsBillboard = SCNBillboardConstraint()
        statsBillboard.freeAxes = .Y
        statsLabel.constraints = [statsBillboard]
        container.addChildNode(statsLabel)

        // Title
        let titleLabel = buildLabel("TEST COVERAGE", color: NSColor(hex: "#58A6FF"), fontSize: 0.08)
        titleLabel.position = SCNVector3(0, 0.5, 0)
        let titleBillboard = SCNBillboardConstraint()
        titleBillboard.freeAxes = .Y
        titleLabel.constraints = [titleBillboard]
        container.addChildNode(titleLabel)

        return container
    }

    // MARK: - Helpers

    private static func coverageColor(_ coverage: Double) -> NSColor {
        if coverage >= 0.8 { return NSColor(hex: "#4CAF50") }
        if coverage >= 0.5 { return NSColor(hex: "#FF9800") }
        return NSColor(hex: "#F44336")
    }

    private static func buildLabel(_ text: String, color: NSColor, fontSize: CGFloat) -> SCNNode {
        let scnText = SCNText(string: text, extrusionDepth: 0.01)
        scnText.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        scnText.flatness = 0.1
        scnText.firstMaterial?.diffuse.contents = color
        scnText.firstMaterial?.emission.contents = color
        scnText.firstMaterial?.emission.intensity = 0.3

        let node = SCNNode(geometry: scnText)
        let (minBound, maxBound) = node.boundingBox
        let textWidth = maxBound.x - minBound.x
        node.pivot = SCNMatrix4MakeTranslation(textWidth / 2, 0, 0)

        return node
    }
}
