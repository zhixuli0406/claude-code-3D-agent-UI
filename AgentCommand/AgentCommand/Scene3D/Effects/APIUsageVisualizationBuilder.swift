import SceneKit

// MARK: - M3: API Usage Analytics Visualization

struct APIUsageVisualizationBuilder {

    static func buildUsageVisualization(modelStats: [ModelUsageStats], budgetAlert: BudgetAlert?, callRecords: [APICallMetrics]) -> SCNNode {
        let container = SCNNode()
        container.name = "apiUsageVisualization"

        // Central usage meter
        let meterNode = buildUsageMeter(budgetAlert: budgetAlert)
        meterNode.position = SCNVector3(0, 0.8, 0)
        container.addChildNode(meterNode)

        // Model usage bars
        for (i, stat) in modelStats.prefix(4).enumerated() {
            let barNode = buildModelBar(stat: stat, index: i, total: min(modelStats.count, 4))
            container.addChildNode(barNode)
        }

        // Recent API call particle trail
        if !callRecords.isEmpty {
            let trailNode = buildCallTrail(records: Array(callRecords.suffix(10)))
            trailNode.position = SCNVector3(0, -0.8, 0)
            container.addChildNode(trailNode)
        }

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 65.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildUsageMeter(budgetAlert: BudgetAlert?) -> SCNNode {
        let node = SCNNode()

        // Outer ring representing budget
        let ringGeo = SCNTorus(ringRadius: 0.35, pipeRadius: 0.02)
        let ringMat = SCNMaterial()
        let budgetColor = budgetAlert?.alertLevel.colorHex ?? "#4CAF50"
        ringMat.diffuse.contents = NSColor(hex: budgetColor).withAlphaComponent(0.6)
        ringMat.emission.contents = NSColor(hex: budgetColor)
        ringMat.emission.intensity = 0.4
        ringGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: ringGeo)
        node.addChildNode(ringNode)

        // Inner sphere for current spend
        let spendPercent = budgetAlert?.spendPercentage ?? 0
        let sphereRadius = CGFloat(min(spendPercent, 1.0)) * 0.2 + 0.05
        let sphereGeo = SCNSphere(radius: sphereRadius)
        let sphereMat = SCNMaterial()
        sphereMat.diffuse.contents = NSColor(hex: "#FF9800").withAlphaComponent(0.5)
        sphereMat.emission.contents = NSColor(hex: "#FF9800")
        sphereMat.emission.intensity = 0.5
        sphereMat.isDoubleSided = true
        sphereGeo.materials = [sphereMat]
        let sphereNode = SCNNode(geometry: sphereGeo)
        node.addChildNode(sphereNode)

        // Budget exceeded warning pulse
        if let alert = budgetAlert, alert.alertLevel == .critical {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.4, duration: 0.3),
                .fadeOpacity(to: 1.0, duration: 0.3)
            ])
            ringNode.runAction(.repeatForever(pulse))
        }

        let rotateRing = SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 12)
        ringNode.runAction(.repeatForever(rotateRing))

        return node
    }

    private static func buildModelBar(stat: ModelUsageStats, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "modelStat_\(stat.id)"

        // Color by model name
        let colorHex: String
        if stat.modelName.lowercased().contains("opus") {
            colorHex = "#9C27B0"
        } else if stat.modelName.lowercased().contains("sonnet") {
            colorHex = "#2196F3"
        } else if stat.modelName.lowercased().contains("haiku") {
            colorHex = "#4CAF50"
        } else {
            colorHex = "#FF9800"
        }

        // Bar height proportional to cost
        let maxCost = 50.0
        let normalizedHeight = CGFloat(min(stat.totalCost / maxCost, 1.0))
        let barHeight = normalizedHeight * 1.2 + 0.1
        let barGeo = SCNCylinder(radius: 0.08, height: barHeight)
        let barMat = SCNMaterial()
        barMat.diffuse.contents = NSColor(hex: colorHex).withAlphaComponent(0.7)
        barMat.emission.contents = NSColor(hex: colorHex)
        barMat.emission.intensity = 0.3
        barGeo.materials = [barMat]
        let barNode = SCNNode(geometry: barGeo)
        node.addChildNode(barNode)

        // Error rate indicator (red ring at top if high)
        if stat.errorRate > 0.05 {
            let errorGeo = SCNTorus(ringRadius: 0.1, pipeRadius: 0.008)
            let errorMat = SCNMaterial()
            errorMat.diffuse.contents = NSColor(hex: "#F44336").withAlphaComponent(0.8)
            errorMat.emission.contents = NSColor(hex: "#F44336")
            errorMat.emission.intensity = 0.5
            errorGeo.materials = [errorMat]
            let errorNode = SCNNode(geometry: errorGeo)
            errorNode.position = SCNVector3(0, Float(barHeight / 2) + 0.05, 0)
            node.addChildNode(errorNode)
        }

        // Label
        let label = buildLabel(String(stat.modelName.prefix(8)),
                              color: NSColor.white.withAlphaComponent(0.7),
                              fontSize: 0.03)
        label.position = SCNVector3(0, Float(barHeight / 2) + 0.15, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Position evenly spaced
        let spacing: Float = 1.2
        let totalWidth = Float(total - 1) * spacing
        let xPos = Float(index) * spacing - totalWidth / 2
        node.position = SCNVector3(xPos, Float(barHeight / 2) - 0.3, 0)

        return node
    }

    private static func buildCallTrail(records: [APICallMetrics]) -> SCNNode {
        let trail = SCNNode()
        trail.name = "apiCallTrail"

        for (i, record) in records.enumerated() {
            let radius: CGFloat = record.isError ? 0.04 : 0.025
            let dotGeo = SCNSphere(radius: radius)
            let dotMat = SCNMaterial()
            let dotColor = record.isError ? "#F44336" : "#4CAF50"
            let opacity = CGFloat(records.count - i) / CGFloat(records.count) * 0.7 + 0.3
            dotMat.diffuse.contents = NSColor(hex: dotColor).withAlphaComponent(opacity)
            dotMat.emission.contents = NSColor(hex: dotColor)
            dotMat.emission.intensity = CGFloat(records.count - i) / CGFloat(records.count) * 0.4
            dotGeo.materials = [dotMat]
            let dotNode = SCNNode(geometry: dotGeo)

            let angle = Float(i) * (Float.pi * 2 / Float(records.count))
            let trailRadius: Float = 1.0
            dotNode.position = SCNVector3(cos(angle) * trailRadius, 0, sin(angle) * trailRadius)
            trail.addChildNode(dotNode)
        }

        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 30)
        trail.runAction(.repeatForever(ringRotate))

        return trail
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
