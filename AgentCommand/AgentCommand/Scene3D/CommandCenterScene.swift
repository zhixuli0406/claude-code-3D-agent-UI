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

        // 3. Place command workstation
        let commandWorkstation = themeBuilder.buildWorkstation(size: .large)
        commandWorkstation.position = config.commandDeskPosition.toSCNVector3()
        commandWorkstation.eulerAngles.y = CGFloat(config.commandDeskPosition.rotation)
        scene.rootNode.addChildNode(commandWorkstation)

        let commandDisplay = themeBuilder.buildDisplay(width: 0.8, height: 0.5)
        commandDisplay.position = SCNVector3(
            config.commandDeskPosition.x,
            0.8,
            config.commandDeskPosition.z - Float(DeskSize.large.depth) * 0.3
        )
        scene.rootNode.addChildNode(commandDisplay)

        let commandSeat = themeBuilder.buildSeating()
        commandSeat.position = SCNVector3(
            config.commandDeskPosition.x,
            0,
            config.commandDeskPosition.z + Float(DeskSize.large.depth) * 0.6 + 0.3
        )
        scene.rootNode.addChildNode(commandSeat)

        // 4. Place workstation desks
        for wsConfig in config.workstationPositions {
            let workstation = themeBuilder.buildWorkstation(size: wsConfig.size)
            workstation.position = wsConfig.position.toSCNVector3()
            workstation.eulerAngles.y = CGFloat(wsConfig.position.rotation)
            scene.rootNode.addChildNode(workstation)

            let wsDisplay = themeBuilder.buildDisplay(width: 0.5, height: 0.35)
            wsDisplay.position = SCNVector3(
                wsConfig.position.x,
                0.8,
                wsConfig.position.z - Float(wsConfig.size.depth) * 0.3
            )
            wsDisplay.eulerAngles.y = CGFloat(wsConfig.position.rotation)
            scene.rootNode.addChildNode(wsDisplay)

            let wsSeat = themeBuilder.buildSeating()
            wsSeat.position = SCNVector3(
                wsConfig.position.x,
                0,
                wsConfig.position.z + Float(wsConfig.size.depth) * 0.6 + 0.3
            )
            wsSeat.eulerAngles.y = CGFloat(wsConfig.position.rotation)
            scene.rootNode.addChildNode(wsSeat)
        }

        // 5. Place agent characters (shared voxel system)
        for agent in agents {
            let character = VoxelCharacterNode(appearance: agent.appearance, role: agent.role)
            let seatOffset: Float = agent.isMainAgent ? 0.6 : 0.5
            character.position = SCNVector3(
                agent.position.x,
                0,
                agent.position.z + seatOffset
            )
            character.eulerAngles.y = CGFloat(agent.position.rotation)
            character.agentId = agent.id
            scene.rootNode.addChildNode(character)
            agentNodes[agent.id] = character

            let controller = AgentAnimationController(characterNode: character)
            controller.transitionTo(agent.status)
            animationControllers[agent.id] = controller
        }

        // 6. Build connection lines
        buildConnectionLines(agents: agents, lineColor: themeBuilder.connectionLineColor)

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

    // MARK: - Private

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
