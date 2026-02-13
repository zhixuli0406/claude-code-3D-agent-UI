import SceneKit

// MARK: - M4: Session History Analytics 3D Visualization Builder

struct SessionHistoryVisualizationBuilder {
    /// Build a 3D visualization of session history analytics
    static func build(sessions: [SessionAnalytics], trend: ProductivityTrend?, timeDistribution: SessionTimeDistribution? = nil, parentNode: SCNNode) {
        let rootNode = SCNNode()
        rootNode.name = "sessionHistoryVisualization"
        rootNode.position = SCNVector3(x: -4.0, y: 2.5, z: -3.0)

        // Central analytics hub
        buildAnalyticsHub(sessions: sessions, parentNode: rootNode)

        // Session timeline arc
        buildSessionTimeline(sessions: sessions, parentNode: rootNode)

        // Productivity trend line
        if let trend = trend {
            buildTrendLine(trend: trend, parentNode: rootNode)
        }

        // Time distribution ring
        if let distribution = timeDistribution {
            buildTimeDistributionRing(distribution: distribution, parentNode: rootNode)
        }

        // Task completion bar chart
        buildTaskBarChart(sessions: sessions, parentNode: rootNode)

        parentNode.addChildNode(rootNode)
    }

    /// Remove session history visualization from scene
    static func remove(from parentNode: SCNNode) {
        parentNode.childNode(withName: "sessionHistoryVisualization", recursively: true)?.removeFromParentNode()
    }

    // MARK: - Analytics Hub

    private static func buildAnalyticsHub(sessions: [SessionAnalytics], parentNode: SCNNode) {
        let hubGeometry = SCNSphere(radius: 0.25)
        let hubMaterial = SCNMaterial()
        hubMaterial.diffuse.contents = NSColor(hex: "#9C27B0")
        hubMaterial.emission.contents = NSColor(hex: "#9C27B0").withAlphaComponent(0.6)
        hubMaterial.transparency = 0.8
        hubGeometry.materials = [hubMaterial]

        let hubNode = SCNNode(geometry: hubGeometry)
        hubNode.name = "sessionHub"
        hubNode.position = SCNVector3(x: 0, y: 0, z: 0)

        // Pulsing animation
        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = NSValue(scnVector3: SCNVector3(1, 1, 1))
        pulse.toValue = NSValue(scnVector3: SCNVector3(1.15, 1.15, 1.15))
        pulse.duration = 2.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        hubNode.addAnimation(pulse, forKey: "pulse")

        parentNode.addChildNode(hubNode)
    }

    // MARK: - Session Timeline

    private static func buildSessionTimeline(sessions: [SessionAnalytics], parentNode: SCNNode) {
        let visibleSessions = Array(sessions.prefix(10))
        let arcRadius: CGFloat = 1.5
        let arcAngle = CGFloat.pi * 0.8

        for (index, session) in visibleSessions.enumerated() {
            let fraction = CGFloat(index) / max(1, CGFloat(visibleSessions.count - 1))
            let angle = -arcAngle / 2 + arcAngle * fraction

            let x = arcRadius * sin(angle)
            let z = arcRadius * cos(angle) - arcRadius

            // Session node - size based on productivity
            let nodeRadius = CGFloat(0.06 + session.productivityScore * 0.08)
            let sessionGeometry = SCNSphere(radius: nodeRadius)
            let sessionMaterial = SCNMaterial()

            // Color based on productivity
            let colorHex = session.productivityColorHex
            sessionMaterial.diffuse.contents = NSColor(hex: colorHex)
            sessionMaterial.emission.contents = NSColor(hex: colorHex).withAlphaComponent(0.4)
            sessionGeometry.materials = [sessionMaterial]

            let sessionNode = SCNNode(geometry: sessionGeometry)
            sessionNode.position = SCNVector3(x: x, y: 0.3, z: z)
            sessionNode.name = "session_\(session.id)"

            // Floating animation
            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = 0.3
            float.toValue = 0.3 + Double.random(in: 0.05...0.15)
            float.duration = Double.random(in: 2.0...3.5)
            float.autoreverses = true
            float.repeatCount = .infinity
            sessionNode.addAnimation(float, forKey: "float")

            parentNode.addChildNode(sessionNode)

            // Connection line to hub
            if index > 0 {
                let prevFraction = CGFloat(index - 1) / max(1, CGFloat(visibleSessions.count - 1))
                let prevAngle = -arcAngle / 2 + arcAngle * prevFraction
                let prevX = arcRadius * sin(prevAngle)
                let prevZ = arcRadius * cos(prevAngle) - arcRadius

                let lineNode = createLine(
                    from: SCNVector3(x: prevX, y: 0.3, z: prevZ),
                    to: SCNVector3(x: x, y: 0.3, z: z),
                    color: NSColor(hex: "#9C27B0").withAlphaComponent(0.3)
                )
                parentNode.addChildNode(lineNode)
            }
        }
    }

