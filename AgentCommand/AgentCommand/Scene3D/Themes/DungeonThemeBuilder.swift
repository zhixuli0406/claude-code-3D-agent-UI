import SceneKit
import SpriteKit

struct DungeonThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .dungeon
    let palette: ThemeColorPalette = .dungeon

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "dungeon_environment"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Stone floor with checker pattern
        let floorNode = buildStoneFloor(width: w, depth: d)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        room.addChildNode(floorNode)

        return room
    }

    // MARK: - Workstation (Treasure Chest)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let chest = SCNNode()
        chest.name = "treasureChest"

        let w = CGFloat(size.width) * 0.5
        let chestHeight: CGFloat = 0.5
        let chestDepth: CGFloat = 0.4

        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        woodMaterial.roughness.contents = 0.85

        // Chest body
        let body = SCNBox(width: w, height: chestHeight, length: chestDepth, chamferRadius: 0.02)
        body.materials = [woodMaterial]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, Float(chestHeight) / 2.0 + 0.01, 0)
        chest.addChildNode(bodyNode)

        // Slightly open lid
        let lid = SCNBox(width: w + 0.02, height: 0.06, length: chestDepth + 0.02, chamferRadius: 0.02)
        lid.materials = [woodMaterial]
        let lidNode = SCNNode(geometry: lid)
        lidNode.position = SCNVector3(0, Float(chestHeight) + 0.05, -Float(chestDepth) * 0.15)
        lidNode.eulerAngles.x = CGFloat(-0.3) // slightly open
        chest.addChildNode(lidNode)

        // Gold trim bands
        let goldMaterial = SCNMaterial()
        goldMaterial.diffuse.contents = NSColor(hex: "#FFD700")
        goldMaterial.metalness.contents = 0.8
        goldMaterial.roughness.contents = 0.2

        for yOffset: CGFloat in [0.15, 0.35] {
            let band = SCNBox(width: w + 0.01, height: 0.04, length: chestDepth + 0.01, chamferRadius: 0)
            band.materials = [goldMaterial]
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, Float(yOffset), 0)
            chest.addChildNode(bandNode)
        }

        // Lock
        let lock = SCNBox(width: 0.06, height: 0.08, length: 0.03, chamferRadius: 0.005)
        lock.materials = [goldMaterial]
        let lockNode = SCNNode(geometry: lock)
        lockNode.position = SCNVector3(0, Float(chestHeight) * 0.55, Float(chestDepth) / 2.0 + 0.02)
        chest.addChildNode(lockNode)

        // Inner glow (treasure inside)
        let glowLight = SCNLight()
        glowLight.type = .omni
        glowLight.color = NSColor(hex: "#FFD700")
        glowLight.intensity = 150
        glowLight.attenuationStartDistance = 0
        glowLight.attenuationEndDistance = 1.5
        let glowNode = SCNNode()
        glowNode.light = glowLight
        glowNode.position = SCNVector3(0, Float(chestHeight) * 0.7, 0)
        chest.addChildNode(glowNode)

        return chest
    }

    // MARK: - Seating (Stone Pillar Stool)

    func buildSeating() -> SCNNode {
        let stool = SCNNode()
        stool.name = "stoneStool"

        let stoneMaterial = SCNMaterial()
        stoneMaterial.diffuse.contents = NSColor(hex: "#696969")
        stoneMaterial.roughness.contents = 0.95

        // Pillar
        let pillar = SCNCylinder(radius: 0.15, height: 0.4)
        pillar.materials = [stoneMaterial]
        let pillarNode = SCNNode(geometry: pillar)
        pillarNode.position = SCNVector3(0, 0.2, 0)
        stool.addChildNode(pillarNode)

        // Seat top (slightly wider)
        let seatTop = SCNCylinder(radius: 0.2, height: 0.05)
        seatTop.materials = [stoneMaterial]
        let seatNode = SCNNode(geometry: seatTop)
        seatNode.position = SCNVector3(0, 0.425, 0)
        stool.addChildNode(seatNode)

        return stool
    }

    // MARK: - Display (Crystal Ball)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "crystalBall"

        let radius = min(width, height) * 0.5

        // Crystal sphere
        let sphere = SCNSphere(radius: radius)
        let crystalMaterial = SCNMaterial()
        crystalMaterial.diffuse.contents = NSColor(hex: "#9C27B0").withAlphaComponent(0.3)
        crystalMaterial.emission.contents = NSColor(hex: "#CE93D8")
        crystalMaterial.emission.intensity = 0.4
        crystalMaterial.transparency = 0.6
        crystalMaterial.isDoubleSided = true
        crystalMaterial.fresnelExponent = 2.0
        sphere.materials = [crystalMaterial]
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(0, Float(radius) + 0.15, 0)
        sphereNode.name = "screen"
        display.addChildNode(sphereNode)

        // Inner glow
        let innerGlow = SCNSphere(radius: radius * 0.6)
        let glowMaterial = SCNMaterial()
        glowMaterial.diffuse.contents = NSColor(hex: "#7B1FA2")
        glowMaterial.emission.contents = NSColor(hex: "#E040FB")
        glowMaterial.emission.intensity = 0.8
        glowMaterial.transparency = 0.5
        innerGlow.materials = [glowMaterial]
        let innerNode = SCNNode(geometry: innerGlow)
        innerNode.position = SCNVector3(0, Float(radius) + 0.15, 0)

        // Pulsing animation
        let pulse = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.scale(to: 1.1, duration: 1.0),
                SCNAction.scale(to: 0.9, duration: 1.0)
            ])
        )
        innerNode.runAction(pulse)
        display.addChildNode(innerNode)

        // Base pedestal
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        baseMaterial.metalness.contents = 0.3

        let base = SCNCylinder(radius: radius * 0.8, height: 0.1)
        base.materials = [baseMaterial]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.05, 0)
        display.addChildNode(baseNode)

        // Floating rune plane (SpriteKit texture)
        let runePlane = SCNPlane(width: width * 0.8, height: height * 0.6)
        let runeMaterial = SCNMaterial()
        let runeScene = createRuneContent(width: 256, height: 192)
        runeMaterial.diffuse.contents = runeScene
        runeMaterial.emission.contents = runeScene
        runeMaterial.emission.intensity = 0.6
        runeMaterial.transparency = 0.7
        runeMaterial.isDoubleSided = true
        runePlane.materials = [runeMaterial]
        let runeNode = SCNNode(geometry: runePlane)
        runeNode.position = SCNVector3(0, Float(radius) + 0.15, Float(radius) + 0.1)
        let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 12))
        runeNode.runAction(spin)
        display.addChildNode(runeNode)

        // Omni light from crystal
        let crystalLight = SCNLight()
        crystalLight.type = .omni
        crystalLight.color = NSColor(hex: "#CE93D8")
        crystalLight.intensity = 60
        crystalLight.attenuationStartDistance = 0
        crystalLight.attenuationEndDistance = 2.5
        let lightNode = SCNNode()
        lightNode.light = crystalLight
        lightNode.position = SCNVector3(0, Float(radius) + 0.15, 0)
        display.addChildNode(lightNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Warm ambient light
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#3D2B1F")
        ambient.intensity = CGFloat(intensity * 0.35)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Torches (omni lights with warm orange color)
        let torchPositions: [(Float, Float, Float)] = [
            (-8, 3, -1.5), (8, 3, -1.5),
            (-8, 3, 4), (8, 3, 4),
            (-8, 3, 8), (8, 3, 8),
            (-4, 3, -1.5), (4, 3, -1.5)
        ]

        for (i, pos) in torchPositions.enumerated() {
            let torch = buildTorch()
            torch.position = SCNVector3(pos.0, pos.1, pos.2)
            torch.name = "torch_\(i)"
            scene.rootNode.addChildNode(torch)
        }
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Spider webs in corners
        let webPositions: [(Float, Float, Float, Float)] = [
            (-Float(dimensions.width) / 2.0 + 0.3, Float(dimensions.height) - 0.5, -1.8, 0),
            (Float(dimensions.width) / 2.0 - 0.3, Float(dimensions.height) - 0.5, -1.8, Float.pi),
            (-Float(dimensions.width) / 2.0 + 0.3, Float(dimensions.height) - 0.5, Float(dimensions.depth) - 3.0, 0),
            (Float(dimensions.width) / 2.0 - 0.3, Float(dimensions.height) - 0.5, Float(dimensions.depth) - 3.0, Float.pi)
        ]

        for (i, pos) in webPositions.enumerated() {
            let web = buildSpiderWeb()
            web.position = SCNVector3(pos.0, pos.1, pos.2)
            web.eulerAngles.y = CGFloat(pos.3)
            web.name = "web_\(i)"
            decorations.addChildNode(web)
        }

        // Scattered bones
        for i in 0..<6 {
            let bone = buildBone()
            bone.position = SCNVector3(
                Float.random(in: -6...6),
                0.02,
                Float.random(in: -1...10)
            )
            bone.eulerAngles.y = CGFloat(Float.random(in: 0...Float.pi * 2))
            bone.name = "bone_\(i)"
            decorations.addChildNode(bone)
        }

        return decorations
    }

    // MARK: - Agent Floor Tile

    func buildAgentFloorTile(isLeader: Bool) -> SCNNode {
        let tile = SCNBox(width: 1.2, height: 0.1, length: 1.2, chamferRadius: 0)
        let stoneMaterial = SCNMaterial()
        stoneMaterial.diffuse.contents = NSColor(hex: "#5A5A5A")
        stoneMaterial.roughness.contents = 0.95
        tile.materials = [stoneMaterial]
        let node = SCNNode(geometry: tile)
        node.name = "agentFloorTile"
        return node
    }

    // MARK: - Private Helpers

    private func buildStoneFloor(width: CGFloat, depth: CGFloat) -> SCNNode {
        let floor = SCNNode()
        floor.name = "stoneFloor"

        let tileSize: CGFloat = 1.0
        let darkStone = SCNMaterial()
        darkStone.diffuse.contents = NSColor(hex: "#4A4A4A")
        darkStone.roughness.contents = 0.95

        let lightStone = SCNMaterial()
        lightStone.diffuse.contents = NSColor(hex: "#5A5A5A")
        lightStone.roughness.contents = 0.9

        let xCount = Int(width / tileSize)
        let zCount = Int(depth / tileSize)

        for ix in 0..<xCount {
            for iz in 0..<zCount {
                let tile = SCNBox(width: tileSize - 0.02, height: 0.1, length: tileSize - 0.02, chamferRadius: 0)
                tile.materials = [(ix + iz) % 2 == 0 ? darkStone : lightStone]
                let tileNode = SCNNode(geometry: tile)
                tileNode.position = SCNVector3(
                    Float(CGFloat(ix) * tileSize - width / 2.0 + tileSize / 2.0),
                    0,
                    Float(CGFloat(iz) * tileSize - depth / 2.0 + tileSize / 2.0)
                )
                floor.addChildNode(tileNode)
            }
        }

        return floor
    }


    private func buildTorch() -> SCNNode {
        let torch = SCNNode()

        // Wooden handle
        let handle = SCNCylinder(radius: 0.03, height: 0.5)
        let handleMaterial = SCNMaterial()
        handleMaterial.diffuse.contents = NSColor(hex: "#6D4C41")
        handle.materials = [handleMaterial]
        let handleNode = SCNNode(geometry: handle)
        torch.addChildNode(handleNode)

        // Metal bracket
        let bracket = SCNBox(width: 0.08, height: 0.04, length: 0.08, chamferRadius: 0)
        let metalMaterial = SCNMaterial()
        metalMaterial.diffuse.contents = NSColor(hex: "#37474F")
        metalMaterial.metalness.contents = 0.7
        bracket.materials = [metalMaterial]
        let bracketNode = SCNNode(geometry: bracket)
        bracketNode.position = SCNVector3(0, 0.2, 0)
        torch.addChildNode(bracketNode)

        // Flame (glowing sphere with pulsing)
        let flame = SCNSphere(radius: 0.06)
        let flameMaterial = SCNMaterial()
        flameMaterial.diffuse.contents = NSColor(hex: "#FF6600")
        flameMaterial.emission.contents = NSColor(hex: "#FF9800")
        flameMaterial.emission.intensity = 1.0
        flame.materials = [flameMaterial]
        let flameNode = SCNNode(geometry: flame)
        flameNode.position = SCNVector3(0, 0.3, 0)

        let pulseFire = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.scale(to: 1.2, duration: 0.3),
                SCNAction.scale(to: 0.8, duration: 0.2),
                SCNAction.scale(to: 1.0, duration: 0.3)
            ])
        )
        flameNode.runAction(pulseFire)
        torch.addChildNode(flameNode)

        // Torch light
        let torchLight = SCNLight()
        torchLight.type = .omni
        torchLight.color = NSColor(hex: "#FF8C00")
        torchLight.intensity = 400
        torchLight.attenuationStartDistance = 0
        torchLight.attenuationEndDistance = 8.0
        torchLight.castsShadow = true
        let lightNode = SCNNode()
        lightNode.light = torchLight
        lightNode.position = SCNVector3(0, 0.3, 0)
        torch.addChildNode(lightNode)

        // Flickering animation for the light
        let flicker = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.run { node in
                    node.light?.intensity = CGFloat(Float.random(in: 300...500))
                },
                SCNAction.wait(duration: 0.1)
            ])
        )
        lightNode.runAction(flicker)

        return torch
    }

    private func buildSpiderWeb() -> SCNNode {
        let web = SCNNode()
        let webPlane = SCNPlane(width: 0.8, height: 0.8)
        let webMaterial = SCNMaterial()
        webMaterial.diffuse.contents = NSColor.white.withAlphaComponent(0.15)
        webMaterial.isDoubleSided = true
        webPlane.materials = [webMaterial]
        let webNode = SCNNode(geometry: webPlane)
        webNode.eulerAngles.x = CGFloat(-Float.pi / 4)
        web.addChildNode(webNode)
        return web
    }

    private func buildBone() -> SCNNode {
        let bone = SCNNode()
        let boneMaterial = SCNMaterial()
        boneMaterial.diffuse.contents = NSColor(hex: "#E8E0D0")
        boneMaterial.roughness.contents = 0.8

        // Shaft
        let shaft = SCNCylinder(radius: 0.015, height: 0.2)
        shaft.materials = [boneMaterial]
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.eulerAngles.z = CGFloat.pi / 2
        bone.addChildNode(shaftNode)

        // Ends
        for xOff: Float in [-0.1, 0.1] {
            let end = SCNSphere(radius: 0.025)
            end.materials = [boneMaterial]
            let endNode = SCNNode(geometry: end)
            endNode.position = SCNVector3(xOff, 0, 0)
            bone.addChildNode(endNode)
        }

        return bone
    }

    private func createRuneContent(width: CGFloat, height: CGFloat) -> SKScene {
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = .clear

        let runes = ["ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ"]
        for (i, rune) in runes.enumerated() {
            let label = SKLabelNode(text: rune)
            label.fontName = "Menlo-Bold"
            label.fontSize = 24
            label.fontColor = NSColor(hex: "#CE93D8")
            label.position = CGPoint(
                x: CGFloat(i % 4) * (width / 4) + width / 8,
                y: CGFloat(i / 4) * (height / 2) + height / 4
            )
            let fade = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.3, duration: Double.random(in: 1...2)),
                    SKAction.fadeAlpha(to: 1.0, duration: Double.random(in: 1...2))
                ])
            )
            label.run(fade)
            scene.addChild(label)
        }

        return scene
    }
}
