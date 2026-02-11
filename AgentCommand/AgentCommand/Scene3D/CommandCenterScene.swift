import SceneKit

class ThemeableScene: ObservableObject {
    let scene = SCNScene()
    private var agentNodes: [UUID: VoxelCharacterNode] = [:]
    private var animationControllers: [UUID: AgentAnimationController] = [:]
    private var monitorNodes: [UUID: SCNNode] = [:]
    private(set) var currentThemeBuilder: (any SceneThemeBuilder)?

    var sceneBackgroundColor: NSColor {
        currentThemeBuilder?.sceneBackgroundColor ?? NSColor(hex: "#0A0A1A")
    }

    /// Build a scene with only the environment (floor, lighting, decorations) — no workstations or agents.
    func buildEmptyScene(config: SceneConfiguration, themeBuilder: any SceneThemeBuilder) {
        // Clear existing
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        agentNodes.removeAll()
        animationControllers.removeAll()
        monitorNodes.removeAll()

        currentThemeBuilder = themeBuilder
        scene.background.contents = themeBuilder.sceneBackgroundColor

        // 1. Build environment
        let environment = themeBuilder.buildEnvironment(dimensions: config.roomSize)
        scene.rootNode.addChildNode(environment)

        // 2. Setup lighting
        themeBuilder.applyLighting(to: scene, intensity: config.ambientLightIntensity)

        // 3. Decorations
        if let decorations = themeBuilder.buildDecorations(dimensions: config.roomSize) {
            scene.rootNode.addChildNode(decorations)
        }

        // 4. Setup camera
        let cameraConfig = themeBuilder.cameraConfigOverride() ?? config.cameraDefaults
        setupCamera(config: cameraConfig)
    }

    func buildScene(config: SceneConfiguration, agents: [Agent], themeBuilder: any SceneThemeBuilder) {
        // Clear existing
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        agentNodes.removeAll()
        animationControllers.removeAll()
        monitorNodes.removeAll()

        currentThemeBuilder = themeBuilder

        // Set scene background
        scene.background.contents = themeBuilder.sceneBackgroundColor

        // 1. Build environment
        let environment = themeBuilder.buildEnvironment(dimensions: config.roomSize)
        scene.rootNode.addChildNode(environment)

        // 2. Setup lighting
        themeBuilder.applyLighting(to: scene, intensity: config.ambientLightIntensity)

        // 3. Place workstations — multi-team or single-team
        if let teamLayouts = config.teamLayouts, !teamLayouts.isEmpty {
            buildMultiTeamWorkstations(teamLayouts: teamLayouts, agents: agents, themeBuilder: themeBuilder)
        } else {
            buildSingleTeamWorkstations(config: config, themeBuilder: themeBuilder)
        }

        // 4. Place agent characters (shared voxel system)
        for agent in agents {
            let character = VoxelCharacterNode(appearance: agent.appearance, role: agent.role)
            let seatOffset: Float = agent.isMainAgent ? 0.6 : 0.5
            let charX = agent.position.x
            let charZ = agent.position.z - seatOffset
            character.position = SCNVector3(charX, 0, charZ)
            character.eulerAngles.y = CGFloat(agent.position.rotation) + .pi
            character.agentId = agent.id
            scene.rootNode.addChildNode(character)
            agentNodes[agent.id] = character

            // Place a floor tile under the character's feet
            let floorTile = themeBuilder.buildAgentFloorTile(isLeader: agent.isMainAgent)
            floorTile.position = SCNVector3(charX, -0.05, charZ)
            floorTile.eulerAngles.y = CGFloat(agent.position.rotation)
            scene.rootNode.addChildNode(floorTile)

            let controller = AgentAnimationController(characterNode: character)
            controller.transitionTo(agent.status)
            animationControllers[agent.id] = controller
        }

        // 5. Build connection lines
        buildConnectionLines(agents: agents, lineColor: themeBuilder.connectionLineColor)

        // 6. Team zone dividers (multi-team only)
        if let teamLayouts = config.teamLayouts, teamLayouts.count > 1 {
            buildTeamZoneDividers(teamLayouts: teamLayouts, roomSize: config.roomSize, themeBuilder: themeBuilder)
            buildTeamLabels(teamLayouts: teamLayouts, agents: agents, themeBuilder: themeBuilder)
        }

        // 7. Decorations
        if let decorations = themeBuilder.buildDecorations(dimensions: config.roomSize) {
            scene.rootNode.addChildNode(decorations)
        }

        // 8. Setup camera
        let cameraConfig = themeBuilder.cameraConfigOverride() ?? config.cameraDefaults
        setupCamera(config: cameraConfig)
    }