    // MARK: - Trend Line

    private static func buildTrendLine(trend: ProductivityTrend, parentNode: SCNNode) {
        let dataPoints = trend.dataPoints.suffix(14)
        guard dataPoints.count >= 2 else { return }

        let lineWidth: CGFloat = 0.8
        let lineHeight: CGFloat = 0.5
        let startX: CGFloat = -lineWidth / 2
        let baseY: CGFloat = -0.3

        for (index, point) in dataPoints.enumerated() {
            let fraction = CGFloat(index) / CGFloat(dataPoints.count - 1)
            let x = startX + lineWidth * fraction
            let y = baseY + CGFloat(point.productivity) * lineHeight

            let dotGeometry = SCNSphere(radius: 0.02)
            let dotMaterial = SCNMaterial()
            dotMaterial.diffuse.contents = NSColor(hex: trend.overallTrend.colorHex)
            dotMaterial.emission.contents = NSColor(hex: trend.overallTrend.colorHex).withAlphaComponent(0.5)
            dotGeometry.materials = [dotMaterial]

            let dotNode = SCNNode(geometry: dotGeometry)
            dotNode.position = SCNVector3(x: x, y: y, z: 0.5)
            parentNode.addChildNode(dotNode)

            if index > 0 {
                let prevFraction = CGFloat(index - 1) / CGFloat(dataPoints.count - 1)
                let prevX = startX + lineWidth * prevFraction
                let prevPoint = dataPoints[dataPoints.index(dataPoints.startIndex, offsetBy: index - 1)]
                let prevY = baseY + CGFloat(prevPoint.productivity) * lineHeight

                let lineNode = createLine(
                    from: SCNVector3(x: prevX, y: prevY, z: 0.5),
                    to: SCNVector3(x: x, y: y, z: 0.5),
                    color: NSColor(hex: trend.overallTrend.colorHex).withAlphaComponent(0.6)
                )
                parentNode.addChildNode(lineNode)
            }
        }
    }

    // MARK: - Time Distribution Ring

