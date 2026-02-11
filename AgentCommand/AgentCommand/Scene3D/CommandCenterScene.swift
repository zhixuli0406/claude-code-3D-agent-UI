import SceneKit

class ThemeableScene: ObservableObject {
    let scene = SCNScene()
    private var agentNodes: [UUID: VoxelCharacterNode] = [:]
    private var animationControllers: [UUID: AgentAnimationController] = [:]
    private var monitorNodes: [UUID: SCNNode] = [:]
    private var interactiveObjects: [InteractiveObjectNode] = []
    /// Stores the desk position for each agent, used by walk-to-desk and visit animations
    private var agentDeskPositions: [UUID: SCNVector3] = [:]
    /// Tracks which agents are currently walking (to avoid conflicting animations)
    private var walkingAgents: Set<UUID> = []
    private(set) var currentThemeBuilder: (any SceneThemeBuilder)?
    private var currentSceneConfig: SceneConfiguration?
    private let ambientParticles = AmbientParticleSystem()
    let chatBubbleManager = ChatBubbleManager()
    /// Callback when an interactive object is clicked
    var onInteractiveObjectClicked: ((InteractiveObjectType, UUID?) -> Void)?

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
        interactiveObjects.removeAll()
        agentDeskPositions.removeAll()
        walkingAgents.removeAll()
        ambientParticles.stop()

        currentThemeBuilder = themeBuilder
        currentSceneConfig = config
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