    func updateAgentStatus(_ agentId: UUID, to status: AgentStatus) {
        animationControllers[agentId]?.transitionTo(status)
    }

    func agentWorldPosition(_ agentId: UUID) -> SCNVector3? {
        agentNodes[agentId]?.worldPosition
    }

    /// Play disband animation for a team, then remove their nodes from the scene.
    /// Each agent dissolves with a slight stagger delay for a cascading effect.
    func disbandTeam(agentIds: [UUID], completion: @escaping () -> Void) {
        guard !agentIds.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()

        for (index, agentId) in agentIds.enumerated() {
            guard let character = agentNodes[agentId] else { continue }

            // Remove the current animation first
            animationControllers[agentId]?.transitionTo(.idle)

            group.enter()
            let staggerDelay = Double(index) * 0.15
            DisbandAnimation.apply(to: character, delay: staggerDelay) { [weak self] in
                self?.agentNodes.removeValue(forKey: agentId)
                self?.animationControllers.removeValue(forKey: agentId)
                group.leave()
            }
        }

        // Also fade out related furniture (workstations, floor tiles, etc.) for the team zone
        fadeOutTeamFurniture(agentIds: agentIds)

        group.notify(queue: .main) {
            // Remove connection lines and labels — they'll be rebuilt if needed
            self.removeConnectionsAndLabels()
            completion()
        }
    }

    private func fadeOutTeamFurniture(agentIds: Set<UUID>) {
        // Find floor tiles and other nodes near the agents being disbanded
        for agentId in agentIds {
            guard let character = agentNodes[agentId] else { continue }
            let charPos = character.position

            // Find nearby nodes that are part of this team's furniture
            for child in scene.rootNode.childNodes {
                guard child !== character,
                      child.name != "camera",
                      child.name != "connections",
                      child.name != "teamDividers",
                      child.name != "teamLabels",
                      child.name != "voxelCharacter" else { continue }

                // Check if this furniture node is close to the agent
                let dx = child.position.x - charPos.x
                let dz = child.position.z - charPos.z
                let dist = sqrt(dx * dx + dz * dz)
                if dist < 2.0 {
                    let fade = SCNAction.sequence([
                        .wait(duration: DisbandAnimation.duration * 0.5),
                        .fadeOut(duration: DisbandAnimation.duration * 0.5),
                        .removeFromParentNode()
                    ])
                    child.runAction(fade)
                }
            }
        }
    }

    private func fadeOutTeamFurniture(agentIds: [UUID]) {
        fadeOutTeamFurniture(agentIds: Set(agentIds))
    }

    private func removeConnectionsAndLabels() {
        // Remove and rebuild connections and labels on next scene rebuild
        scene.rootNode.childNodes.filter { $0.name == "connections" || $0.name == "teamDividers" || $0.name == "teamLabels" }
            .forEach { node in
                let fade = SCNAction.sequence([.fadeOut(duration: 0.3), .removeFromParentNode()])
                node.runAction(fade)
            }
    }

    // MARK: - Single-team workstation placement (legacy)

    private func buildSingleTeamWorkstations(config: SceneConfiguration, themeBuilder: any SceneThemeBuilder) {
        // Command workstation
        let commandWorkstation = themeBuilder.buildWorkstation(size: .large)
        commandWorkstation.position = config.commandDeskPosition.toSCNVector3()
        commandWorkstation.eulerAngles.y = CGFloat(config.commandDeskPosition.rotation)
        scene.rootNode.addChildNode(commandWorkstation)

        let commandDisplay = themeBuilder.buildDisplay(width: 0.8, height: 0.5)
        commandDisplay.position = SCNVector3(
            config.commandDeskPosition.x,
            0.8,
            config.commandDeskPosition.z + Float(DeskSize.large.depth) * 0.3
        )
        commandDisplay.eulerAngles.y = .pi
        scene.rootNode.addChildNode(commandDisplay)

        let commandSeat = themeBuilder.buildSeating()
        commandSeat.position = SCNVector3(
            config.commandDeskPosition.x,
            0,
            config.commandDeskPosition.z - Float(DeskSize.large.depth) * 0.6 - 0.3
        )
        scene.rootNode.addChildNode(commandSeat)

        // Sub-agent workstations
        for wsConfig in config.workstationPositions {
            placeWorkstation(wsConfig: wsConfig, themeBuilder: themeBuilder)
        }
    }