    private static func buildTimeDistributionRing(distribution: SessionTimeDistribution, parentNode: SCNNode) {
        let ringRadius: Float = 0.6
        let ringY: Float = -0.7
        var currentAngle: Float = 0

        for entry in distribution.entries {
            let sliceAngle = Float(entry.percentage) * .pi * 2
            let midAngle = currentAngle + sliceAngle / 2
            let endAngle = currentAngle + sliceAngle

            // Arc segment represented as a positioned dot at the midpoint
            let x = ringRadius * cos(midAngle - .pi / 2)
            let z = ringRadius * sin(midAngle - .pi / 2)

            let dotSize = CGFloat(0.02 + entry.percentage * 0.04)
            let dotGeometry = SCNSphere(radius: dotSize)
            let dotMaterial = SCNMaterial()
            dotMaterial.diffuse.contents = NSColor(hex: entry.category.colorHex)
            dotMaterial.emission.contents = NSColor(hex: entry.category.colorHex).withAlphaComponent(0.5)
            dotGeometry.materials = [dotMaterial]

            let dotNode = SCNNode(geometry: dotGeometry)
            dotNode.position = SCNVector3(x, ringY, z)
            dotNode.name = "timeDist_\(entry.category.rawValue)"

            // Gentle pulse
            let pulse = CABasicAnimation(keyPath: "scale")
            pulse.fromValue = NSValue(scnVector3: SCNVector3(1, 1, 1))
            pulse.toValue = NSValue(scnVector3: SCNVector3(1.2, 1.2, 1.2))
            pulse.duration = Double.random(in: 1.5...2.5)
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            dotNode.addAnimation(pulse, forKey: "pulse")

            parentNode.addChildNode(dotNode)

            // Connect adjacent segments
            if currentAngle > 0 {
                let prevX = ringRadius * cos(currentAngle - .pi / 2)
                let prevZ = ringRadius * sin(currentAngle - .pi / 2)

                let lineNode = createLine(
                    from: SCNVector3(prevX, ringY, prevZ),
                    to: SCNVector3(x, ringY, z),
                    color: NSColor(hex: "#9C27B0").withAlphaComponent(0.2)
                )
                parentNode.addChildNode(lineNode)
            }

            currentAngle = endAngle
        }

        // Close the ring
        if distribution.entries.count > 1 {
            let firstEntry = distribution.entries[0]
            let firstAngle = Float(firstEntry.percentage) * .pi * 2 / 2
            let firstX = ringRadius * cos(firstAngle - .pi / 2)
            let firstZ = ringRadius * sin(firstAngle - .pi / 2)
            let lastX = ringRadius * cos(currentAngle - .pi / 2)
            let lastZ = ringRadius * sin(currentAngle - .pi / 2)

            let closeLine = createLine(
                from: SCNVector3(lastX, ringY, lastZ),
                to: SCNVector3(firstX, ringY, firstZ),
                color: NSColor(hex: "#9C27B0").withAlphaComponent(0.2)
            )
            parentNode.addChildNode(closeLine)
        }
    }

    // MARK: - Task Bar Chart

    private static func buildTaskBarChart(sessions: [SessionAnalytics], parentNode: SCNNode) {
        let visibleSessions = Array(sessions.prefix(8))
        guard !visibleSessions.isEmpty else { return }

        let maxTasks = visibleSessions.map(\.tasksCompleted).max() ?? 1
        let barWidth: CGFloat = 0.06
        let spacing: Float = 0.12
        let totalWidth = Float(visibleSessions.count) * spacing
        let startX = -totalWidth / 2
        let baseY: Float = -1.0

        for (index, session) in visibleSessions.enumerated() {
            let normalizedHeight = Float(session.tasksCompleted) / Float(max(1, maxTasks))
            let height = CGFloat(max(0.05, normalizedHeight * 0.5))

            let barGeometry = SCNCylinder(radius: barWidth, height: height)
            let barMaterial = SCNMaterial()
            barMaterial.diffuse.contents = NSColor(hex: session.productivityColorHex).withAlphaComponent(0.7)
            barMaterial.emission.contents = NSColor(hex: session.productivityColorHex)
            barMaterial.emission.intensity = 0.3
            barGeometry.materials = [barMaterial]

            let barNode = SCNNode(geometry: barGeometry)
            let x = startX + Float(index) * spacing
            barNode.position = SCNVector3(x, baseY + Float(height / 2), 0.8)
            barNode.name = "taskBar_\(session.id)"

            parentNode.addChildNode(barNode)
        }
    }

    // MARK: - Helpers

    private static func createLine(from: SCNVector3, to: SCNVector3, color: NSColor) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let distance = sqrt(dx*dx + dy*dy + dz*dz)

        let cylinder = SCNCylinder(radius: 0.005, height: CGFloat(distance))
        let material = SCNMaterial()
        material.diffuse.contents = color
        cylinder.materials = [material]

        let lineNode = SCNNode(geometry: cylinder)
        lineNode.position = SCNVector3(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2,
            z: (from.z + to.z) / 2
        )

        lineNode.look(at: to, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))

        return lineNode
    }
}
