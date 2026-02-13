import SceneKit

// MARK: - J2: Real-time Collaboration Visualization

struct CollaborationVisualizationBuilder {

    static func buildCollaborationGraph(paths: [AgentCollaborationPath], handoffs: [TaskHandoff], metrics: [TeamEfficiencyMetric]) -> SCNNode {
        let container = SCNNode()
        container.name = "collaborationVisualization"

        // Build data flow paths as animated arcs
        for (i, path) in paths.prefix(8).enumerated() {
            let pathNode = buildFlowPath(path: path, index: i, total: min(paths.count, 8))
            container.addChildNode(pathNode)
        }

        // Build radar chart for efficiency metrics
        if !metrics.isEmpty {
            let radar = buildRadarChart(metrics: metrics)
            radar.position = SCNVector3(0, 1.5, 0)
            container.addChildNode(radar)
        }

        // Build handoff indicators
        for handoff in handoffs.prefix(3) where handoff.isAnimating {
            let handoffNode = buildHandoffIndicator(handoff: handoff)
            container.addChildNode(handoffNode)
        }

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 70.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildFlowPath(path: AgentCollaborationPath, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "collabPath_\(path.id.uuidString)"

        let angle = Float(index) / Float(total) * Float.pi * 2
        let radius: Float = 1.5

        // Source point
        let srcSphere = SCNSphere(radius: 0.08)
        let srcMat = SCNMaterial()
        srcMat.diffuse.contents = NSColor(hex: path.direction.hexColor)
        srcMat.emission.contents = NSColor(hex: path.direction.hexColor)
        srcMat.emission.intensity = 0.5
        srcSphere.materials = [srcMat]
        let srcNode = SCNNode(geometry: srcSphere)
        srcNode.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)
        node.addChildNode(srcNode)

        // Target point
        let nextAngle = Float(index + 1) / Float(total) * Float.pi * 2
        let tgtSphere = SCNSphere(radius: 0.06)
        tgtSphere.materials = [srcMat]
        let tgtNode = SCNNode(geometry: tgtSphere)
        tgtNode.position = SCNVector3(cos(nextAngle) * (radius * 0.8), 0.3, sin(nextAngle) * (radius * 0.8))
        node.addChildNode(tgtNode)

        // Connection line
        let lineNode = buildConnectionLine(from: srcNode.position, to: tgtNode.position, color: path.direction.hexColor, active: path.isActive)
        node.addChildNode(lineNode)

        // Data type label
        let label = buildLabel(path.dataType, color: NSColor.white.withAlphaComponent(0.6), fontSize: 0.04)
        label.position = SCNVector3(
            (srcNode.position.x + tgtNode.position.x) / 2,
            0.2,
            (srcNode.position.z + tgtNode.position.z) / 2
        )
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Particle flow animation for active paths
        if path.isActive {
            let particle = buildFlowParticle(color: path.direction.hexColor)
            particle.position = srcNode.position

            let moveToTarget = SCNAction.move(to: tgtNode.position, duration: 1.5)
            moveToTarget.timingMode = .easeInEaseOut
            let moveBack = SCNAction.move(to: srcNode.position, duration: 0.01)
            particle.runAction(.repeatForever(.sequence([moveToTarget, moveBack])))
            node.addChildNode(particle)
        }

        return node
    }

    private static func buildRadarChart(metrics: [TeamEfficiencyMetric]) -> SCNNode {
        let node = SCNNode()
        node.name = "radarChart"

        let radius: Float = 0.6
        let count = metrics.count

        // Draw axes
        for (i, metric) in metrics.enumerated() {
            let angle = Float(i) / Float(count) * Float.pi * 2 - Float.pi / 2
            let endX = cos(angle) * radius
            let endZ = sin(angle) * radius

            // Axis line
            let axisLine = buildThinLine(from: .init(0, 0, 0), to: .init(endX, 0, endZ), color: "#FFFFFF", alpha: 0.2)
            node.addChildNode(axisLine)

            // Value point
            let valueRadius = radius * Float(metric.value)
            let pointGeo = SCNSphere(radius: 0.03)
            let pointMat = SCNMaterial()
            pointMat.diffuse.contents = NSColor(hex: "#00BCD4")
            pointMat.emission.contents = NSColor(hex: "#00BCD4")
            pointMat.emission.intensity = 0.6
            pointGeo.materials = [pointMat]
            let pointNode = SCNNode(geometry: pointGeo)
            pointNode.position = SCNVector3(cos(angle) * valueRadius, 0, sin(angle) * valueRadius)
            node.addChildNode(pointNode)

            // Label
            let label = buildLabel(metric.label, color: NSColor.white.withAlphaComponent(0.7), fontSize: 0.04)
            label.position = SCNVector3(cos(angle) * (radius + 0.15), 0, sin(angle) * (radius + 0.15))
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            label.constraints = [billboard]
            node.addChildNode(label)
        }

        return node
    }

    private static func buildHandoffIndicator(handoff: TaskHandoff) -> SCNNode {
        let node = SCNNode()
        let arrowGeo = SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.15)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: "#FF9800")
        mat.emission.contents = NSColor(hex: "#FF9800")
        mat.emission.intensity = 0.5
        arrowGeo.materials = [mat]
        node.geometry = arrowGeo
        node.position = SCNVector3(0, 0.8, 0)

        let pulse = SCNAction.sequence([
            .fadeOpacity(to: 0.3, duration: 0.5),
            .fadeOpacity(to: 1.0, duration: 0.5)
        ])
        node.runAction(.repeatForever(pulse))

        return node
    }

    private static func buildFlowParticle(color: String) -> SCNNode {
        let sphere = SCNSphere(radius: 0.025)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: color)
        mat.emission.contents = NSColor(hex: color)
        mat.emission.intensity = 0.8
        sphere.materials = [mat]
        return SCNNode(geometry: sphere)
    }

    private static func buildConnectionLine(from: SCNVector3, to: SCNVector3, color: String, active: Bool) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let dist = sqrt(dx * dx + dy * dy + dz * dz)

        let cyl = SCNCylinder(radius: active ? 0.012 : 0.006, height: CGFloat(dist))
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: color).withAlphaComponent(active ? 0.6 : 0.2)
        mat.emission.contents = NSColor(hex: color)
        mat.emission.intensity = active ? 0.3 : 0.05
        cyl.materials = [mat]

        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2)
        node.look(at: to)
        node.eulerAngles.x += .pi / 2
        return node
    }

    private static func buildThinLine(from: SCNVector3, to: SCNVector3, color: String, alpha: CGFloat) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let dist = sqrt(dx * dx + dy * dy + dz * dz)

        let cyl = SCNCylinder(radius: 0.004, height: CGFloat(dist))
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: color).withAlphaComponent(alpha)
        cyl.materials = [mat]

        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2)
        node.look(at: to)
        node.eulerAngles.x += .pi / 2
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
