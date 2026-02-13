import SceneKit

// MARK: - I4: Multi-Project Workspace Visualization

struct MultiProjectVisualizationBuilder {

    // MARK: - Project Graph

    static func buildProjectGraph(projects: [ProjectWorkspace]) -> SCNNode {
        let container = SCNNode()
        container.name = "multiProjectVisualization"

        let projectsToShow = Array(projects.prefix(12))
        guard !projectsToShow.isEmpty else { return container }

        // Calculate positions in a spherical/circular layout
        var positions: [UUID: SCNVector3] = [:]
        let radius: Float = 3.5

        for (i, project) in projectsToShow.enumerated() {
            let angle = Float(i) / Float(projectsToShow.count) * Float.pi * 2
            let yOffset = Float(i % 3) * 0.5 - 0.5
            let pos = SCNVector3(
                sin(angle) * radius,
                yOffset,
                -cos(angle) * radius
            )
            positions[project.id] = pos

            let projectNode = buildProjectSphere(project: project, index: i, total: projectsToShow.count)
            projectNode.position = pos
            container.addChildNode(projectNode)
        }

        // Draw connection lines between projects that share resources
        // (connect projects that are both active, implying shared context)
        let activeProjects = projectsToShow.filter { $0.isActive }
        for i in 0..<activeProjects.count {
            for j in (i + 1)..<activeProjects.count {
                guard let fromPos = positions[activeProjects[i].id],
                      let toPos = positions[activeProjects[j].id] else { continue }
                let connectionNode = buildConnectionLine(from: fromPos, to: toPos)
                container.addChildNode(connectionNode)
            }
        }

        // Title label
        let titleLabel = buildLabel("MULTI-PROJECT WORKSPACE", color: NSColor(hex: "#00BCD4"), fontSize: 0.12)
        titleLabel.position = SCNVector3(0, 3.0, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        titleLabel.constraints = [billboard]
        container.addChildNode(titleLabel)

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 60.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    // MARK: - Project Sphere

    private static func buildProjectSphere(project: ProjectWorkspace, index: Int, total: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "projectSphere_\(project.id.uuidString)"

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        let projectColor = NSColor(hex: project.iconColor)

        // Sphere size based on task count (normalized)
        let minRadius: CGFloat = 0.2
        let maxRadius: CGFloat = 0.6
        let taskScale = min(1.0, CGFloat(project.totalTasks) / 50.0)
        let sphereRadius = minRadius + (maxRadius - minRadius) * taskScale

        // Main sphere
        let sphere = SCNSphere(radius: sphereRadius)
        let sphereMat = SCNMaterial()
        sphereMat.diffuse.contents = projectColor.withAlphaComponent(0.7)
        sphereMat.emission.contents = projectColor
        sphereMat.emission.intensity = project.isActive ? 0.6 : 0.15
        sphere.materials = [sphereMat]
        let sphereNode = SCNNode(geometry: sphere)
        container.addChildNode(sphereNode)

        // Active glow ring
        if project.isActive {
            let glow = SCNSphere(radius: sphereRadius * 1.3)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = projectColor.withAlphaComponent(0.08)
            glowMat.emission.contents = projectColor
            glowMat.emission.intensity = 0.3
            glowMat.isDoubleSided = true
            glow.materials = [glowMat]
            let glowNode = SCNNode(geometry: glow)
            container.addChildNode(glowNode)

            // Pulse for active projects
            let pulse = SCNAction.customAction(duration: 2.0) { node, elapsed in
                let t = Float(elapsed) / 2.0
                let intensity = 0.2 + 0.2 * sin(t * Float.pi * 2)
                node.geometry?.materials.first?.emission.intensity = CGFloat(intensity)
            }
            glowNode.runAction(.repeatForever(pulse))

            // Orbiting status ring
            let ring = SCNTorus(ringRadius: sphereRadius * 1.15, pipeRadius: 0.015)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = projectColor.withAlphaComponent(0.5)
            ringMat.emission.contents = projectColor
            ringMat.emission.intensity = 0.5
            ring.materials = [ringMat]
            let ringNode = SCNNode(geometry: ring)
            ringNode.eulerAngles.x = CGFloat.pi / 3
            container.addChildNode(ringNode)

            let rotateRing = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 4.0)
            ringNode.runAction(.repeatForever(rotateRing))
        }

        // Project name label
        let displayName = String(project.name.prefix(20))
        let nameText = SCNText(string: displayName, extrusionDepth: 0.005)
        nameText.font = NSFont(name: "Menlo-Bold", size: 0.08) ?? NSFont.monospacedSystemFont(ofSize: 0.08, weight: .bold)
        nameText.flatness = 0.3
        let nameMat = SCNMaterial()
        nameMat.diffuse.contents = NSColor.white
        nameMat.emission.contents = NSColor.white
        nameMat.emission.intensity = 0.3
        nameText.materials = [nameMat]
        let nameNode = SCNNode(geometry: nameText)
        let (minBound, maxBound) = nameNode.boundingBox
        let nameWidth = maxBound.x - minBound.x
        nameNode.position = SCNVector3(-nameWidth / 2, sphereRadius + 0.12, 0.01)
        nameNode.scale = SCNVector3(0.5, 0.5, 0.5)
        container.addChildNode(nameNode)

        // Task count badge
        let taskStr = "\(project.completedTasks)/\(project.totalTasks) tasks"
        let taskLabel = buildLabel(taskStr, color: NSColor(hex: "#8B949E"), fontSize: 0.05)
        taskLabel.position = SCNVector3(0, Float(sphereRadius) + 0.02, 0.01)
        let taskBillboard = SCNBillboardConstraint()
        taskBillboard.freeAxes = .Y
        taskLabel.constraints = [taskBillboard]
        container.addChildNode(taskLabel)

        // Agent count indicator (small spheres orbiting)
        for a in 0..<min(project.activeAgentCount, 4) {
            let agentAngle = Float(a) / Float(min(project.activeAgentCount, 4)) * Float.pi * 2
            let agentSphere = SCNSphere(radius: 0.05)
            let agentMat = SCNMaterial()
            agentMat.diffuse.contents = NSColor(hex: "#58A6FF")
            agentMat.emission.contents = NSColor(hex: "#58A6FF")
            agentMat.emission.intensity = 0.6
            agentSphere.materials = [agentMat]
            let agentNode = SCNNode(geometry: agentSphere)
            let orbitRadius = Float(sphereRadius) + 0.25
            agentNode.position = SCNVector3(
                cos(agentAngle) * orbitRadius,
                -Float(sphereRadius) - 0.1,
                sin(agentAngle) * orbitRadius
            )
            container.addChildNode(agentNode)
        }

        // Success rate arc indicator
        if project.totalTasks > 0 {
            let successRate = project.successRate
            let rateStr = String(format: "%.0f%%", successRate * 100)
            let rateColor: NSColor
            if successRate >= 0.8 {
                rateColor = NSColor(hex: "#4CAF50")
            } else if successRate >= 0.5 {
                rateColor = NSColor(hex: "#FF9800")
            } else {
                rateColor = NSColor(hex: "#F44336")
            }
            let rateLabel = buildLabel(rateStr, color: rateColor, fontSize: 0.06)
            rateLabel.position = SCNVector3(0, -Float(sphereRadius) - 0.15, 0.01)
            let rateBillboard = SCNBillboardConstraint()
            rateBillboard.freeAxes = .Y
            rateLabel.constraints = [rateBillboard]
            container.addChildNode(rateLabel)
        }

        // Floating bob animation
        let bobDuration = 2.5 + Double(index % 5) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }

    // MARK: - Connection Line

    private static func buildConnectionLine(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let container = SCNNode()

        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        guard distance > 0.1 else { return container }

        // Dashed line using small spheres
        let dashCount = Int(distance / 0.2)
        let lineColor = NSColor(hex: "#00BCD4")

        for i in 0..<dashCount where i % 2 == 0 {
            let t = CGFloat(i) / CGFloat(max(dashCount, 1))
            let pos = SCNVector3(
                from.x + dx * t,
                from.y + dy * t,
                from.z + dz * t
            )

            let dash = SCNSphere(radius: 0.015)
            let dashMat = SCNMaterial()
            dashMat.diffuse.contents = lineColor.withAlphaComponent(0.3)
            dashMat.emission.contents = lineColor
            dashMat.emission.intensity = 0.2
            dash.materials = [dashMat]
            let dashNode = SCNNode(geometry: dash)
            dashNode.position = pos
            container.addChildNode(dashNode)
        }

        return container
    }

    // MARK: - Helpers

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