    // MARK: - Multi-team workstation placement

    private func buildMultiTeamWorkstations(teamLayouts: [TeamLayout], agents: [Agent], themeBuilder: any SceneThemeBuilder) {
        for layout in teamLayouts {
            // Commander workstation (large)
            let commandWorkstation = themeBuilder.buildWorkstation(size: .large)
            commandWorkstation.position = layout.commandDeskPosition.toSCNVector3()
            commandWorkstation.eulerAngles.y = CGFloat(layout.commandDeskPosition.rotation)
            scene.rootNode.addChildNode(commandWorkstation)

            let commandDisplay = themeBuilder.buildDisplay(width: 0.8, height: 0.5)
            commandDisplay.position = SCNVector3(
                layout.commandDeskPosition.x,
                0.8,
                layout.commandDeskPosition.z + Float(DeskSize.large.depth) * 0.3
            )
            commandDisplay.eulerAngles.y = .pi
            scene.rootNode.addChildNode(commandDisplay)

            let commandSeat = themeBuilder.buildSeating()
            commandSeat.position = SCNVector3(
                layout.commandDeskPosition.x,
                0,
                layout.commandDeskPosition.z - Float(DeskSize.large.depth) * 0.6 - 0.3
            )
            scene.rootNode.addChildNode(commandSeat)

            // Sub-agent workstations
            for wsConfig in layout.workstationPositions {
                placeWorkstation(wsConfig: wsConfig, themeBuilder: themeBuilder)
            }
        }
    }

    private func placeWorkstation(wsConfig: WorkstationConfig, themeBuilder: any SceneThemeBuilder) {
        let workstation = themeBuilder.buildWorkstation(size: wsConfig.size)
        workstation.position = wsConfig.position.toSCNVector3()
        workstation.eulerAngles.y = CGFloat(wsConfig.position.rotation)
        scene.rootNode.addChildNode(workstation)

        let wsDisplay = themeBuilder.buildDisplay(width: 0.5, height: 0.35)
        wsDisplay.position = SCNVector3(
            wsConfig.position.x,
            0.8,
            wsConfig.position.z + Float(wsConfig.size.depth) * 0.3
        )
        wsDisplay.eulerAngles.y = CGFloat(wsConfig.position.rotation) + .pi
        scene.rootNode.addChildNode(wsDisplay)

        let wsSeat = themeBuilder.buildSeating()
        wsSeat.position = SCNVector3(
            wsConfig.position.x,
            0,
            wsConfig.position.z - Float(wsConfig.size.depth) * 0.6 - 0.3
        )
        wsSeat.eulerAngles.y = CGFloat(wsConfig.position.rotation)
        scene.rootNode.addChildNode(wsSeat)
    }

    // MARK: - Team zone dividers

    private func buildTeamZoneDividers(teamLayouts: [TeamLayout], roomSize: RoomDimensions, themeBuilder: any SceneThemeBuilder) {
        guard teamLayouts.count > 1 else { return }

        let dividerGroup = SCNNode()
        dividerGroup.name = "teamDividers"

        let accentColor = themeBuilder.connectionLineColor.withAlphaComponent(0.2)
        let material = SCNMaterial()
        material.diffuse.contents = accentColor
        material.emission.contents = themeBuilder.connectionLineColor.withAlphaComponent(0.15)
        material.emission.intensity = 0.5

        // Sort layouts by X position to find boundaries between adjacent teams
        let sorted = teamLayouts.sorted { $0.commandDeskPosition.x < $1.commandDeskPosition.x }
        for i in 0..<(sorted.count - 1) {
            let leftX = sorted[i].commandDeskPosition.x
            let rightX = sorted[i + 1].commandDeskPosition.x
            let midX = (leftX + rightX) / 2.0

            let lineGeo = SCNBox(width: 0.03, height: 0.01, length: CGFloat(roomSize.depth), chamferRadius: 0)
            lineGeo.materials = [material]
            let lineNode = SCNNode(geometry: lineGeo)
            lineNode.position = SCNVector3(midX, 0.005, roomSize.depth / 2.0 - 2.0)
            dividerGroup.addChildNode(lineNode)
        }

        scene.rootNode.addChildNode(dividerGroup)
    }

