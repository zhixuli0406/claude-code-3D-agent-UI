import SceneKit
import AppKit

/// Builds 3D visualization nodes for prompt optimization data (H4)
struct PromptOptimizationVisualizationBuilder {

    /// Build a floating prompt quality radar chart and pattern network in 3D space
    static func buildOptimizationGraph(
        score: PromptQualityScore?,
        patterns: [PromptPattern],
        history: [PromptHistoryRecord],
        antiPatterns: [PromptAntiPattern] = []
    ) -> SCNNode {
        let container = SCNNode()
        container.name = "promptOptimizationGraph"

        // Build radar chart for quality score
        if let score = score {
            let radarNode = buildRadarChart(score: score)
            radarNode.position = SCNVector3(0, 0, 0)
            container.addChildNode(radarNode)
        }

        // Build pattern network nodes
        if !patterns.isEmpty {
            let networkNode = buildPatternNetwork(patterns: patterns)
            networkNode.position = SCNVector3(2.5, 0, 0)
            container.addChildNode(networkNode)
        }

        // Build history sparkline
        if history.count >= 3 {
            let sparklineNode = buildHistorySparkline(history: Array(history.prefix(20)))
            sparklineNode.position = SCNVector3(-2.5, -0.5, 0)
            container.addChildNode(sparklineNode)
        }

        // Build anti-pattern warning ring
        if !antiPatterns.isEmpty {
            let apNode = buildAntiPatternRing(antiPatterns: antiPatterns)
            apNode.position = SCNVector3(0, -1.2, 0)
            container.addChildNode(apNode)
        }

        // Add title label
        let titleNode = buildLabel("PROMPT OPTIMIZATION", color: NSColor(hex: "#E040FB"), fontSize: 0.15)
        titleNode.position = SCNVector3(0, 1.5, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        titleNode.constraints = [billboard]
        container.addChildNode(titleNode)

        return container
    }

    // MARK: - Radar Chart

    private static func buildRadarChart(score: PromptQualityScore) -> SCNNode {
        let group = SCNNode()
        group.name = "qualityRadar"

        let dimensions: [(String, Double, NSColor)] = [
            ("CLR", score.clarity, NSColor(hex: "#00BCD4")),
            ("SPC", score.specificity, NSColor(hex: "#4CAF50")),
            ("CTX", score.context, NSColor(hex: "#FF9800")),
            ("ACT", score.actionability, NSColor(hex: "#E040FB")),
            ("EFF", score.tokenEfficiency, NSColor(hex: "#03A9F4")),
        ]

        let count = dimensions.count
        let radius: Float = 0.8

        // Draw background pentagon
        let bgMaterial = SCNMaterial()
        bgMaterial.diffuse.contents = NSColor(hex: "#E040FB").withAlphaComponent(0.05)
        bgMaterial.isDoubleSided = true

        // Draw axes and labels
        for (i, (label, _, color)) in dimensions.enumerated() {
            let angle = Float(i) * (2 * .pi / Float(count)) - .pi / 2
            let x = cos(angle) * radius
            let z = sin(angle) * radius

            // Axis line
            let axisLine = buildThinLine(from: SCNVector3(0, 0, 0), to: SCNVector3(x, 0, z), color: NSColor.white.withAlphaComponent(0.15))
            group.addChildNode(axisLine)

            // Label
            let labelNode = buildLabel(label, color: color, fontSize: 0.08)
            labelNode.position = SCNVector3(x * 1.2, 0, z * 1.2)
            let lblBillboard = SCNBillboardConstraint()
            lblBillboard.freeAxes = .Y
            labelNode.constraints = [lblBillboard]
            group.addChildNode(labelNode)
        }

        // Draw value polygon
        for (i, (_, value, color)) in dimensions.enumerated() {
            let angle = Float(i) * (2 * .pi / Float(count)) - .pi / 2
            let r = Float(value) * radius
            let x = cos(angle) * r
            let z = sin(angle) * r

            // Value dot
            let dot = SCNSphere(radius: 0.04)
            let dotMat = SCNMaterial()
            dotMat.diffuse.contents = color
            dotMat.emission.contents = color
            dotMat.emission.intensity = 0.8
            dot.materials = [dotMat]
            let dotNode = SCNNode(geometry: dot)
            dotNode.position = SCNVector3(x, 0, z)
            group.addChildNode(dotNode)

            // Connect to next point
            let nextI = (i + 1) % count
            let nextAngle = Float(nextI) * (2 * .pi / Float(count)) - .pi / 2
            let nextR = Float(dimensions[nextI].1) * radius
            let nextX = cos(nextAngle) * nextR
            let nextZ = sin(nextAngle) * nextR

            let line = buildThinLine(
                from: SCNVector3(x, 0, z),
                to: SCNVector3(nextX, 0, nextZ),
                color: NSColor(hex: "#E040FB").withAlphaComponent(0.6)
            )
            group.addChildNode(line)
        }

        // Grade label in center
        let gradeNode = buildLabel(score.gradeLabel, color: NSColor(hex: score.gradeColorHex), fontSize: 0.2)
        gradeNode.position = SCNVector3(0, 0.3, 0)
        let gradeBillboard = SCNBillboardConstraint()
        gradeBillboard.freeAxes = .Y
        gradeNode.constraints = [gradeBillboard]
        group.addChildNode(gradeNode)

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 20.0)
        group.runAction(.repeatForever(rotate), forKey: "radarSpin")

        return group
    }

