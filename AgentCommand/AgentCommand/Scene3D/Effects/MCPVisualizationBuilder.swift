import SceneKit

// MARK: - L4: MCP Integration Visualization

struct MCPVisualizationBuilder {

    static func buildMCPVisualization(servers: [MCPServer], recentCalls: [MCPToolCall]) -> SCNNode {
        let container = SCNNode()
        container.name = "mcpVisualization"

        // Central hub
        let hubNode = buildHubNode()
        container.addChildNode(hubNode)

        // Server nodes around hub
        for (i, server) in servers.prefix(5).enumerated() {
            let serverNode = buildServerNode(server: server, index: i, total: min(servers.count, 5))
            container.addChildNode(serverNode)

            // Connection line to hub
            let connectionNode = buildConnectionToHub(index: i, total: min(servers.count, 5), connected: server.status == .connected)
            container.addChildNode(connectionNode)
        }

        // Recent call particles
        if !recentCalls.isEmpty {
            let callsNode = buildRecentCallsRing(calls: Array(recentCalls.prefix(8)))
            callsNode.position = SCNVector3(0, -0.6, 0)
            container.addChildNode(callsNode)
        }

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 75.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildHubNode() -> SCNNode {
        let node = SCNNode()
        node.name = "mcpHub"

        // Central sphere
        let hubGeo = SCNSphere(radius: 0.25)
        let hubMat = SCNMaterial()
        hubMat.diffuse.contents = NSColor(hex: "#00BCD4").withAlphaComponent(0.6)
        hubMat.emission.contents = NSColor(hex: "#00BCD4")
        hubMat.emission.intensity = 0.5
        hubGeo.materials = [hubMat]
        let hubSphere = SCNNode(geometry: hubGeo)
        node.addChildNode(hubSphere)

        // Label
        let label = buildLabel("MCP", color: NSColor.white, fontSize: 0.08)
        label.position = SCNVector3(0, 0.4, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Rotating ring
        let ringGeo = SCNTorus(ringRadius: 0.35, pipeRadius: 0.012)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: "#00BCD4").withAlphaComponent(0.3)
        ringMat.emission.contents = NSColor(hex: "#00BCD4")
        ringMat.emission.intensity = 0.2
        ringGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: ringGeo)
        let ringRotate = SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 6)
        ringNode.runAction(.repeatForever(ringRotate))
        node.addChildNode(ringNode)

        // Pulse
        let pulse = SCNAction.sequence([
            .scale(to: 1.05, duration: 2.0),
            .scale(to: 1.0, duration: 2.0)
        ])
        hubSphere.runAction(.repeatForever(pulse))

        return node
    }

    private static func buildServerNode(server: MCPServer, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "mcpServer_\(server.id.uuidString)"

        let angle = Float(index) * (2 * Float.pi / Float(total))
        let radius: Float = 1.8
        node.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)

        // Server box
        let boxGeo = SCNBox(width: 0.4, height: 0.4, length: 0.2, chamferRadius: 0.05)
        let boxMat = SCNMaterial()
        boxMat.diffuse.contents = NSColor(hex: server.status.hexColor).withAlphaComponent(0.8)
        boxMat.emission.contents = NSColor(hex: server.status.hexColor)
        boxMat.emission.intensity = 0.4
        boxGeo.materials = [boxMat]
        let boxNode = SCNNode(geometry: boxGeo)
        node.addChildNode(boxNode)

        // Server name
        let label = buildLabel(String(server.name.prefix(12)),
                              color: NSColor.white.withAlphaComponent(0.8),
                              fontSize: 0.04)
        label.position = SCNVector3(0, 0.3, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Tool count indicator
        let toolCount = server.tools.count
        let countLabel = buildLabel("\(toolCount) tools",
                                   color: NSColor.white.withAlphaComponent(0.5),
                                   fontSize: 0.03)
        countLabel.position = SCNVector3(0, -0.3, 0)
        let countBillboard = SCNBillboardConstraint()
        countBillboard.freeAxes = .Y
        countLabel.constraints = [countBillboard]
        node.addChildNode(countLabel)

        // Connected pulse
        if server.status == .connected {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.7, duration: 1.0),
                .fadeOpacity(to: 1.0, duration: 1.0)
            ])
            boxNode.runAction(.repeatForever(pulse))
        }

        // Bob
        let bobDuration = 2.0 + Double(index % 3) * 0.4
        let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return node
    }

    private static func buildConnectionToHub(index: Int, total: Int, connected: Bool) -> SCNNode {
        let angle = Float(index) * (2 * Float.pi / Float(total))
        let radius: Float = 1.8
        let endPoint = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)

        let distance = sqrt(endPoint.x * endPoint.x + endPoint.z * endPoint.z)
        let lineGeo = SCNCylinder(radius: connected ? 0.012 : 0.006, height: CGFloat(distance))
        let lineMat = SCNMaterial()
        let color = connected ? "#4CAF50" : "#9E9E9E"
        lineMat.diffuse.contents = NSColor(hex: color).withAlphaComponent(connected ? 0.4 : 0.15)
        lineMat.emission.contents = NSColor(hex: color)
        lineMat.emission.intensity = connected ? 0.2 : 0.05
        lineGeo.materials = [lineMat]

        let lineNode = SCNNode(geometry: lineGeo)
        lineNode.position = SCNVector3(endPoint.x / 2, 0, endPoint.z / 2)
        lineNode.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, -atan2(endPoint.z, endPoint.x))

        return lineNode
    }

    private static func buildRecentCallsRing(calls: [MCPToolCall]) -> SCNNode {
        let ring = SCNNode()
        ring.name = "mcpCallsRing"

        for (i, call) in calls.enumerated() {
            let angle = Float(i) * (2 * Float.pi / Float(calls.count))
            let radius: Float = 0.8

            let dotGeo = SCNSphere(radius: 0.04)
            let dotMat = SCNMaterial()
            let color = call.status == .connected ? "#4CAF50" : "#F44336"
            dotMat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.7)
            dotMat.emission.contents = NSColor(hex: color)
            dotMat.emission.intensity = 0.3
            dotGeo.materials = [dotMat]
            let dotNode = SCNNode(geometry: dotGeo)
            dotNode.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)
            ring.addChildNode(dotNode)
        }

        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)
        ring.runAction(.repeatForever(ringRotate))

        return ring
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
