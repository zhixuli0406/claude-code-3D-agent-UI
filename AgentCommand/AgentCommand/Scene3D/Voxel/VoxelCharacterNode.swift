import SceneKit

/// A complete voxel character assembled from body parts
class VoxelCharacterNode: SCNNode {
    var agentId: UUID?

    // Animatable body part references
    private(set) var headNode: SCNNode!
    private(set) var bodyNode: SCNNode!
    private(set) var leftArmNode: SCNNode!
    private(set) var rightArmNode: SCNNode!
    private(set) var leftLegNode: SCNNode!
    private(set) var rightLegNode: SCNNode!
    private(set) var statusIndicator: SCNNode!

    convenience init(appearance: VoxelAppearance, role: AgentRole) {
        self.init()
        self.name = "voxelCharacter"
        buildCharacter(with: appearance, role: role)
    }

    private func buildCharacter(with appearance: VoxelAppearance, role: AgentRole) {
        let palette = VoxelPalette(from: appearance)
        let vs = Float(VoxelBuilder.voxelSize)

        // --- Legs ---
        let legGrid = VoxelCharacterTemplate.leg()
        let legHeight = Float(legGrid.height) * vs

        leftLegNode = VoxelBuilder.buildBlock(from: legGrid, palette: palette)
        leftLegNode.position = SCNVector3(-0.12, 0, 0)
        leftLegNode.name = "leftLeg"
        addChildNode(leftLegNode)

        rightLegNode = VoxelBuilder.buildBlock(from: legGrid, palette: palette)
        rightLegNode.position = SCNVector3(0.12, 0, 0)
        rightLegNode.name = "rightLeg"
        addChildNode(rightLegNode)

        // --- Body ---
        let torsoGrid = VoxelCharacterTemplate.torso()
        let torsoHeight = Float(torsoGrid.height) * vs

        bodyNode = VoxelBuilder.buildBlock(from: torsoGrid, palette: palette)
        bodyNode.position = SCNVector3(0, legHeight, 0)
        bodyNode.name = "body"
        addChildNode(bodyNode)

        // --- Arms (kept unflattened at shoulder for pivot animation) ---
        let armGrid = VoxelCharacterTemplate.arm()
        let armHeight = Float(armGrid.height) * vs

        // Left arm - pivot at shoulder (top of arm)
        leftArmNode = VoxelBuilder.buildBlock(from: armGrid, palette: palette)
        leftArmNode.position = SCNVector3(-0.42, legHeight + torsoHeight - vs * 2, 0)
        leftArmNode.pivot = SCNMatrix4MakeTranslation(0, CGFloat(armHeight * 0.5), 0)
        leftArmNode.name = "leftArm"
        addChildNode(leftArmNode)

        // Right arm
        rightArmNode = VoxelBuilder.buildBlock(from: armGrid, palette: palette)
        rightArmNode.position = SCNVector3(0.42, legHeight + torsoHeight - vs * 2, 0)
        rightArmNode.pivot = SCNMatrix4MakeTranslation(0, CGFloat(armHeight * 0.5), 0)
        rightArmNode.name = "rightArm"
        addChildNode(rightArmNode)

        // --- Head ---
        let headGrid = VoxelCharacterTemplate.head(hairStyle: appearance.hairStyle)
        headNode = VoxelBuilder.buildBlock(from: headGrid, palette: palette)
        let headBaseY = legHeight + torsoHeight
        headNode.position = SCNVector3(0, headBaseY, 0)
        headNode.name = "head"
        addChildNode(headNode)

        // Add accessory
        if let accessory = appearance.accessory {
            let accessoryNode = buildAccessory(accessory, palette: palette)
            // Position on head
            let headHeight = Float(headGrid.height) * vs
            accessoryNode.position = SCNVector3(0, headBaseY + headHeight * 0.5, 0)
            addChildNode(accessoryNode)
        }

        // --- Status indicator (floating sphere above head) ---
        statusIndicator = buildStatusIndicator()
        let totalHeight = legHeight + torsoHeight + Float(headGrid.height) * vs
        statusIndicator.position = SCNVector3(0, totalHeight + 0.3, 0)
        addChildNode(statusIndicator)

        // --- Role badge (small colored cube near feet) ---
        let badge = buildRoleBadge(role: role)
        badge.position = SCNVector3(0.3, 0.1, 0.3)
        addChildNode(badge)
    }

