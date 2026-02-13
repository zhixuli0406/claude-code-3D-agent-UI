import SceneKit

// MARK: - M5: Team Performance 3D Visualization Builder

struct TeamPerformanceVisualizationBuilder {
    /// Build a 3D visualization of team performance
    static func build(snapshot: TeamPerformanceSnapshot?, radarData: TeamRadarData?, leaderboard: TeamLeaderboard? = nil, parentNode: SCNNode) {
        let rootNode = SCNNode()
        rootNode.name = "teamPerformanceVisualization"
        rootNode.position = SCNVector3(x: 4.0, y: 2.5, z: -3.0)

        // Central performance hub
        if let snapshot = snapshot {
            buildPerformanceHub(snapshot: snapshot, parentNode: rootNode)
            buildMemberColumns(members: snapshot.memberMetrics, parentNode: rootNode)
            buildSpecializationOrbit(members: snapshot.memberMetrics, parentNode: rootNode)
        }

        // Radar chart ring
        if let radar = radarData {
            buildRadarRing(radar: radar, parentNode: rootNode)
        }

        // Leaderboard podium
        if let leaderboard = leaderboard {
            buildLeaderboardPodium(leaderboard: leaderboard, parentNode: rootNode)
        }

        parentNode.addChildNode(rootNode)
    }

    /// Remove team performance visualization from scene
    static func remove(from parentNode: SCNNode) {
        parentNode.childNode(withName: "teamPerformanceVisualization", recursively: true)?.removeFromParentNode()
    }

    // MARK: - Performance Hub

    private static func buildPerformanceHub(snapshot: TeamPerformanceSnapshot, parentNode: SCNNode) {
        let hubGeometry = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0.05)
        let hubMaterial = SCNMaterial()
        hubMaterial.diffuse.contents = NSColor(hex: snapshot.efficiencyColorHex)
        hubMaterial.emission.contents = NSColor(hex: snapshot.efficiencyColorHex).withAlphaComponent(0.5)
        hubMaterial.transparency = 0.85
        hubGeometry.materials = [hubMaterial]

        let hubNode = SCNNode(geometry: hubGeometry)
        hubNode.name = "performanceHub"
        hubNode.position = SCNVector3(x: 0, y: 0, z: 0)