    // MARK: - Pattern Network

    private static func buildPatternNetwork(patterns: [PromptPattern]) -> SCNNode {
        let group = SCNNode()
        group.name = "patternNetwork"

        let patternsToShow = Array(patterns.prefix(6))
        let angleStep = (2 * Float.pi) / Float(max(patternsToShow.count, 1))

        for (i, pattern) in patternsToShow.enumerated() {
            let angle = Float(i) * angleStep
            let r: Float = 0.6
            let x = cos(angle) * r
            let z = sin(angle) * r

            // Pattern node
            let size = CGFloat(0.08 + 0.04 * min(Double(pattern.matchCount) / 10.0, 1.0))
            let sphere = SCNSphere(radius: size)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: pattern.effectivenessColorHex)
            mat.emission.contents = NSColor(hex: pattern.effectivenessColorHex)
            mat.emission.intensity = 0.5
            sphere.materials = [mat]

            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = SCNVector3(x, 0, z)
            group.addChildNode(sphereNode)

            // Label
            let labelNode = buildLabel(pattern.name, color: NSColor.white.withAlphaComponent(0.7), fontSize: 0.06)
            labelNode.position = SCNVector3(x, 0.15, z)
            let lblBillboard = SCNBillboardConstraint()
            lblBillboard.freeAxes = .Y
            labelNode.constraints = [lblBillboard]
            group.addChildNode(labelNode)

            // Connection to center
            let line = buildThinLine(from: SCNVector3(0, 0, 0), to: SCNVector3(x, 0, z),
                                     color: NSColor(hex: pattern.effectivenessColorHex).withAlphaComponent(0.3))
            group.addChildNode(line)

            // Floating animation
            let bobUp = SCNAction.moveBy(x: 0, y: CGFloat(0.05 + 0.02 * Float(i)), z: 0, duration: 1.5 + Double(i) * 0.2)
            bobUp.timingMode = .easeInEaseOut
            let bobDown = SCNAction.moveBy(x: 0, y: -CGFloat(0.05 + 0.02 * Float(i)), z: 0, duration: 1.5 + Double(i) * 0.2)
            bobDown.timingMode = .easeInEaseOut
            sphereNode.runAction(.repeatForever(.sequence([bobUp, bobDown])), forKey: "bob")
        }

