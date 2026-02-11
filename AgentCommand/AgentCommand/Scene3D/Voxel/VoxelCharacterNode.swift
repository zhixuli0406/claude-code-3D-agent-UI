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

        case .crown:
            let goldMaterial = SCNMaterial()
            goldMaterial.diffuse.contents = NSColor(hex: "#FFD700")
            goldMaterial.emission.contents = NSColor(hex: "#FFD700")
            goldMaterial.emission.intensity = 0.4
            goldMaterial.metalness.contents = 0.8

            // Crown base band
            let band = SCNBox(width: 0.45, height: 0.08, length: 0.45, chamferRadius: 0)
            band.materials = [goldMaterial]
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, 0.22, 0)
            node.addChildNode(bandNode)

            // Crown points (3 tall prongs)
            let pointGeo = SCNBox(width: 0.08, height: 0.12, length: 0.08, chamferRadius: 0)
            pointGeo.materials = [goldMaterial]
            for xOff: Float in [-0.14, 0, 0.14] {
                let pointNode = SCNNode(geometry: pointGeo)
                pointNode.position = SCNVector3(xOff, 0.32, 0)
                node.addChildNode(pointNode)
            }

            // Gem on center point
            let gemMaterial = SCNMaterial()
            gemMaterial.diffuse.contents = NSColor(hex: "#E91E63")
            gemMaterial.emission.contents = NSColor(hex: "#E91E63")
            gemMaterial.emission.intensity = 0.6
            let gem = SCNSphere(radius: 0.03)
            gem.materials = [gemMaterial]
            let gemNode = SCNNode(geometry: gem)
            gemNode.position = SCNVector3(0, 0.28, 0.2)
            node.addChildNode(gemNode)

        case .cape:
            let capeMaterial = SCNMaterial()
            capeMaterial.diffuse.contents = NSColor(hex: "#D32F2F")
            capeMaterial.emission.contents = NSColor(hex: "#D32F2F")
            capeMaterial.emission.intensity = 0.15
            capeMaterial.isDoubleSided = true

            // Cape body (flat box behind the character)
            let capeBody = SCNBox(width: 0.5, height: 0.7, length: 0.02, chamferRadius: 0)
            capeBody.materials = [capeMaterial]
            let capeNode = SCNNode(geometry: capeBody)
            capeNode.position = SCNVector3(0, -0.15, -0.2)
            capeNode.name = "capeBody"

            // Subtle wave animation
            let waveLeft = SCNAction.rotateTo(x: 0.05, y: 0, z: 0.03, duration: 1.5)
            waveLeft.timingMode = .easeInEaseOut
            let waveRight = SCNAction.rotateTo(x: -0.02, y: 0, z: -0.03, duration: 1.5)
            waveRight.timingMode = .easeInEaseOut
            capeNode.runAction(.repeatForever(.sequence([waveLeft, waveRight])))
            node.addChildNode(capeNode)

            // Cape clasp (gold circle at neck)
            let claspMaterial = SCNMaterial()
            claspMaterial.diffuse.contents = NSColor(hex: "#FFD700")
            claspMaterial.metalness.contents = 0.7
            let clasp = SCNSphere(radius: 0.04)
            clasp.materials = [claspMaterial]
            let claspNode = SCNNode(geometry: clasp)
            claspNode.position = SCNVector3(0, 0.2, -0.15)
            node.addChildNode(claspNode)

        case .aura:
            // Glowing energy ring around the character
            let auraMaterial = SCNMaterial()
            auraMaterial.diffuse.contents = NSColor(hex: "#7C4DFF").withAlphaComponent(0.4)
            auraMaterial.emission.contents = NSColor(hex: "#7C4DFF")
            auraMaterial.emission.intensity = 1.0
            auraMaterial.isDoubleSided = true
            auraMaterial.blendMode = .add

            let ring = SCNTorus(ringRadius: 0.5, pipeRadius: 0.02)
            ring.materials = [auraMaterial]
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(0, -0.1, 0)
            ringNode.name = "auraRing"

            // Orbit animation
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2.0)
            ringNode.runAction(.repeatForever(rotate))

            // Pulse animation
            let scaleUp = SCNAction.scale(to: 1.2, duration: 1.0)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SCNAction.scale(to: 0.9, duration: 1.0)
            scaleDown.timingMode = .easeInEaseOut
            ringNode.runAction(.repeatForever(.sequence([scaleUp, scaleDown])), forKey: "auraPulse")
            node.addChildNode(ringNode)

            // Floating particles around the ring
            let particleMaterial = SCNMaterial()
            particleMaterial.diffuse.contents = NSColor(hex: "#B388FF")
            particleMaterial.emission.contents = NSColor(hex: "#B388FF")
            particleMaterial.emission.intensity = 1.0
            particleMaterial.blendMode = .add
            for i in 0..<4 {
                let particle = SCNSphere(radius: 0.025)
                particle.materials = [particleMaterial]
                let pNode = SCNNode(geometry: particle)
                let angle = Float(i) * Float.pi * 0.5
                pNode.position = SCNVector3(cos(angle) * 0.5, 0, sin(angle) * 0.5)

                // Orbit with offset
                let orbitAction = SCNAction.customAction(duration: 3.0) { node, elapsed in
                    let t = Float(elapsed) / 3.0
                    let a = angle + t * Float.pi * 2
                    node.position = SCNVector3(cos(a) * 0.5, sin(a * 2) * 0.15, sin(a) * 0.5)
                }
                pNode.runAction(.repeatForever(orbitAction))
                ringNode.addChildNode(pNode)
            }
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

    // MARK: - Selection Highlight

    /// Show a glowing selection ring around the character
    func showSelectionHighlight() {
        guard childNode(withName: "selectionRing", recursively: false) == nil else { return }

        let ring = SCNTorus(ringRadius: 0.6, pipeRadius: 0.03)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#00BCD4").withAlphaComponent(0.8)
        material.emission.contents = NSColor(hex: "#00BCD4")
        material.emission.intensity = 1.0
        ring.materials = [material]

        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "selectionRing"
        ringNode.position = SCNVector3(0, 0.05, 0)

        // Pulsing animation
        let scaleUp = SCNAction.scale(to: 1.15, duration: 0.8)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SCNAction.scale(to: 0.95, duration: 0.8)
        scaleDown.timingMode = .easeInEaseOut
        ringNode.runAction(.repeatForever(.sequence([scaleUp, scaleDown])), forKey: "selectionPulse")

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 3.0)
        ringNode.runAction(.repeatForever(rotate), forKey: "selectionRotate")

        // Fade in
        ringNode.opacity = 0
        addChildNode(ringNode)
        ringNode.runAction(.fadeIn(duration: 0.3))
    }

    /// Remove the selection highlight
    func hideSelectionHighlight() {
        guard let ring = childNode(withName: "selectionRing", recursively: false) else { return }
        ring.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
    }

    // MARK: - Level Badge

    /// Show or update a level badge floating near the character
    func updateLevelBadge(level: Int) {
        // Remove existing
        childNode(withName: "levelBadge", recursively: false)?.removeFromParentNode()

        guard level > 1 else { return }

        let badgeNode = SCNNode()
        badgeNode.name = "levelBadge"

        // Background circle
        let bgMaterial = SCNMaterial()
        let badgeColor: NSColor
        switch level {
        case 2...4: badgeColor = NSColor(hex: "#4CAF50")   // Green
        case 5...9: badgeColor = NSColor(hex: "#2196F3")   // Blue
        default:    badgeColor = NSColor(hex: "#FFD700")    // Gold (10+)
        }
        bgMaterial.diffuse.contents = badgeColor
        bgMaterial.emission.contents = badgeColor
        bgMaterial.emission.intensity = 0.5

        let bg = SCNCylinder(radius: 0.12, height: 0.02)
        bg.materials = [bgMaterial]
        let bgNode = SCNNode(geometry: bg)
        bgNode.eulerAngles.x = CGFloat.pi / 2 // Face forward
        badgeNode.addChildNode(bgNode)

        // Level number text
        let text = SCNText(string: "\(level)", extrusionDepth: 0.01)
        text.font = NSFont.systemFont(ofSize: 0.12, weight: .bold)
        text.flatness = 0.1
        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = NSColor.white
        textMaterial.emission.contents = NSColor.white
        textMaterial.emission.intensity = 0.3
        text.materials = [textMaterial]

        let textNode = SCNNode(geometry: text)
        // Center the text
        let (min, max) = textNode.boundingBox
        let textWidth = max.x - min.x
        let textHeight = max.y - min.y
        textNode.position = SCNVector3(-textWidth / 2, -textHeight / 2, 0.02)
        textNode.scale = SCNVector3(1, 1, 1)
        badgeNode.addChildNode(textNode)

        // Position badge to the left of the character, near shoulder
        badgeNode.position = SCNVector3(-0.5, 1.2, 0.2)

        // Billboard constraint so it always faces camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        badgeNode.constraints = [billboard]

        addChildNode(badgeNode)
    }

    // MARK: - Cosmetic System

    /// Apply a cosmetic hat from the shop
    func applyCosmeticHat(_ hatStyle: CosmeticHatStyle, appearance: VoxelAppearance) {
        // Remove existing cosmetic hat
        childNode(withName: "cosmeticHat", recursively: false)?.removeFromParentNode()
        // Also remove level-based accessory
        childNode(withName: "accessoryNode", recursively: false)?.removeFromParentNode()

        let hatNode = CosmeticHatBuilder.buildHat(hatStyle)
        hatNode.name = "cosmeticHat"

        let vs = Float(VoxelBuilder.voxelSize)
        let legHeight = Float(VoxelCharacterTemplate.leg().height) * vs
        let torsoHeight = Float(VoxelCharacterTemplate.torso().height) * vs
        let headGrid = VoxelCharacterTemplate.head(hairStyle: appearance.hairStyle)
        let headBaseY = legHeight + torsoHeight
        let headHeight = Float(headGrid.height) * vs
        hatNode.position = SCNVector3(0, headBaseY + headHeight * 0.5, 0)

        // Fade in
        hatNode.opacity = 0
        addChildNode(hatNode)
        hatNode.runAction(.fadeIn(duration: 0.5))
    }

    /// Remove cosmetic hat and restore level-based accessory
    func removeCosmeticHat() {
        guard let hat = childNode(withName: "cosmeticHat", recursively: false) else { return }
        hat.runAction(.sequence([.fadeOut(duration: 0.3), .removeFromParentNode()]))
    }

    /// Apply cosmetic particle trail
    func applyCosmeticParticle(colorHex: String, itemId: String) {
        // Remove existing
        childNode(withName: "cosmeticParticle", recursively: false)?.removeFromParentNode()

        let trailNode = CosmeticParticleTrail.buildTrail(colorHex: colorHex, itemId: itemId)
        trailNode.name = "cosmeticParticle"

        // Fade in
        trailNode.opacity = 0
        addChildNode(trailNode)
        trailNode.runAction(.fadeIn(duration: 0.5))
    }

    /// Remove cosmetic particle
    func removeCosmeticParticle() {
        guard let particle = childNode(withName: "cosmeticParticle", recursively: false) else { return }
        particle.runAction(.sequence([.fadeOut(duration: 0.3), .removeFromParentNode()]))
    }

    /// Apply name tag with optional title
    func applyNameTag(agentName: String, title: String?) {
        // Remove existing
        childNode(withName: "nameTag", recursively: false)?.removeFromParentNode()

        let tag = NameTagNode.build(agentName: agentName, title: title)

        // Fade in
        tag.opacity = 0
        addChildNode(tag)
        tag.runAction(.fadeIn(duration: 0.4))
    }

    /// Remove name tag
    func removeNameTag() {
        guard let tag = childNode(withName: "nameTag", recursively: false) else { return }
        tag.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
    }

    /// Apply cosmetic skin colors by rebuilding the character
    func applyCosmeticSkin(_ skinColors: SkinColorSet, role: AgentRole, hairStyle: HairStyle) {
        // Remove all body parts
        headNode?.removeFromParentNode()
        bodyNode?.removeFromParentNode()
        leftArmNode?.removeFromParentNode()
        rightArmNode?.removeFromParentNode()
        leftLegNode?.removeFromParentNode()
        rightLegNode?.removeFromParentNode()

        // Rebuild with new colors
        let appearance = VoxelAppearance(
            skinColor: skinColors.skinColor,
            shirtColor: skinColors.shirtColor,
            pantsColor: skinColors.pantsColor,
            hairColor: skinColors.hairColor,
            hairStyle: hairStyle,
            accessory: nil
        )
        buildCharacter(with: appearance, role: role)
    }

    // MARK: - Accessory Update

    /// Dynamically replace the current accessory with a new one
    func replaceAccessory(_ newAccessory: Accessory, appearance: VoxelAppearance) {
        // Remove existing accessory node
        childNode(withName: "accessoryNode", recursively: false)?.removeFromParentNode()

        let palette = VoxelPalette(from: appearance)
        let accessoryNode = buildAccessory(newAccessory, palette: palette)
        accessoryNode.name = "accessoryNode"

        let vs = Float(VoxelBuilder.voxelSize)
        let legGrid = VoxelCharacterTemplate.leg()
        let legHeight = Float(legGrid.height) * vs
        let torsoGrid = VoxelCharacterTemplate.torso()
        let torsoHeight = Float(torsoGrid.height) * vs
        let headGrid = VoxelCharacterTemplate.head(hairStyle: appearance.hairStyle)
        let headBaseY = legHeight + torsoHeight
        let headHeight = Float(headGrid.height) * vs
        accessoryNode.position = SCNVector3(0, headBaseY + headHeight * 0.5, 0)

        // Fade-in animation
        accessoryNode.opacity = 0
        addChildNode(accessoryNode)
        accessoryNode.runAction(.fadeIn(duration: 0.5))
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
