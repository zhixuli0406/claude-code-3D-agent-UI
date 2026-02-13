import SceneKit

// MARK: - I3: Code Quality Complexity Graph Visualization

struct CodeQualityVisualizationBuilder {

    // MARK: - Complexity Graph

    static func buildComplexityGraph(complexities: [CodeComplexity]) -> SCNNode {
        let container = SCNNode()
        container.name = "codeQualityVisualization"

        let items = Array(complexities.prefix(15))
        guard !items.isEmpty else { return container }

        // Build 3D bar chart
        let spacing: Float = 1.2
        let totalWidth = Float(items.count - 1) * spacing
        let startX = -totalWidth / 2.0

        for (i, complexity) in items.enumerated() {
            let barNode = buildComplexityBar(complexity: complexity, index: i, total: items.count)
            barNode.position = SCNVector3(startX + Float(i) * spacing, 0, 0)
            container.addChildNode(barNode)
        }

        // Title label
        let titleLabel = buildLabel("CODE COMPLEXITY", color: NSColor(hex: "#E040FB"), fontSize: 0.15)
        titleLabel.position = SCNVector3(0, 4.0, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        titleLabel.constraints = [billboard]
        container.addChildNode(titleLabel)

        // Base platform
        let baseWidth = CGFloat(totalWidth + 2.5)
        let basePlane = SCNBox(width: baseWidth, height: 0.03, length: 1.2, chamferRadius: 0.01)
        let baseMat = SCNMaterial()
        baseMat.diffuse.contents = NSColor(hex: "#30363D").withAlphaComponent(0.5)
        baseMat.emission.contents = NSColor(hex: "#30363D")
        baseMat.emission.intensity = 0.1
        basePlane.materials = [baseMat]
        let baseNode = SCNNode(geometry: basePlane)
        baseNode.position = SCNVector3(0, -0.02, 0)
        container.addChildNode(baseNode)

        // Threshold lines (visual indicators)
        let thresholdLow = buildThresholdLine(
            height: complexityToHeight(10), width: totalWidth + 2.0,
            color: NSColor(hex: "#4CAF50"), label: "Low (10)"
        )
        container.addChildNode(thresholdLow)

        let thresholdMed = buildThresholdLine(
            height: complexityToHeight(20), width: totalWidth + 2.0,
            color: NSColor(hex: "#FF9800"), label: "Medium (20)"
        )
        container.addChildNode(thresholdMed)

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 80.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    // MARK: - Complexity Bar

    private static func buildComplexityBar(complexity: CodeComplexity, index: Int, total: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "complexityBar_\(complexity.id.uuidString)"

        let barColor = NSColor(hex: complexity.complexityColor)
        let barHeight = complexityToHeight(complexity.cyclomaticComplexity)

        // Main bar
        let barGeo = SCNBox(width: 0.6, height: CGFloat(barHeight), length: 0.6, chamferRadius: 0.03)
        let barMat = SCNMaterial()
        barMat.diffuse.contents = barColor.withAlphaComponent(0.75)
        barMat.emission.contents = barColor
        barMat.emission.intensity = 0.3
        barGeo.materials = [barMat]
        let barNode = SCNNode(geometry: barGeo)
        barNode.position = SCNVector3(0, barHeight / 2, 0)
        container.addChildNode(barNode)

        // Glow sphere at top for high complexity
        if complexity.cyclomaticComplexity > 20 {
            let glow = SCNSphere(radius: 0.15)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = barColor.withAlphaComponent(0.2)
            glowMat.emission.contents = barColor
            glowMat.emission.intensity = 0.8
            glowMat.isDoubleSided = true
            glow.materials = [glowMat]
            let glowNode = SCNNode(geometry: glow)
            glowNode.position = SCNVector3(0, barHeight + 0.1, 0)
            container.addChildNode(glowNode)

            // Pulse animation for critical complexity
            let pulse = SCNAction.customAction(duration: 1.5) { node, elapsed in
                let t = Float(elapsed) / 1.5
                let intensity = 0.6 + 0.4 * sin(t * Float.pi * 2)
                node.geometry?.materials.first?.emission.intensity = CGFloat(intensity)
            }
            glowNode.runAction(.repeatForever(pulse))
        }

        // Severity indicator floating above bar
        let severityNode = buildSeverityIndicator(complexity: complexity)
        severityNode.position = SCNVector3(0, barHeight + 0.35, 0)
        container.addChildNode(severityNode)

        // Complexity value label
        let valStr = "\(complexity.cyclomaticComplexity)"
        let valLabel = buildLabel(valStr, color: barColor, fontSize: 0.1)
        valLabel.position = SCNVector3(0, barHeight + 0.15, 0)
        let valBillboard = SCNBillboardConstraint()
        valBillboard.freeAxes = .Y
        valLabel.constraints = [valBillboard]
        container.addChildNode(valLabel)

        // Module name label
        let displayName = String(complexity.moduleName.prefix(18))
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

        // Maintainability index as secondary bar (thin bar in front)
        let maintHeight = Float(complexity.maintainabilityIndex) / 100.0 * barHeight
        if maintHeight > 0.01 {
            let maintGeo = SCNBox(width: 0.1, height: CGFloat(maintHeight), length: 0.1, chamferRadius: 0.01)
            let maintMat = SCNMaterial()
            let maintColor = NSColor(hex: complexity.maintainabilityColor)
            maintMat.diffuse.contents = maintColor.withAlphaComponent(0.6)
            maintMat.emission.contents = maintColor
            maintMat.emission.intensity = 0.3
            maintGeo.materials = [maintMat]
            let maintNode = SCNNode(geometry: maintGeo)
            maintNode.position = SCNVector3(0.4, maintHeight / 2, 0.4)
            container.addChildNode(maintNode)
        }

        // Floating bob animation
        let bobDuration = 2.2 + Double(index % 5) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }

    // MARK: - Severity Indicator

    private static func buildSeverityIndicator(complexity: CodeComplexity) -> SCNNode {
        let container = SCNNode()

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        let severityText: String
        let severityColor: NSColor
        if complexity.cyclomaticComplexity <= 10 {
            severityText = "LOW"
            severityColor = NSColor(hex: "#4CAF50")
        } else if complexity.cyclomaticComplexity <= 20 {
            severityText = "MED"
            severityColor = NSColor(hex: "#FF9800")
        } else {
            severityText = "HIGH"
            severityColor = NSColor(hex: "#F44336")
        }

        // Background pill
        let pill = SCNPlane(width: 0.35, height: 0.12)
        let pillMat = SCNMaterial()
        pillMat.diffuse.contents = severityColor.withAlphaComponent(0.2)
        pillMat.emission.contents = severityColor
        pillMat.emission.intensity = 0.3
        pillMat.isDoubleSided = true
        pill.materials = [pillMat]
        let pillNode = SCNNode(geometry: pill)
        container.addChildNode(pillNode)

        // Severity text
        let text = SCNText(string: severityText, extrusionDepth: 0.003)
        text.font = NSFont(name: "Menlo-Bold", size: 0.06) ?? NSFont.monospacedSystemFont(ofSize: 0.06, weight: .bold)
        text.flatness = 0.3
        let textMat = SCNMaterial()
        textMat.diffuse.contents = severityColor
        textMat.emission.contents = severityColor
        textMat.emission.intensity = 0.5
        text.materials = [textMat]
        let textNode = SCNNode(geometry: text)
        let (minBound, maxBound) = textNode.boundingBox
        let textWidth = maxBound.x - minBound.x
        textNode.position = SCNVector3(-textWidth / 2, -0.03, 0.01)
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        container.addChildNode(textNode)

        return container
    }

    // MARK: - Threshold Line

    private static func buildThresholdLine(height: Float, width: Float, color: NSColor, label: String) -> SCNNode {
        let container = SCNNode()

        // Dashed line using small cylinders
        let dashCount = Int(width / 0.3)
        for i in 0..<dashCount where i % 2 == 0 {
            let t = Float(i) / Float(max(dashCount, 1))
            let x = -width / 2 + t * width

            let dash = SCNBox(width: 0.12, height: 0.008, length: 0.008, chamferRadius: 0)
            let dashMat = SCNMaterial()
            dashMat.diffuse.contents = color.withAlphaComponent(0.3)
            dashMat.emission.contents = color
            dashMat.emission.intensity = 0.2
            dash.materials = [dashMat]
            let dashNode = SCNNode(geometry: dash)
            dashNode.position = SCNVector3(x, height, 0)
            container.addChildNode(dashNode)
        }

        // Label
        let labelNode = buildLabel(label, color: color.withAlphaComponent(0.5), fontSize: 0.04)
        labelNode.position = SCNVector3(width / 2 + 0.3, height, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        labelNode.constraints = [billboard]
        container.addChildNode(labelNode)

        return container
    }

    // MARK: - Helpers

    private static func complexityToHeight(_ complexity: Int) -> Float {
        let maxHeight: Float = 3.5
        return min(maxHeight, Float(complexity) / 30.0 * maxHeight)
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