        // Rotation animation
        let rotation = CABasicAnimation(keyPath: "rotation")
        rotation.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
        rotation.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, CGFloat.pi * 2))
        rotation.duration = 12.0
        rotation.repeatCount = .infinity
        hubNode.addAnimation(rotation, forKey: "rotation")

        parentNode.addChildNode(hubNode)

        // Efficiency ring around hub
        let ringGeometry = SCNTorus(ringRadius: 0.4, pipeRadius: 0.015)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = NSColor(hex: "#FF5722")
        ringMaterial.emission.contents = NSColor(hex: "#FF5722").withAlphaComponent(0.4)
        ringGeometry.materials = [ringMaterial]

        let ringNode = SCNNode(geometry: ringGeometry)
        ringNode.name = "efficiencyRing"
        parentNode.addChildNode(ringNode)
    }

    // MARK: - Member Columns

    private static func buildMemberColumns(members: [AgentPerformanceMetric], parentNode: SCNNode) {
        let visibleMembers = Array(members.prefix(6))
        let columnRadius: CGFloat = 1.2
        let angleStep = CGFloat.pi * 2 / max(1, CGFloat(visibleMembers.count))

        for (index, member) in visibleMembers.enumerated() {
            let angle = angleStep * CGFloat(index)
            let x = columnRadius * cos(angle)
            let z = columnRadius * sin(angle)

            // Column height based on efficiency
            let height = CGFloat(0.2 + member.efficiency * 0.8)
            let columnGeometry = SCNCylinder(radius: 0.06, height: height)
            let columnMaterial = SCNMaterial()
            columnMaterial.diffuse.contents = NSColor(hex: member.specialization.colorHex)
            columnMaterial.emission.contents = NSColor(hex: member.specialization.colorHex).withAlphaComponent(0.3)
            columnGeometry.materials = [columnMaterial]

            let columnNode = SCNNode(geometry: columnGeometry)
            columnNode.position = SCNVector3(x: x, y: height / 2 - 0.3, z: z)
            columnNode.name = "member_\(member.agentName)"

            parentNode.addChildNode(columnNode)

            // Top indicator sphere
            let indicatorGeometry = SCNSphere(radius: 0.04)
            let indicatorMaterial = SCNMaterial()
            let indicatorColor = member.efficiency > 0.8 ? "#4CAF50" : (member.efficiency > 0.6 ? "#FF9800" : "#F44336")
            indicatorMaterial.diffuse.contents = NSColor(hex: indicatorColor)
            indicatorMaterial.emission.contents = NSColor(hex: indicatorColor).withAlphaComponent(0.6)
            indicatorGeometry.materials = [indicatorMaterial]

            let indicatorNode = SCNNode(geometry: indicatorGeometry)
            indicatorNode.position = SCNVector3(x: x, y: height - 0.3 + 0.06, z: z)

            // Glow animation
            let glow = CABasicAnimation(keyPath: "scale")
            glow.fromValue = NSValue(scnVector3: SCNVector3(1, 1, 1))
            glow.toValue = NSValue(scnVector3: SCNVector3(1.3, 1.3, 1.3))
            glow.duration = 1.5
            glow.autoreverses = true
            glow.repeatCount = .infinity
            indicatorNode.addAnimation(glow, forKey: "glow")

            parentNode.addChildNode(indicatorNode)
        }
    }

    // MARK: - Radar Ring

    private static func buildRadarRing(radar: TeamRadarData, parentNode: SCNNode) {
        let radarRadius: CGFloat = 0.8
        let dimensions = radar.dimensions
        guard !dimensions.isEmpty else { return }

        let angleStep = CGFloat.pi * 2 / CGFloat(dimensions.count)

        for (index, dimension) in dimensions.enumerated() {
            let angle = angleStep * CGFloat(index)
            let scale = CGFloat(dimension.value)
            let x = radarRadius * scale * cos(angle)
            let z = radarRadius * scale * sin(angle)

            let dotGeometry = SCNSphere(radius: 0.025)
            let dotMaterial = SCNMaterial()
            dotMaterial.diffuse.contents = NSColor(hex: "#FF5722")
            dotMaterial.emission.contents = NSColor(hex: "#FF5722").withAlphaComponent(0.5)
            dotGeometry.materials = [dotMaterial]

            let dotNode = SCNNode(geometry: dotGeometry)
            dotNode.position = SCNVector3(x: x, y: -0.5, z: z)
            dotNode.name = "radar_\(dimension.category.rawValue)"

            parentNode.addChildNode(dotNode)

            // Axis line
            let axisX: CGFloat = radarRadius * cos(angle)
            let axisZ: CGFloat = radarRadius * sin(angle)

            let lineNode = createLine(
                from: SCNVector3(x: 0, y: -0.5, z: 0),
                to: SCNVector3(x: axisX, y: -0.5, z: axisZ),
                color: NSColor(hex: "#FF5722").withAlphaComponent(0.15)
            )
            parentNode.addChildNode(lineNode)

            // Connect radar dots
            if index > 0 {
                let prevAngle = angleStep * CGFloat(index - 1)
                let prevScale = CGFloat(dimensions[index - 1].value)
                let prevX = radarRadius * prevScale * cos(prevAngle)
                let prevZ = radarRadius * prevScale * sin(prevAngle)

                let connectLine = createLine(
                    from: SCNVector3(x: prevX, y: -0.5, z: prevZ),
                    to: SCNVector3(x: x, y: -0.5, z: z),
                    color: NSColor(hex: "#FF5722").withAlphaComponent(0.4)
                )
                parentNode.addChildNode(connectLine)
            }

            // Close the radar shape
            if index == dimensions.count - 1 {
                let firstScale = CGFloat(dimensions[0].value)
                let firstX = radarRadius * firstScale * cos(0)
                let firstZ = radarRadius * firstScale * sin(0)

                let closeLine = createLine(
                    from: SCNVector3(x: x, y: -0.5, z: z),
                    to: SCNVector3(x: firstX, y: -0.5, z: firstZ),
                    color: NSColor(hex: "#FF5722").withAlphaComponent(0.4)
                )
                parentNode.addChildNode(closeLine)
            }
        }
    }

    // MARK: - Specialization Orbit

    private static func buildSpecializationOrbit(members: [AgentPerformanceMetric], parentNode: SCNNode) {
        let specGroups = Dictionary(grouping: members, by: \.specialization)
        let orbitRadius: Float = 1.8
        let orbitY: Float = 0.5
        let angleStep = Float.pi * 2 / max(1, Float(specGroups.count))

        for (index, (spec, groupMembers)) in specGroups.enumerated() {
            let angle = angleStep * Float(index)
            let x = orbitRadius * cos(angle)
            let z = orbitRadius * sin(angle)

            // Specialization node - size based on member count
            let nodeSize = CGFloat(0.03 + Double(groupMembers.count) * 0.02)
            let specGeometry = SCNBox(width: nodeSize * 2, height: nodeSize * 2, length: nodeSize * 2, chamferRadius: nodeSize * 0.3)
            let specMaterial = SCNMaterial()
            specMaterial.diffuse.contents = NSColor(hex: spec.colorHex).withAlphaComponent(0.6)
            specMaterial.emission.contents = NSColor(hex: spec.colorHex)
            specMaterial.emission.intensity = 0.4
            specGeometry.materials = [specMaterial]

            let specNode = SCNNode(geometry: specGeometry)
            specNode.position = SCNVector3(x, orbitY, z)
            specNode.name = "spec_\(spec.rawValue)"

            // Slow rotation
            let rotation = CABasicAnimation(keyPath: "rotation")
            rotation.fromValue = NSValue(scnVector4: SCNVector4(1, 1, 0, 0))
            rotation.toValue = NSValue(scnVector4: SCNVector4(1, 1, 0, Float.pi * 2))
            rotation.duration = Double.random(in: 6...10)
            rotation.repeatCount = .infinity
            specNode.addAnimation(rotation, forKey: "rotation")

            parentNode.addChildNode(specNode)

            // Connection to center
            let lineNode = createLine(
                from: SCNVector3(0, orbitY, 0),
                to: SCNVector3(x, orbitY, z),
                color: NSColor(hex: spec.colorHex).withAlphaComponent(0.15)
            )
            parentNode.addChildNode(lineNode)
        }
    }

    // MARK: - Leaderboard Podium

    private static func buildLeaderboardPodium(leaderboard: TeamLeaderboard, parentNode: SCNNode) {
        let topEntries = Array(leaderboard.entries.prefix(3))
        guard !topEntries.isEmpty else { return }

        let podiumBaseY: Float = -1.0
        let podiumZ: Float = 1.0

        // Podium heights for 1st, 2nd, 3rd
        let heights: [Float] = [0.5, 0.35, 0.25]
        let positions: [Float] = [0, -0.25, 0.25]
        let colors: [String] = ["#FFD700", "#C0C0C0", "#CD7F32"]

        for (index, entry) in topEntries.enumerated() {
            let height = heights[index]
            let xPos = positions[index]

            // Podium block
            let podiumGeometry = SCNBox(width: CGFloat(0.18), height: CGFloat(height), length: CGFloat(0.15), chamferRadius: CGFloat(0.02))
            let podiumMaterial = SCNMaterial()
            podiumMaterial.diffuse.contents = NSColor(hex: colors[index]).withAlphaComponent(0.5)
            podiumMaterial.emission.contents = NSColor(hex: colors[index])
            podiumMaterial.emission.intensity = 0.3
            podiumGeometry.materials = [podiumMaterial]

            let podiumNode = SCNNode(geometry: podiumGeometry)
            podiumNode.position = SCNVector3(xPos, podiumBaseY + height / 2, podiumZ)
            podiumNode.name = "podium_\(entry.rank)"

            parentNode.addChildNode(podiumNode)

            // Winner sphere on top
            let sphereGeometry = SCNSphere(radius: 0.04)
            let sphereMaterial = SCNMaterial()
            sphereMaterial.diffuse.contents = NSColor(hex: colors[index])
            sphereMaterial.emission.contents = NSColor(hex: colors[index]).withAlphaComponent(0.6)
            sphereGeometry.materials = [sphereMaterial]

            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.position = SCNVector3(xPos, podiumBaseY + height + 0.06, podiumZ)

            // Bounce animation for the winner
            if index == 0 {
                let bounce = CABasicAnimation(keyPath: "position.y")
                bounce.fromValue = podiumBaseY + Float(height) + 0.06
                bounce.toValue = podiumBaseY + Float(height) + 0.12
                bounce.duration = 1.0
                bounce.autoreverses = true
                bounce.repeatCount = .infinity
                sphereNode.addAnimation(bounce, forKey: "bounce")
            }

            parentNode.addChildNode(sphereNode)
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
