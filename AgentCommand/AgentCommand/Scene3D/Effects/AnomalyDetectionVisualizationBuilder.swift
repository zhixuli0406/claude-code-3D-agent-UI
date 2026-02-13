import SceneKit

// MARK: - L3: Anomaly Detection Visualization

struct AnomalyDetectionVisualizationBuilder {

    static func buildAnomalyVisualization(alerts: [AnomalyAlert], patterns: [ErrorPattern]) -> SCNNode {
        let container = SCNNode()
        container.name = "anomalyVisualization"

        // Build alert nodes
        for (i, alert) in alerts.prefix(5).enumerated() {
            let alertNode = buildAlertNode(alert: alert, index: i, total: min(alerts.count, 5))
            container.addChildNode(alertNode)
        }

        // Build pattern ring
        if !patterns.isEmpty {
            let patternRing = buildPatternRing(patterns: Array(patterns.prefix(6)))
            patternRing.position = SCNVector3(0, -0.8, 0)
            container.addChildNode(patternRing)
        }

        // Shield/monitoring indicator
        let shieldNode = buildShieldNode()
        shieldNode.position = SCNVector3(0, 1.2, 0)
        container.addChildNode(shieldNode)

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 70.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildAlertNode(alert: AnomalyAlert, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "anomaly_\(alert.id.uuidString)"

        // Alert geometry based on severity
        let size: CGFloat = alert.severity == .critical ? 0.3 : (alert.severity == .warning ? 0.22 : 0.18)
        let geo: SCNGeometry

        switch alert.severity {
        case .critical:
            geo = SCNBox(width: size, height: size, length: size, chamferRadius: 0.02)
        case .warning:
            let pyramid = SCNPyramid(width: size, height: size * 1.2, length: size)
            geo = pyramid
        case .info:
            geo = SCNSphere(radius: size / 2)
        }

        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: alert.severity.hexColor).withAlphaComponent(alert.isResolved ? 0.3 : 0.85)
        mat.emission.contents = NSColor(hex: alert.severity.hexColor)
        mat.emission.intensity = alert.isResolved ? 0.1 : 0.5
        geo.materials = [mat]

        let geoNode = SCNNode(geometry: geo)
        node.addChildNode(geoNode)

        // Type icon label
        let label = buildLabel(alert.type.displayName.prefix(10).description,
                              color: NSColor.white.withAlphaComponent(0.7),
                              fontSize: 0.04)
        label.position = SCNVector3(0, Float(size) + 0.1, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Position in semicircle
        let angle = Float(index) * (Float.pi / Float(max(total - 1, 1))) - Float.pi / 2
        node.position = SCNVector3(cos(angle) * 1.8, sin(angle) * 0.5, sin(angle) * 0.3)

        // Critical alerts pulse
        if alert.severity == .critical && !alert.isResolved {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.4, duration: 0.4),
                .fadeOpacity(to: 1.0, duration: 0.4)
            ])
            geoNode.runAction(.repeatForever(pulse))
        }

        // Resolved: slow fade
        if alert.isResolved {
            geoNode.opacity = 0.4
        }

        return node
    }

    private static func buildPatternRing(patterns: [ErrorPattern]) -> SCNNode {
        let ring = SCNNode()
        ring.name = "errorPatternRing"

        for (i, pattern) in patterns.enumerated() {
            let angle = Float(i) * (2 * Float.pi / Float(patterns.count))
            let radius: Float = 1.0

            let barHeight = CGFloat(min(pattern.occurrenceCount, 10)) * 0.08
            let barGeo = SCNCylinder(radius: 0.04, height: barHeight)
            let barMat = SCNMaterial()
            barMat.diffuse.contents = NSColor(hex: pattern.category.hexColor).withAlphaComponent(0.7)
            barMat.emission.contents = NSColor(hex: pattern.category.hexColor)
            barMat.emission.intensity = 0.3
            barGeo.materials = [barMat]
            let barNode = SCNNode(geometry: barGeo)
            barNode.position = SCNVector3(cos(angle) * radius, Float(barHeight / 2), sin(angle) * radius)
            ring.addChildNode(barNode)
        }

        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 40)
        ring.runAction(.repeatForever(ringRotate))

        return ring
    }

    private static func buildShieldNode() -> SCNNode {
        let node = SCNNode()

        let shieldGeo = SCNSphere(radius: 0.2)
        let shieldMat = SCNMaterial()
        shieldMat.diffuse.contents = NSColor(hex: "#4CAF50").withAlphaComponent(0.3)
        shieldMat.emission.contents = NSColor(hex: "#4CAF50")
        shieldMat.emission.intensity = 0.4
        shieldMat.isDoubleSided = true
        shieldGeo.materials = [shieldMat]
        let shieldNode = SCNNode(geometry: shieldGeo)
        node.addChildNode(shieldNode)

        // Outer ring
        let ringGeo = SCNTorus(ringRadius: 0.3, pipeRadius: 0.015)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: "#00BCD4").withAlphaComponent(0.5)
        ringMat.emission.contents = NSColor(hex: "#00BCD4")
        ringMat.emission.intensity = 0.3
        ringGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: ringGeo)
        node.addChildNode(ringNode)

        // Rotation
        let rotate = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 8)
        ringNode.runAction(.repeatForever(rotate))

        // Pulse
        let pulse = SCNAction.sequence([
            .scale(to: 1.1, duration: 1.5),
            .scale(to: 1.0, duration: 1.5)
        ])
        node.runAction(.repeatForever(pulse))

        return node
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