        // 5. Ambient particles
        ambientParticles.start(in: scene, theme: themeBuilder.theme, dimensions: config.roomSize)
    }

    func buildScene(config: SceneConfiguration, agents: [Agent], themeBuilder: any SceneThemeBuilder) {
        // Clear existing
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        agentNodes.removeAll()
        animationControllers.removeAll()
        monitorNodes.removeAll()
        interactiveObjects.removeAll()
        agentDeskPositions.removeAll()
        walkingAgents.removeAll()
        ambientParticles.stop()
        chatBubbleManager.removeAll()

        currentThemeBuilder = themeBuilder
        currentSceneConfig = config

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
            let deskPosition = SCNVector3(charX, 0, charZ)
            character.position = deskPosition
            character.eulerAngles.y = CGFloat(agent.position.rotation) + .pi
            character.agentId = agent.id
            scene.rootNode.addChildNode(character)
            agentNodes[agent.id] = character
            agentDeskPositions[agent.id] = deskPosition

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

        // 7.5. Place interactive objects (door, server rack, whiteboard)
        placeInteractiveObjects(roomSize: config.roomSize, themeBuilder: themeBuilder)

        // 8. Setup camera
        let cameraConfig = themeBuilder.cameraConfigOverride() ?? config.cameraDefaults
        setupCamera(config: cameraConfig)

        // 9. Ambient particles
        ambientParticles.start(in: scene, theme: themeBuilder.theme, dimensions: config.roomSize)

        // 10. Setup chat bubble manager
        chatBubbleManager.setup(scene: scene) { [weak self] agentId in
            self?.agentNodes[agentId]
        }
    }

    func updateAgentStatus(_ agentId: UUID, to status: AgentStatus) {
        animationControllers[agentId]?.transitionTo(status)
    }

    func agentWorldPosition(_ agentId: UUID) -> SCNVector3? {
        agentNodes[agentId]?.worldPosition
    }

    /// Play streak-break particle effect on an agent
    func playStreakBreakEffect(agentId: UUID, lostStreak: Int) {
        guard let character = agentNodes[agentId] else { return }
        let effect = ParticleEffectBuilder.buildStreakBreakEffect(lostStreak: lostStreak)
        character.addChildNode(effect)
    }

    // MARK: - Selection Highlight

    private var selectedHighlightId: UUID?

    func highlightAgent(_ agentId: UUID) {
        if let prevId = selectedHighlightId, prevId != agentId {
            agentNodes[prevId]?.hideSelectionHighlight()
        }
        agentNodes[agentId]?.showSelectionHighlight()
        selectedHighlightId = agentId
    }

    func unhighlightAgent(_ agentId: UUID) {
        agentNodes[agentId]?.hideSelectionHighlight()
        if selectedHighlightId == agentId {
            selectedHighlightId = nil
        }
    }

    func clearSelectionHighlight() {
        if let prevId = selectedHighlightId {
            agentNodes[prevId]?.hideSelectionHighlight()
            selectedHighlightId = nil
        }
    }

    // MARK: - Drop Target Highlight

    private var dropHighlightAgentId: UUID?

    func showDropHighlight(_ agentId: UUID) {
        // Clear previous if different
        if let prevId = dropHighlightAgentId, prevId != agentId {
            hideDropHighlightFor(prevId)
        }

        guard let character = agentNodes[agentId] else { return }
        guard character.childNode(withName: "dropHighlight", recursively: false) == nil else { return }

        // Green glow ring at agent's feet
        let ring = SCNTorus(ringRadius: 0.7, pipeRadius: 0.04)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#4CAF50").withAlphaComponent(0.9)
        material.emission.contents = NSColor(hex: "#4CAF50")
        material.emission.intensity = 1.5
        ring.materials = [material]

        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "dropHighlight"
        ringNode.position = SCNVector3(0, 0.05, 0)

        // Pulsing scale animation
        let scaleUp = SCNAction.scale(to: 1.25, duration: 0.4)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SCNAction.scale(to: 0.85, duration: 0.4)
        scaleDown.timingMode = .easeInEaseOut
        ringNode.runAction(.repeatForever(.sequence([scaleUp, scaleDown])), forKey: "dropPulse")

        // Rotation animation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 1.5)
        ringNode.runAction(.repeatForever(rotate), forKey: "dropRotate")

        ringNode.opacity = 0
        character.addChildNode(ringNode)
        ringNode.runAction(.fadeIn(duration: 0.15))

        // Boost agent glow
        setAgentDropGlow(character, enabled: true)

        dropHighlightAgentId = agentId
    }

    func clearDropHighlight() {
        if let prevId = dropHighlightAgentId {
            hideDropHighlightFor(prevId)
            dropHighlightAgentId = nil
        }
    }

    private func hideDropHighlightFor(_ agentId: UUID) {
        guard let character = agentNodes[agentId] else { return }
        if let ring = character.childNode(withName: "dropHighlight", recursively: false) {
            ring.runAction(.sequence([.fadeOut(duration: 0.15), .removeFromParentNode()]))
        }
        setAgentDropGlow(character, enabled: false)
    }

    private func setAgentDropGlow(_ character: VoxelCharacterNode, enabled: Bool) {
        character.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry, node.name != "dropHighlight" else { return }
            for mat in geometry.materials {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.2
                if enabled {
                    mat.emission.contents = NSColor(hex: "#4CAF50").withAlphaComponent(0.4)
                    mat.emission.intensity = 0.6
                } else {
                    mat.emission.contents = NSColor.black
                    mat.emission.intensity = 0
                }
                SCNTransaction.commit()
            }
        }
    }

    // MARK: - Camera Zoom to Agent

    func zoomToAgent(_ agentId: UUID) {
        guard let character = agentNodes[agentId] else { return }
        let targetPos = character.worldPosition

        guard let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }

        let newCamPos = SCNVector3(targetPos.x + 2.5, targetPos.y + 3.0, targetPos.z + 3.5)
        let lookAt = SCNVector3(targetPos.x, targetPos.y + 1.0, targetPos.z)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = newCamPos
        cameraNode.look(at: lookAt)
        SCNTransaction.commit()
    }

    // MARK: - Camera Presets

    enum CameraPreset {
        case overview
        case closeUp
        case cinematic
    }

    func setCameraPreset(_ preset: CameraPreset) {
        guard let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }

        let themeConfig = currentThemeBuilder?.cameraConfigOverride()
        let sceneDefaults = currentSceneConfig?.cameraDefaults
        let defaultPos = themeConfig?.position.toSCNVector3() ?? sceneDefaults?.position.toSCNVector3() ?? SCNVector3(0, 8, 12)
        let defaultTarget = themeConfig?.lookAtTarget.toSCNVector3() ?? sceneDefaults?.lookAtTarget.toSCNVector3() ?? SCNVector3(0, 1, 0)

        let newPos: SCNVector3
        let lookAt: SCNVector3
        let fov: CGFloat

        switch preset {
        case .overview:
            newPos = defaultPos
            lookAt = defaultTarget
            fov = CGFloat(themeConfig?.fieldOfView ?? sceneDefaults?.fieldOfView ?? 60)
        case .closeUp:
            newPos = SCNVector3(defaultPos.x * 0.4, defaultPos.y * 0.5, defaultPos.z * 0.4)
            lookAt = defaultTarget
            fov = 45
        case .cinematic:
            newPos = SCNVector3(defaultPos.x + 5, defaultPos.y * 0.3, defaultPos.z + 2)
            lookAt = SCNVector3(defaultTarget.x, defaultTarget.y + 0.5, defaultTarget.z)
            fov = 75
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.2
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = newPos
        cameraNode.look(at: lookAt)
        cameraNode.camera?.fieldOfView = fov
        SCNTransaction.commit()
    }

    // MARK: - Code Rain Effect

    func showCodeRainOnAgent(_ agentId: UUID) {
        guard let character = agentNodes[agentId],
              character.childNode(withName: "codeRain", recursively: false) == nil else { return }
        let rain = ParticleEffectBuilder.buildCodeRain()
        rain.position = SCNVector3(0, 2.5, 0)
        character.addChildNode(rain)
    }

    func hideCodeRainOnAgent(_ agentId: UUID) {
        guard let character = agentNodes[agentId],
              let rain = character.childNode(withName: "codeRain", recursively: false) else { return }
        rain.runAction(.sequence([.fadeOut(duration: 0.5), .removeFromParentNode()]))
    }

    // MARK: - Lightning Effect

    func showLightningOnAgent(_ agentId: UUID) {
        guard let character = agentNodes[agentId],
              character.childNode(withName: "lightningEffect", recursively: false) == nil else { return }
        let lightning = ParticleEffectBuilder.buildLightningEffect()
        lightning.position = SCNVector3(0, 1.5, 0)
        character.addChildNode(lightning)
    }

    func hideLightningOnAgent(_ agentId: UUID) {
        guard let character = agentNodes[agentId],
              let lightning = character.childNode(withName: "lightningEffect", recursively: false) else { return }
        lightning.runAction(.sequence([.fadeOut(duration: 0.3), .removeFromParentNode()]))
    }

    // MARK: - Chat Bubbles

    func updateChatBubble(agentId: UUID, text: String?, style: ChatBubbleNode.BubbleStyle, toolIcon: ToolIcon?) {
        chatBubbleManager.updateBubble(agentId: agentId, text: text, style: style, toolIcon: toolIcon)
    }

    func showTypingBubble(agentId: UUID) {
        chatBubbleManager.showTyping(agentId: agentId)
    }

    func hideChatBubble(agentId: UUID) {
        chatBubbleManager.hideBubble(agentId: agentId)
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

    // MARK: - Level Badge & Accessory

    func updateLevelBadge(agentId: UUID, level: Int) {
        agentNodes[agentId]?.updateLevelBadge(level: level)
    }

    func replaceAccessory(agentId: UUID, accessory: Accessory, appearance: VoxelAppearance) {
        agentNodes[agentId]?.replaceAccessory(accessory, appearance: appearance)
    }

    // MARK: - Wave Animation for New Agents

    func playWaveForAgent(_ agentId: UUID) {
        animationControllers[agentId]?.playWaveAnimation()
    }

    // MARK: - Scene Transition Effect

    /// Play a fade-out/fade-in transition effect during scene rebuild
    func playSceneTransition(completion: @escaping () -> Void) {
        // Create a full-screen overlay that fades in then out
        let overlay = SCNNode()
        overlay.name = "transitionOverlay"

        let plane = SCNPlane(width: 50, height: 50)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.black
        mat.isDoubleSided = true
        plane.materials = [mat]
        overlay.geometry = plane

        // Position in front of camera
        if let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: false) {
            overlay.position = cameraNode.position
            overlay.eulerAngles = cameraNode.eulerAngles
            // Push slightly forward
            let forward = SCNVector3(0, 0, -2)
            overlay.position = cameraNode.position + forward
        }

        overlay.opacity = 0
        scene.rootNode.addChildNode(overlay)

        let fadeIn = SCNAction.fadeIn(duration: 0.4)
        fadeIn.timingMode = .easeIn
        let fadeOut = SCNAction.fadeOut(duration: 0.4)
        fadeOut.timingMode = .easeOut

        overlay.runAction(.sequence([
            fadeIn,
            .run { _ in completion() },
            fadeOut,
            .removeFromParentNode()
        ]))
    }

    // MARK: - First-Person Camera

    private var savedCameraState: (position: SCNVector3, eulerAngles: SCNVector3, fov: CGFloat)?
    private(set) var firstPersonTargetId: UUID?

    func enterFirstPerson(agentId: UUID) {
        guard let character = agentNodes[agentId],
              let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }

        savedCameraState = (cameraNode.position, cameraNode.eulerAngles, cameraNode.camera?.fieldOfView ?? 60)
        firstPersonTargetId = agentId

        let headPos = character.worldPosition
        let headHeight: CGFloat = 1.8
        let rotation = character.eulerAngles.y
        let forwardX = -sin(rotation)
        let forwardZ = -cos(rotation)

        let camPos = SCNVector3(headPos.x, headHeight, headPos.z)
        let lookAt = SCNVector3(headPos.x + forwardX * 5, headHeight, headPos.z + forwardZ * 5)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = camPos
        cameraNode.look(at: lookAt)
        cameraNode.camera?.fieldOfView = 70
        SCNTransaction.commit()
    }

    func updateFirstPersonCamera() {
        guard let agentId = firstPersonTargetId,
              let character = agentNodes[agentId],
              let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }

        let headPos = character.worldPosition
        let headHeight: CGFloat = 1.8
        let rotation = character.eulerAngles.y
        let forwardX = -sin(rotation)
        let forwardZ = -cos(rotation)

        cameraNode.position = SCNVector3(headPos.x, headHeight, headPos.z)
        cameraNode.look(at: SCNVector3(headPos.x + forwardX * 5, headHeight, headPos.z + forwardZ * 5))
    }

    func exitFirstPerson() {
        guard let saved = savedCameraState,
              let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }

        firstPersonTargetId = nil
        savedCameraState = nil

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = saved.position
        cameraNode.eulerAngles = saved.eulerAngles
        cameraNode.camera?.fieldOfView = saved.fov
        SCNTransaction.commit()
    }

    // MARK: - PiP Camera

    func removePiPCamera() {
        scene.rootNode.childNode(withName: "pipCamera", recursively: false)?.removeFromParentNode()
    }

    func pipCameraConfig() -> (position: SCNVector3, lookAt: SCNVector3, fov: CGFloat) {
        let themeConfig = currentThemeBuilder?.cameraConfigOverride()
        let sceneDefaults = currentSceneConfig?.cameraDefaults
        let defaultPos = themeConfig?.position.toSCNVector3() ?? sceneDefaults?.position.toSCNVector3() ?? SCNVector3(0, 8, 12)
        let defaultTarget = themeConfig?.lookAtTarget.toSCNVector3() ?? sceneDefaults?.lookAtTarget.toSCNVector3() ?? SCNVector3(0, 1, 0)
        let fov = CGFloat(themeConfig?.fieldOfView ?? sceneDefaults?.fieldOfView ?? 60)
        return (defaultPos, defaultTarget, fov)
    }

    // MARK: - Cosmetic System

    /// Apply a cosmetic hat to an agent's 3D character
    func applyCosmeticHat(agentId: UUID, hatStyle: CosmeticHatStyle, appearance: VoxelAppearance) {
        agentNodes[agentId]?.applyCosmeticHat(hatStyle, appearance: appearance)
    }

    /// Remove cosmetic hat from an agent
    func removeCosmeticHat(agentId: UUID) {
        agentNodes[agentId]?.removeCosmeticHat()
    }

    /// Apply a cosmetic particle trail to an agent
    func applyCosmeticParticle(agentId: UUID, colorHex: String, itemId: String) {
        agentNodes[agentId]?.applyCosmeticParticle(colorHex: colorHex, itemId: itemId)
    }

    /// Remove cosmetic particle from an agent
    func removeCosmeticParticle(agentId: UUID) {
        agentNodes[agentId]?.removeCosmeticParticle()
    }

    /// Apply a name tag with optional title to an agent
    func applyNameTag(agentId: UUID, agentName: String, title: String?) {
        agentNodes[agentId]?.applyNameTag(agentName: agentName, title: title)
    }

    /// Remove name tag from an agent
    func removeNameTag(agentId: UUID) {
        agentNodes[agentId]?.removeNameTag()
    }

    /// Apply cosmetic skin colors to an agent (rebuilds character appearance)
    func applyCosmeticSkin(agentId: UUID, skinColors: SkinColorSet, role: AgentRole, hairStyle: HairStyle) {
        agentNodes[agentId]?.applyCosmeticSkin(skinColors, role: role, hairStyle: hairStyle)
    }

    // MARK: - Walk To Desk Animation

    /// Spawn an agent off-screen and walk them to their desk position.
    /// Used when new agents join the scene.
    func walkAgentToDesk(_ agentId: UUID, completion: (() -> Void)? = nil) {
        guard let character = agentNodes[agentId],
              let deskPos = agentDeskPositions[agentId] else {
            completion?()
            return
        }
        guard !walkingAgents.contains(agentId) else {
            completion?()
            return
        }

        walkingAgents.insert(agentId)

        // Spawn position: offset from desk (enter from the side of the scene)
        let spawnOffset: CGFloat = 4.0
        let spawnPos = SCNVector3(deskPos.x - spawnOffset, 0, deskPos.z + spawnOffset)

        // Store the final desk rotation
        let finalRotation = character.eulerAngles.y

        WalkToDeskAnimation.apply(to: character, from: spawnPos, to: deskPos) { [weak self] in
            // Restore desk facing rotation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            character.eulerAngles.y = finalRotation
            SCNTransaction.commit()

            self?.walkingAgents.remove(agentId)
            completion?()
        }
    }

    /// Check if an agent is currently walking
    func isAgentWalking(_ agentId: UUID) -> Bool {
        walkingAgents.contains(agentId)
    }

    // MARK: - Visit Agent (Collaboration Walk)

    /// Make one agent walk to another agent's position to collaborate, then walk back.
    func visitAgent(visitorId: UUID, targetId: UUID, completion: (() -> Void)? = nil) {
        guard let visitor = agentNodes[visitorId],
              let target = agentNodes[targetId],
              let visitorDesk = agentDeskPositions[visitorId] else {
            completion?()
            return
        }
        guard !walkingAgents.contains(visitorId) else {
            completion?()
            return
        }

        walkingAgents.insert(visitorId)

        let targetPos = target.presentation.position

        VisitAgentAnimation.apply(
            visitor: visitor,
            visitorDeskPosition: visitorDesk,
            targetPosition: targetPos
        ) { [weak self] in
            // Restore desk facing rotation
            if let deskPos = self?.agentDeskPositions[visitorId] {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.3
                visitor.eulerAngles.y = CGFloat(Float.pi)
                SCNTransaction.commit()
            }

            self?.walkingAgents.remove(visitorId)
            completion?()
        }
    }

    // MARK: - Exploration Items

    /// Place 3D nodes for undiscovered exploration items in the scene
    func placeExplorationItems(_ items: [ExplorationItem], discoveredIds: Set<String>) {
        // Remove any existing exploration items
        scene.rootNode.childNodes
            .filter { $0.name?.hasPrefix("explorationItem-") == true }
            .forEach { $0.removeFromParentNode() }

        for item in items where !discoveredIds.contains(item.id) {
            let node = buildExplorationItemNode(item)
            node.position = SCNVector3(item.position.x, item.position.y, item.position.z)
            scene.rootNode.addChildNode(node)
        }
    }

    /// Remove a specific exploration item from the scene with a collect animation
    func removeExplorationItem(itemId: String) {
        guard let node = scene.rootNode.childNode(withName: "explorationItem-\(itemId)", recursively: false) else { return }
        let collectAnim = SCNAction.group([
            .moveBy(x: 0, y: 1.5, z: 0, duration: 0.6),
            .scale(to: 0.01, duration: 0.6),
            .fadeOut(duration: 0.6)
        ])
        collectAnim.timingMode = .easeIn
        node.runAction(.sequence([collectAnim, .removeFromParentNode()]))
    }

    private func buildExplorationItemNode(_ item: ExplorationItem) -> SCNNode {
        let container = SCNNode()
        container.name = "explorationItem-\(item.id)"

        // Glowing cube
        let box = SCNBox(width: 0.25, height: 0.25, length: 0.25, chamferRadius: 0.03)
        let mat = SCNMaterial()
        let color: NSColor = item.type == .easterEgg
            ? NSColor(hex: "#FFD700")  // gold
            : NSColor(hex: "#00BCD4")  // cyan
        mat.diffuse.contents = color.withAlphaComponent(0.8)
        mat.emission.contents = color
        mat.emission.intensity = 0.8
        mat.transparency = 0.85
        box.materials = [mat]

        let boxNode = SCNNode(geometry: box)
        container.addChildNode(boxNode)

        // "?" label above
        let text = SCNText(string: "?", extrusionDepth: 0.02)
        text.font = NSFont.systemFont(ofSize: 0.25, weight: .bold)
        text.flatness = 0.1
        text.firstMaterial?.diffuse.contents = NSColor.white
        text.firstMaterial?.emission.contents = color
        text.firstMaterial?.emission.intensity = 0.5
        let textNode = SCNNode(geometry: text)
        let (minBound, maxBound) = textNode.boundingBox
        let textWidth = maxBound.x - minBound.x
        textNode.position = SCNVector3(-textWidth / 2, 0.3, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        textNode.constraints = [billboard]
        container.addChildNode(textNode)

        // Floating bob animation
        let bobUp = SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 1.2)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 1.2)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])), forKey: "bob")

        // Slow Y rotation
        let rotate = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.0)
        boxNode.runAction(.repeatForever(rotate), forKey: "spin")

        return container
    }

    // MARK: - Interactive Objects

    private func placeInteractiveObjects(roomSize: RoomDimensions, themeBuilder: any SceneThemeBuilder) {
        // Door at the edge of the room
        let door = InteractiveObjectBuilder.buildInteractiveDoor(palette: themeBuilder.palette)
        door.position = SCNVector3(-roomSize.width / 2 + 0.5, 0, -roomSize.depth / 2 + 1.0)
        door.eulerAngles.y = CGFloat.pi / 2
        door.onInteraction = { [weak self] in
            self?.onInteractiveObjectClicked?(.door, nil)
        }
        scene.rootNode.addChildNode(door)
        interactiveObjects.append(door)

        // Server rack on the back wall
        let serverRack = InteractiveObjectBuilder.buildInteractiveServerRack(palette: themeBuilder.palette)
        serverRack.position = SCNVector3(roomSize.width / 2 - 1.0, 0, -roomSize.depth / 2 + 0.5)
        serverRack.onInteraction = { [weak self] in
            self?.onInteractiveObjectClicked?(.serverRack, nil)
        }
        scene.rootNode.addChildNode(serverRack)
        interactiveObjects.append(serverRack)

        // Whiteboard on the wall
        let whiteboard = InteractiveObjectBuilder.buildInteractiveWhiteboard(palette: themeBuilder.palette)
        whiteboard.position = SCNVector3(0, 0, -roomSize.depth / 2 + 0.2)
        whiteboard.onInteraction = { [weak self] in
            self?.onInteractiveObjectClicked?(.whiteboard, nil)
        }
        scene.rootNode.addChildNode(whiteboard)
        interactiveObjects.append(whiteboard)
    }

    /// Handle a click on the scene and check if it hit an interactive object
    func handleInteractiveObjectClick(at point: CGPoint, in view: SCNView) -> Bool {
        let hitResults = view.hitTest(point, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: false)
        ])

        for hit in hitResults {
            if let interactive = hit.node.findParentInteractiveObject() {
                interactive.playInteractionEffect()
                interactive.onInteraction?()
                return true
            }
        }
        return false
    }

    /// Show hover highlight on interactive objects
    func handleInteractiveObjectHover(at point: CGPoint, in view: SCNView) -> Bool {
        let hitResults = view.hitTest(point, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: true)
        ])

        // Clear all highlights first
        for obj in interactiveObjects {
            obj.hideHoverHighlight()
        }

        for hit in hitResults {
            if let interactive = hit.node.findParentInteractiveObject() {
                interactive.showHoverHighlight()
                return true
            }
        }
        return false
    }
}