    // MARK: - Team labels

    private func buildTeamLabels(teamLayouts: [TeamLayout], agents: [Agent], themeBuilder: any SceneThemeBuilder) {
        let labelGroup = SCNNode()
        labelGroup.name = "teamLabels"

        for layout in teamLayouts {
            guard let commander = agents.first(where: { $0.id == layout.commanderId }) else { continue }

            let text = SCNText(string: commander.name, extrusionDepth: 0.02)
            text.font = NSFont.systemFont(ofSize: 0.3, weight: .bold)
            text.flatness = 0.1
            text.firstMaterial?.diffuse.contents = themeBuilder.connectionLineColor.withAlphaComponent(0.7)
            text.firstMaterial?.emission.contents = themeBuilder.connectionLineColor.withAlphaComponent(0.3)
            text.firstMaterial?.emission.intensity = 0.5

            let textNode = SCNNode(geometry: text)
            // Center the text above the commander desk
            let (minBound, maxBound) = textNode.boundingBox
            let textWidth = Float(maxBound.x - minBound.x)
            textNode.position = SCNVector3(
                layout.commandDeskPosition.x - textWidth / 2.0,
                Float(3.0),
                layout.commandDeskPosition.z - 1.5
            )

            // Make it face the camera (billboard constraint)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .Y
            textNode.constraints = [constraint]

            labelGroup.addChildNode(textNode)
        }

        scene.rootNode.addChildNode(labelGroup)
    }

    // MARK: - Connection lines

    private func buildConnectionLines(agents: [Agent], lineColor: NSColor) {
        let connectionsGroup = SCNNode()
        connectionsGroup.name = "connections"

        for agent in agents {
            guard let parentId = agent.parentAgentId,
                  let parentNode = agentNodes[parentId],
                  let childNode = agentNodes[agent.id] else { continue }

            let from = SCNVector3(parentNode.position.x, 1.8, parentNode.position.z)
            let to = SCNVector3(childNode.position.x, 1.8, childNode.position.z)

            let lineNode = createDashedLine(from: from, to: to, color: lineColor.withAlphaComponent(0.5))
            connectionsGroup.addChildNode(lineNode)
        }

        scene.rootNode.addChildNode(connectionsGroup)
    }

    private func createDashedLine(from: SCNVector3, to: SCNVector3, color: NSColor) -> SCNNode {
        let parent = SCNNode()
        let direction = to - from
        let distance = direction.length
        let normalized = direction.normalized
        let segmentLength: Float = 0.15
        let gapLength: Float = 0.1
        let step = segmentLength + gapLength
        var current: Float = 0

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 0.3

        while current < distance {
            let segEnd = min(current + segmentLength, distance)
            let startPos = from + normalized * current
            let endPos = from + normalized * segEnd

            let mid = SCNVector3(
                (startPos.x + endPos.x) / 2,
                (startPos.y + endPos.y) / 2,
                (startPos.z + endPos.z) / 2
            )

            let len = CGFloat(segEnd - current)
            let seg = SCNBox(width: 0.02, height: 0.02, length: len, chamferRadius: 0)
            seg.materials = [material]
            let segNode = SCNNode(geometry: seg)
            segNode.position = mid
            segNode.look(at: endPos)
            parent.addChildNode(segNode)

            current += step
        }

        return parent
    }

    private func setupCamera(config: CameraConfig) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = CGFloat(config.fieldOfView)
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.position = config.position.toSCNVector3()
        cameraNode.look(at: config.lookAtTarget.toSCNVector3())
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)
    }
}
