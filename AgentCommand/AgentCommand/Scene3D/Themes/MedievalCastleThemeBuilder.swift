import SceneKit
import SpriteKit

struct MedievalCastleThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .medievalCastle
    let palette: ThemeColorPalette = .medievalCastle

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "medieval_environment"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Stone floor with large tiles
        let floorNode = buildStoneTileFloor(width: w, depth: d)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        room.addChildNode(floorNode)

        // Stone walls on sides
        addStoneWalls(to: room, dimensions: dimensions)

        return room
    }

    // MARK: - Workstation (Wooden Table)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let table = SCNNode()
        table.name = "woodenTable"

        let w = CGFloat(size.width)
        let d = CGFloat(size.depth)
        let tableHeight: CGFloat = 0.75

        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        woodMaterial.roughness.contents = 0.85

        // Table top
        let top = SCNBox(width: w, height: 0.06, length: d, chamferRadius: 0.01)
        top.materials = [woodMaterial]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, Float(tableHeight), 0)
        table.addChildNode(topNode)

        // Thick wooden legs
        let legMaterial = SCNMaterial()
        legMaterial.diffuse.contents = NSColor(hex: "#4A3728")
        legMaterial.roughness.contents = 0.9

        let legPositions: [(Float, Float)] = [
            (-Float(w) / 2.0 + 0.08, -Float(d) / 2.0 + 0.08),
            (Float(w) / 2.0 - 0.08, -Float(d) / 2.0 + 0.08),
            (-Float(w) / 2.0 + 0.08, Float(d) / 2.0 - 0.08),
            (Float(w) / 2.0 - 0.08, Float(d) / 2.0 - 0.08)
        ]
        for pos in legPositions {
            let leg = SCNBox(width: 0.1, height: tableHeight - 0.03, length: 0.1, chamferRadius: 0)
            leg.materials = [legMaterial]
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(pos.0, Float(tableHeight) / 2.0, pos.1)
            table.addChildNode(legNode)
        }

        // Candle on table
        let candle = buildCandle()
        candle.position = SCNVector3(Float(w) * 0.3, Float(tableHeight) + 0.03, 0)
        table.addChildNode(candle)

        return table
    }

    // MARK: - Seating (Wooden Bench)

    func buildSeating() -> SCNNode {
        let bench = SCNNode()
        bench.name = "woodenBench"

        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = NSColor(hex: "#5C4A3A")
        woodMaterial.roughness.contents = 0.9

        // Seat plank
        let seat = SCNBox(width: 0.5, height: 0.04, length: 0.3, chamferRadius: 0.005)
        seat.materials = [woodMaterial]
        let seatNode = SCNNode(geometry: seat)
        seatNode.position = SCNVector3(0, 0.4, 0)
        bench.addChildNode(seatNode)

        // Two thick legs
        let legMaterial = SCNMaterial()
        legMaterial.diffuse.contents = NSColor(hex: "#4A3728")
        legMaterial.roughness.contents = 0.95

        for xOff: Float in [-0.18, 0.18] {
            let leg = SCNBox(width: 0.08, height: 0.4, length: 0.25, chamferRadius: 0)
            leg.materials = [legMaterial]
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(xOff, 0.2, 0)
            bench.addChildNode(legNode)
        }

        return bench
    }

    // MARK: - Display (Scroll on Easel)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "scrollEasel"

        // Easel frame
        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = NSColor(hex: "#5C4A3A")
        woodMaterial.roughness.contents = 0.85

        // Two legs
        for xOff: Float in [-0.15, 0.15] {
            let leg = SCNCylinder(radius: 0.02, height: 1.0)
            leg.materials = [woodMaterial]
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(xOff, 0.5, -0.05)
            legNode.eulerAngles.x = CGFloat(0.15)
            display.addChildNode(legNode)
        }

        // Cross bar
        let bar = SCNCylinder(radius: 0.015, height: width + 0.1)
        bar.materials = [woodMaterial]
        let barNode = SCNNode(geometry: bar)
        barNode.position = SCNVector3(0, 0.7, 0)
        barNode.eulerAngles.z = CGFloat.pi / 2
        display.addChildNode(barNode)

        // Scroll (parchment)
        let scroll = SCNPlane(width: width, height: height)
        let scrollMaterial = SCNMaterial()
        let skScene = createParchmentContent(width: 512, height: 320)
        scrollMaterial.diffuse.contents = skScene
        scrollMaterial.emission.contents = skScene
        scrollMaterial.emission.intensity = 0.3
        scrollMaterial.isDoubleSided = true
        scroll.materials = [scrollMaterial]
        let scrollNode = SCNNode(geometry: scroll)
        scrollNode.position = SCNVector3(0, Float(height) / 2.0 + 0.15, 0.02)
        scrollNode.name = "screen"
        display.addChildNode(scrollNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Warm amber ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#3D2B1F")
        ambient.intensity = CGFloat(intensity * 0.4)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Main warm spotlight (like sunlight from high window)
        let mainSpot = SCNLight()
        mainSpot.type = .spot
        mainSpot.color = NSColor(hex: "#FFE0B2")
        mainSpot.intensity = CGFloat(intensity * 1.0)
        mainSpot.spotInnerAngle = 25
        mainSpot.spotOuterAngle = 55
        mainSpot.castsShadow = true
        mainSpot.shadowRadius = 4
        let mainSpotNode = SCNNode()
        mainSpotNode.light = mainSpot
        mainSpotNode.position = SCNVector3(3, 7, 1)
        mainSpotNode.look(at: SCNVector3(0, 0, 3))
        mainSpotNode.name = "mainSpotLight"
        scene.rootNode.addChildNode(mainSpotNode)

        // Wall-mounted torches
        let torchPositions: [(Float, Float, Float)] = [
            (-8, 3, 0), (8, 3, 0),
            (-8, 3, 5), (8, 3, 5),
            (-8, 3, 10), (8, 3, 10)
        ]
        for (i, pos) in torchPositions.enumerated() {
            let torch = buildWallTorch()
            torch.position = SCNVector3(pos.0, pos.1, pos.2)
            torch.name = "torch_\(i)"
            scene.rootNode.addChildNode(torch)
        }
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Banners hanging on walls
        let bannerColors = ["#8B0000", "#00008B", "#DAA520", "#006400"]
        let bannerPositions: [(Float, Float, Float)] = [
            (-Float(dimensions.width) / 2.0 + 0.1, 4, 2),
            (Float(dimensions.width) / 2.0 - 0.1, 4, 2),
            (-Float(dimensions.width) / 2.0 + 0.1, 4, 7),
            (Float(dimensions.width) / 2.0 - 0.1, 4, 7)
        ]
        for (i, pos) in bannerPositions.enumerated() {
            let banner = buildBanner(color: bannerColors[i % bannerColors.count])
            banner.position = SCNVector3(pos.0, pos.1, pos.2)
            banner.eulerAngles.y = pos.0 < 0 ? CGFloat.pi / 2 : -CGFloat.pi / 2
            banner.name = "banner_\(i)"
            decorations.addChildNode(banner)
        }

        // Throne at the back
        let throne = buildThrone()
        throne.position = SCNVector3(0, 0, -1.5)
        decorations.addChildNode(throne)

        // Scattered shields and swords on walls
        for i in 0..<3 {
            let shield = buildShield()
            shield.position = SCNVector3(
                Float.random(in: -6...6),
                Float.random(in: 2.5...4.0),
                -1.8
            )
            shield.name = "shield_\(i)"
            decorations.addChildNode(shield)
        }

        return decorations
    }

    // MARK: - Agent Floor Tile

    func buildAgentFloorTile(isLeader: Bool) -> SCNNode {
        let tile = SCNBox(width: 1.2, height: 0.1, length: 1.2, chamferRadius: 0)
        let stoneMaterial = SCNMaterial()
        stoneMaterial.diffuse.contents = NSColor(hex: isLeader ? "#6B5B4F" : "#4A3728")
        stoneMaterial.roughness.contents = 0.95
        tile.materials = [stoneMaterial]
        let node = SCNNode(geometry: tile)
        node.name = "agentFloorTile"

        if isLeader {
            // Gold trim around leader tile
            let trimMaterial = SCNMaterial()
            trimMaterial.diffuse.contents = NSColor(hex: "#DAA520")
            trimMaterial.metalness.contents = 0.7
            trimMaterial.emission.contents = NSColor(hex: "#DAA520")
            trimMaterial.emission.intensity = 0.3

            let trim = SCNBox(width: 1.25, height: 0.02, length: 1.25, chamferRadius: 0)
            trim.materials = [trimMaterial]
            let trimNode = SCNNode(geometry: trim)
            trimNode.position = SCNVector3(0, 0.06, 0)
            node.addChildNode(trimNode)
        }

        return node
    }

    // MARK: - Private Helpers

    private func buildStoneTileFloor(width: CGFloat, depth: CGFloat) -> SCNNode {
        let floor = SCNNode()
        floor.name = "stoneFloor"

        let tileSize: CGFloat = 1.5
        let darkStone = SCNMaterial()
        darkStone.diffuse.contents = NSColor(hex: "#4A3728")
        darkStone.roughness.contents = 0.95

        let lightStone = SCNMaterial()
        lightStone.diffuse.contents = NSColor(hex: "#5C4A3A")
        lightStone.roughness.contents = 0.9

        let xCount = Int(width / tileSize)
        let zCount = Int(depth / tileSize)

        for ix in 0..<xCount {
            for iz in 0..<zCount {
                let tile = SCNBox(width: tileSize - 0.04, height: 0.1, length: tileSize - 0.04, chamferRadius: 0)
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

    private func addStoneWalls(to room: SCNNode, dimensions: RoomDimensions) {
        let wallMaterial = SCNMaterial()
        wallMaterial.diffuse.contents = NSColor(hex: palette.wallColor)
        wallMaterial.roughness.contents = 0.95

        let wallHeight: CGFloat = 5.0

        // Left wall
        let leftWall = SCNBox(width: 0.3, height: wallHeight, length: CGFloat(dimensions.depth), chamferRadius: 0)
        leftWall.materials = [wallMaterial]
        let leftNode = SCNNode(geometry: leftWall)
        leftNode.position = SCNVector3(-dimensions.width / 2.0 - 0.15, Float(wallHeight) / 2.0, dimensions.depth / 2.0 - 2.0)
        room.addChildNode(leftNode)

        // Right wall
        let rightWall = SCNBox(width: 0.3, height: wallHeight, length: CGFloat(dimensions.depth), chamferRadius: 0)
        rightWall.materials = [wallMaterial]
        let rightNode = SCNNode(geometry: rightWall)
        rightNode.position = SCNVector3(dimensions.width / 2.0 + 0.15, Float(wallHeight) / 2.0, dimensions.depth / 2.0 - 2.0)
        room.addChildNode(rightNode)

        // Back wall
        let backWall = SCNBox(width: CGFloat(dimensions.width) + 0.6, height: wallHeight, length: 0.3, chamferRadius: 0)
        backWall.materials = [wallMaterial]
        let backNode = SCNNode(geometry: backWall)
        backNode.position = SCNVector3(0, Float(wallHeight) / 2.0, -2.15)
        room.addChildNode(backNode)
    }

    private func buildCandle() -> SCNNode {
        let candle = SCNNode()

        let waxMaterial = SCNMaterial()
        waxMaterial.diffuse.contents = NSColor(hex: "#F5F5DC")
        waxMaterial.roughness.contents = 0.8

        let wax = SCNCylinder(radius: 0.02, height: 0.12)
        wax.materials = [waxMaterial]
        let waxNode = SCNNode(geometry: wax)
        waxNode.position = SCNVector3(0, 0.06, 0)
        candle.addChildNode(waxNode)

        // Flame
        let flame = SCNSphere(radius: 0.015)
        let flameMaterial = SCNMaterial()
        flameMaterial.diffuse.contents = NSColor(hex: "#FF8C00")
        flameMaterial.emission.contents = NSColor(hex: "#FFD700")
        flameMaterial.emission.intensity = 1.0
        flame.materials = [flameMaterial]
        let flameNode = SCNNode(geometry: flame)
        flameNode.position = SCNVector3(0, 0.14, 0)
        let pulse = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.scale(to: 1.2, duration: 0.2),
                SCNAction.scale(to: 0.8, duration: 0.15),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ])
        )
        flameNode.runAction(pulse)
        candle.addChildNode(flameNode)

        // Candle light
        let light = SCNLight()
        light.type = .omni
        light.color = NSColor(hex: "#FFD700")
        light.intensity = 50
        light.attenuationStartDistance = 0
        light.attenuationEndDistance = 1.5
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 0.14, 0)
        candle.addChildNode(lightNode)

        return candle
    }

    private func buildWallTorch() -> SCNNode {
        let torch = SCNNode()

        let handleMat = SCNMaterial()
        handleMat.diffuse.contents = NSColor(hex: "#6D4C41")
        let handle = SCNCylinder(radius: 0.025, height: 0.4)
        handle.materials = [handleMat]
        let handleNode = SCNNode(geometry: handle)
        torch.addChildNode(handleNode)

        let flame = SCNSphere(radius: 0.05)
        let flameMat = SCNMaterial()
        flameMat.diffuse.contents = NSColor(hex: "#FF6600")
        flameMat.emission.contents = NSColor(hex: "#FF9800")
        flameMat.emission.intensity = 1.0
        flame.materials = [flameMat]
        let flameNode = SCNNode(geometry: flame)
        flameNode.position = SCNVector3(0, 0.25, 0)
        flameNode.runAction(.repeatForever(.sequence([
            .scale(to: 1.2, duration: 0.3),
            .scale(to: 0.8, duration: 0.2),
            .scale(to: 1.0, duration: 0.3)
        ])))
        torch.addChildNode(flameNode)

        let torchLight = SCNLight()
        torchLight.type = .omni
        torchLight.color = NSColor(hex: "#FF8C00")
        torchLight.intensity = 300
        torchLight.attenuationStartDistance = 0
        torchLight.attenuationEndDistance = 6.0
        let lightNode = SCNNode()
        lightNode.light = torchLight
        lightNode.position = SCNVector3(0, 0.25, 0)
        lightNode.runAction(.repeatForever(.sequence([
            .run { node in node.light?.intensity = CGFloat(Float.random(in: 200...400)) },
            .wait(duration: 0.1)
        ])))
        torch.addChildNode(lightNode)

        return torch
    }

    private func buildBanner(color: String) -> SCNNode {
        let banner = SCNNode()

        // Banner cloth
        let cloth = SCNPlane(width: 0.6, height: 1.5)
        let clothMaterial = SCNMaterial()
        clothMaterial.diffuse.contents = NSColor(hex: color)
        clothMaterial.roughness.contents = 0.8
        clothMaterial.isDoubleSided = true
        cloth.materials = [clothMaterial]
        let clothNode = SCNNode(geometry: cloth)
        banner.addChildNode(clothNode)

        // Rod at top
        let rod = SCNCylinder(radius: 0.015, height: 0.7)
        let metalMat = SCNMaterial()
        metalMat.diffuse.contents = NSColor(hex: "#DAA520")
        metalMat.metalness.contents = 0.6
        rod.materials = [metalMat]
        let rodNode = SCNNode(geometry: rod)
        rodNode.position = SCNVector3(0, 0.75, 0)
        rodNode.eulerAngles.z = CGFloat.pi / 2
        banner.addChildNode(rodNode)

        // Gold trim stripe
        let stripe = SCNPlane(width: 0.5, height: 0.04)
        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = NSColor(hex: "#DAA520")
        goldMat.emission.contents = NSColor(hex: "#DAA520")
        goldMat.emission.intensity = 0.2
        goldMat.isDoubleSided = true
        stripe.materials = [goldMat]
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(0, 0.2, 0.001)
        banner.addChildNode(stripeNode)

        return banner
    }

    private func buildThrone() -> SCNNode {
        let throne = SCNNode()
        throne.name = "throne"

        let stoneMat = SCNMaterial()
        stoneMat.diffuse.contents = NSColor(hex: "#696969")
        stoneMat.roughness.contents = 0.9

        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = NSColor(hex: "#DAA520")
        goldMat.metalness.contents = 0.7

        // Seat
        let seat = SCNBox(width: 1.0, height: 0.15, length: 0.8, chamferRadius: 0.02)
        seat.materials = [stoneMat]
        let seatNode = SCNNode(geometry: seat)
        seatNode.position = SCNVector3(0, 0.5, 0)
        throne.addChildNode(seatNode)

        // Back
        let back = SCNBox(width: 1.0, height: 1.5, length: 0.15, chamferRadius: 0.02)
        back.materials = [stoneMat]
        let backNode = SCNNode(geometry: back)
        backNode.position = SCNVector3(0, 1.25, -0.32)
        throne.addChildNode(backNode)

        // Armrests
        for side: Float in [-0.5, 0.5] {
            let arm = SCNBox(width: 0.12, height: 0.8, length: 0.7, chamferRadius: 0.02)
            arm.materials = [stoneMat]
            let armNode = SCNNode(geometry: arm)
            armNode.position = SCNVector3(side, 0.7, 0.0)
            throne.addChildNode(armNode)
        }

        // Steps
        for i in 0..<2 {
            let step = SCNBox(width: 1.6 + CGFloat(i) * 0.4, height: 0.15, length: 1.2 + CGFloat(i) * 0.2, chamferRadius: 0)
            step.materials = [stoneMat]
            let stepNode = SCNNode(geometry: step)
            stepNode.position = SCNVector3(0, Float(1 - i) * 0.15 + 0.075, Float(i) * 0.1)
            throne.addChildNode(stepNode)
        }

        // Gold crown on top of backrest
        let crown = SCNTorus(ringRadius: 0.15, pipeRadius: 0.03)
        crown.materials = [goldMat]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, 2.05, -0.32)
        throne.addChildNode(crownNode)

        return throne
    }

    private func buildShield() -> SCNNode {
        let shield = SCNNode()

        let shieldGeo = SCNCylinder(radius: 0.25, height: 0.03)
        let shieldMat = SCNMaterial()
        let colors = ["#8B0000", "#00008B", "#006400"]
        shieldMat.diffuse.contents = NSColor(hex: colors.randomElement()!)
        shieldMat.metalness.contents = 0.3
        shieldGeo.materials = [shieldMat]
        let shieldNode = SCNNode(geometry: shieldGeo)
        shieldNode.eulerAngles.x = CGFloat.pi / 2
        shield.addChildNode(shieldNode)

        // Metal rim
        let rim = SCNTorus(ringRadius: 0.25, pipeRadius: 0.015)
        let rimMat = SCNMaterial()
        rimMat.diffuse.contents = NSColor(hex: "#C0C0C0")
        rimMat.metalness.contents = 0.7
        rim.materials = [rimMat]
        let rimNode = SCNNode(geometry: rim)
        rimNode.eulerAngles.x = CGFloat.pi / 2
        shield.addChildNode(rimNode)

        // Boss (center piece)
        let boss = SCNSphere(radius: 0.05)
        let bossMat = SCNMaterial()
        bossMat.diffuse.contents = NSColor(hex: "#DAA520")
        bossMat.metalness.contents = 0.8
        boss.materials = [bossMat]
        let bossNode = SCNNode(geometry: boss)
        bossNode.position = SCNVector3(0, 0, 0.02)
        shield.addChildNode(bossNode)

        return shield
    }

    private func createParchmentContent(width: CGFloat, height: CGFloat) -> SKScene {
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = NSColor(hex: "#D4B896")

        let title = SKLabelNode(text: "AGENT COMMAND")
        title.fontName = "Copperplate-Bold"
        title.fontSize = 28
        title.fontColor = NSColor(hex: "#4A3728")
        title.position = CGPoint(x: width / 2, y: height - 40)
        scene.addChild(title)

        let status = SKLabelNode(text: "> Awaiting Orders")
        status.fontName = "Copperplate"
        status.fontSize = 18
        status.fontColor = NSColor(hex: "#6B5B4F")
        status.position = CGPoint(x: width / 2, y: height / 2)
        let fade = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 1.5),
                SKAction.fadeAlpha(to: 1.0, duration: 1.5)
            ])
        )
        status.run(fade)
        scene.addChild(status)

        return scene
    }
}