        return group
    }

    // MARK: - History Sparkline

    private static func buildHistorySparkline(history: [PromptHistoryRecord]) -> SCNNode {
        let group = SCNNode()
        group.name = "historySparkline"

        let width: Float = 2.0
        let height: Float = 0.6
        let stepX = width / Float(max(history.count - 1, 1))

        // Draw sparkline from quality scores
        for i in 0..<history.count {
            let record = history[i]
            let score = record.qualityScore?.overallScore ?? 0.5
            let x = Float(i) * stepX - width / 2
            let y = Float(score) * height

            // Dot
            let dot = SCNSphere(radius: 0.02)
            let mat = SCNMaterial()
            let color: NSColor = record.wasSuccessful == true ? NSColor(hex: "#4CAF50") :
                                  (record.wasSuccessful == false ? NSColor(hex: "#F44336") : NSColor(hex: "#9E9E9E"))
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 0.5
            dot.materials = [mat]
            let dotNode = SCNNode(geometry: dot)
            dotNode.position = SCNVector3(x, y, 0)
            group.addChildNode(dotNode)

            // Connect to next
            if i < history.count - 1 {
                let nextScore = history[i + 1].qualityScore?.overallScore ?? 0.5
                let nextX = Float(i + 1) * stepX - width / 2
                let nextY = Float(nextScore) * height
                let line = buildThinLine(from: SCNVector3(x, y, 0), to: SCNVector3(nextX, nextY, 0),
                                         color: NSColor(hex: "#E040FB").withAlphaComponent(0.4))
                group.addChildNode(line)
            }
        }

        // Baseline
        let baseline = buildThinLine(from: SCNVector3(-width / 2, 0, 0), to: SCNVector3(width / 2, 0, 0),
                                     color: NSColor.white.withAlphaComponent(0.1))
        group.addChildNode(baseline)

        // Label
        let label = buildLabel("HISTORY", color: NSColor.white.withAlphaComponent(0.4), fontSize: 0.06)
        label.position = SCNVector3(0, -0.15, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        group.addChildNode(label)

        return group
    }

    // MARK: - Anti-Pattern Warning Ring

    private static func buildAntiPatternRing(antiPatterns: [PromptAntiPattern]) -> SCNNode {
        let group = SCNNode()
        group.name = "antiPatternRing"

        let count = min(antiPatterns.count, 8)
        let angleStep = (2 * Float.pi) / Float(max(count, 1))
        let ringRadius: Float = 1.0

        for (i, ap) in antiPatterns.prefix(count).enumerated() {
            let angle = Float(i) * angleStep
            let x = cos(angle) * ringRadius
            let z = sin(angle) * ringRadius

            // Severity determines shape size and color
            let severity = ap.severity
            let baseSize: CGFloat = severity == .critical ? 0.1 : (severity == .warning ? 0.07 : 0.05)
            let colorHex = severity.colorHex

            // Warning octahedron for critical, box for warning, sphere for info
            let geometry: SCNGeometry
            switch severity {
            case .critical:
                // Use two pyramids to form a diamond shape
                let pyramid = SCNPyramid(width: baseSize * 2, height: baseSize * 2, length: baseSize * 2)
                geometry = pyramid
            case .warning:
                geometry = SCNBox(width: baseSize * 1.5, height: baseSize * 1.5, length: baseSize * 1.5, chamferRadius: 0.01)
            case .info:
                geometry = SCNSphere(radius: baseSize)
            }

            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: colorHex)
            mat.emission.contents = NSColor(hex: colorHex)
            mat.emission.intensity = 0.7
            mat.transparency = 0.85
            geometry.materials = [mat]

            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(x, 0, z)
            group.addChildNode(node)

            // Category label
            let labelNode = buildLabel(ap.category.displayName, color: NSColor(hex: colorHex), fontSize: 0.05)
            labelNode.position = SCNVector3(x, -0.15, z)
            let lblBillboard = SCNBillboardConstraint()
            lblBillboard.freeAxes = .Y
            labelNode.constraints = [lblBillboard]
            group.addChildNode(labelNode)

            // Pulsing animation for critical issues
            if severity == .critical {
                let scaleUp = SCNAction.scale(to: 1.3, duration: 0.5)
                scaleUp.timingMode = .easeInEaseOut
                let scaleDown = SCNAction.scale(to: 1.0, duration: 0.5)
                scaleDown.timingMode = .easeInEaseOut
                node.runAction(.repeatForever(.sequence([scaleUp, scaleDown])), forKey: "pulse")
            }

            // Slow rotation for all
            let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.0 + Double(i))
            node.runAction(.repeatForever(spin), forKey: "spin")
        }

        // Ring connecting line
        let ringSegments = max(count, 3)
        for i in 0..<ringSegments {
            let angle1 = Float(i) * (2 * .pi / Float(ringSegments))
            let angle2 = Float((i + 1) % ringSegments) * (2 * .pi / Float(ringSegments))
            let from = SCNVector3(cos(angle1) * ringRadius, 0, sin(angle1) * ringRadius)
            let to = SCNVector3(cos(angle2) * ringRadius, 0, sin(angle2) * ringRadius)
            let line = buildThinLine(from: from, to: to, color: NSColor(hex: "#F44336").withAlphaComponent(0.2))
            group.addChildNode(line)
        }

        // Warning label
        let warningLabel = buildLabel("ISSUES: \(antiPatterns.count)", color: NSColor(hex: "#F44336"), fontSize: 0.08)
        warningLabel.position = SCNVector3(0, 0.2, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        warningLabel.constraints = [billboard]
        group.addChildNode(warningLabel)

        return group
    }

    // MARK: - Helpers

    private static func buildThinLine(from: SCNVector3, to: SCNVector3, color: NSColor) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let length = sqrt(dx * dx + dy * dy + dz * dz)

        let cylinder = SCNCylinder(radius: 0.008, height: CGFloat(length))
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = 0.3
        cylinder.materials = [mat]

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (from.x + to.x) / 2,
            (from.y + to.y) / 2,
            (from.z + to.z) / 2
        )
        node.look(at: to, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))

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
        // Center the text
        let (minBound, maxBound) = node.boundingBox
        let textWidth = maxBound.x - minBound.x
        node.pivot = SCNMatrix4MakeTranslation(textWidth / 2, 0, 0)

        return node
    }
}