    private func buildStatusIndicator() -> SCNNode {
        let sphere = SCNSphere(radius: 0.08)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#888888")
        material.emission.contents = NSColor(hex: "#888888")
        material.emission.intensity = 0.5
        sphere.materials = [material]

        let node = SCNNode(geometry: sphere)
        node.name = "statusIndicator"

        // Subtle floating animation
        let floatUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 1.0)
        floatUp.timingMode = .easeInEaseOut
        let floatDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 1.0)
        floatDown.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([floatUp, floatDown])))

        return node
    }

    private func buildAccessory(_ accessory: Accessory, palette: VoxelPalette) -> SCNNode {
        let node = SCNNode()
        let accessoryMaterial = SCNMaterial()
        accessoryMaterial.diffuse.contents = NSColor(hex: "#90A4AE")
        accessoryMaterial.metalness.contents = 0.3

        switch accessory {
        case .glasses:
            // Two small cubes for lenses + bridge
            let lens = SCNBox(width: 0.12, height: 0.06, length: 0.02, chamferRadius: 0)
            lens.materials = [accessoryMaterial]
            let leftLens = SCNNode(geometry: lens)
            leftLens.position = SCNVector3(-0.1, 0, 0.25)
            node.addChildNode(leftLens)
            let rightLens = SCNNode(geometry: lens)
            rightLens.position = SCNVector3(0.1, 0, 0.25)
            node.addChildNode(rightLens)
            // Bridge
            let bridge = SCNBox(width: 0.06, height: 0.02, length: 0.02, chamferRadius: 0)
            bridge.materials = [accessoryMaterial]
            let bridgeNode = SCNNode(geometry: bridge)
            bridgeNode.position = SCNVector3(0, 0, 0.25)
            node.addChildNode(bridgeNode)

        case .headphones:
            let bandMaterial = SCNMaterial()
            bandMaterial.diffuse.contents = NSColor(hex: "#424242")
            // Headband
            let band = SCNBox(width: 0.5, height: 0.03, length: 0.03, chamferRadius: 0)
            band.materials = [bandMaterial]
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, 0.15, 0)
            node.addChildNode(bandNode)
            // Ear cups
            let cup = SCNBox(width: 0.08, height: 0.1, length: 0.08, chamferRadius: 0.01)
            cup.materials = [bandMaterial]
            let leftCup = SCNNode(geometry: cup)
            leftCup.position = SCNVector3(-0.25, 0.05, 0)
            node.addChildNode(leftCup)
            let rightCup = SCNNode(geometry: cup)
            rightCup.position = SCNVector3(0.25, 0.05, 0)
            node.addChildNode(rightCup)

        case .hat:
            let hatMaterial = SCNMaterial()
            hatMaterial.diffuse.contents = NSColor(hex: "#E65100")
            // Brim
            let brim = SCNBox(width: 0.5, height: 0.02, length: 0.5, chamferRadius: 0)
            brim.materials = [hatMaterial]
            let brimNode = SCNNode(geometry: brim)
            brimNode.position = SCNVector3(0, 0.2, 0)
            node.addChildNode(brimNode)
            // Crown
            let crown = SCNBox(width: 0.35, height: 0.15, length: 0.35, chamferRadius: 0)
            crown.materials = [hatMaterial]
            let crownNode = SCNNode(geometry: crown)
            crownNode.position = SCNVector3(0, 0.3, 0)
            node.addChildNode(crownNode)
        }

        return node
    }

    private func buildRoleBadge(role: AgentRole) -> SCNNode {
        let badgeColor: NSColor
        switch role {
        case .commander: badgeColor = NSColor(hex: "#FFD700")
        case .developer: badgeColor = NSColor(hex: "#4CAF50")
        case .researcher: badgeColor = NSColor(hex: "#9C27B0")
        case .reviewer: badgeColor = NSColor(hex: "#2196F3")
        case .tester: badgeColor = NSColor(hex: "#FF5722")
        case .designer: badgeColor = NSColor(hex: "#E91E63")
        }

        let badge = SCNBox(width: 0.12, height: 0.12, length: 0.12, chamferRadius: 0.02)
        let material = SCNMaterial()
        material.diffuse.contents = badgeColor
        material.emission.contents = badgeColor
        material.emission.intensity = 0.3
        badge.materials = [material]

        let node = SCNNode(geometry: badge)
        node.name = "roleBadge"

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 4.0)
        node.runAction(.repeatForever(rotate))

        return node
    }

    /// Update the status indicator color
    func updateStatusColor(_ status: AgentStatus) {
        guard let geometry = statusIndicator?.geometry as? SCNSphere,
              let material = geometry.materials.first else { return }

        let color = NSColor(hex: status.hexColor)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        material.diffuse.contents = color
        material.emission.contents = color
        SCNTransaction.commit()
    }
}
