import SceneKit
import SpriteKit

struct MinecraftOverworldThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .minecraftOverworld
    let palette: ThemeColorPalette = .minecraftOverworld

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "minecraft_environment"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Grass block floor (green top, dirt sides)
        let floorNode = buildGrassFloor(width: w, depth: d)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        room.addChildNode(floorNode)

        // Terrain variation: small hills
        addTerrainHills(to: room, dimensions: dimensions)

        return room
    }

    // MARK: - Workstation (Crafting Table)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let table = SCNNode()
        table.name = "craftingTable"

        let blockSize: CGFloat = 0.5
        let tableHeight: CGFloat = 0.75

        // Table top (crafting grid pattern)
        let topMat = SCNMaterial()
        topMat.diffuse.contents = NSColor(hex: "#8B6914")
        topMat.roughness.contents = 0.85

        let top = SCNBox(width: CGFloat(size.width), height: blockSize * 0.1, length: CGFloat(size.depth), chamferRadius: 0)
        top.materials = [topMat]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, Float(tableHeight), 0)
        table.addChildNode(topNode)

        // Crafting grid lines on top
        let gridMat = SCNMaterial()
        gridMat.diffuse.contents = NSColor(hex: "#6B5014")
        let lineThickness: CGFloat = 0.01
        for i in 0..<4 {
            // Horizontal
            let hLine = SCNBox(width: CGFloat(size.width), height: lineThickness, length: lineThickness, chamferRadius: 0)
            hLine.materials = [gridMat]
            let hNode = SCNNode(geometry: hLine)
            hNode.position = SCNVector3(0, Float(tableHeight) + 0.026, Float(size.depth) * (Float(i) / 3.0 - 0.5))
            table.addChildNode(hNode)

            // Vertical
            let vLine = SCNBox(width: lineThickness, height: lineThickness, length: CGFloat(size.depth), chamferRadius: 0)
            vLine.materials = [gridMat]
            let vNode = SCNNode(geometry: vLine)
            vNode.position = SCNVector3(Float(size.width) * (Float(i) / 3.0 - 0.5), Float(tableHeight) + 0.026, 0)
            table.addChildNode(vNode)
        }

        // Wooden plank legs (blocky)
        let legMat = SCNMaterial()
        legMat.diffuse.contents = NSColor(hex: "#6B5B4F")
        legMat.roughness.contents = 0.9

        let legW: CGFloat = 0.15
        let legPositions: [(Float, Float)] = [
            (-Float(size.width) / 2.0 + Float(legW) / 2.0, -Float(size.depth) / 2.0 + Float(legW) / 2.0),
            (Float(size.width) / 2.0 - Float(legW) / 2.0, -Float(size.depth) / 2.0 + Float(legW) / 2.0),
            (-Float(size.width) / 2.0 + Float(legW) / 2.0, Float(size.depth) / 2.0 - Float(legW) / 2.0),
            (Float(size.width) / 2.0 - Float(legW) / 2.0, Float(size.depth) / 2.0 - Float(legW) / 2.0)
        ]
        for pos in legPositions {
            let leg = SCNBox(width: legW, height: tableHeight - 0.05, length: legW, chamferRadius: 0)
            leg.materials = [legMat]
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(pos.0, Float(tableHeight) / 2.0, pos.1)
            table.addChildNode(legNode)
        }

        return table
    }

    // MARK: - Seating (Oak Log)

    func buildSeating() -> SCNNode {
        let log = SCNNode()
        log.name = "oakLog"

        // Log body (darker bark)
        let barkMat = SCNMaterial()
        barkMat.diffuse.contents = NSColor(hex: "#4A3728")
        barkMat.roughness.contents = 0.9

        // Log rings on top (lighter inner wood)
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(hex: "#C4A882")
        woodMat.roughness.contents = 0.8

        let logGeo = SCNCylinder(radius: 0.2, height: 0.4)
        logGeo.materials = [barkMat, woodMat, woodMat] // side, top, bottom
        let logNode = SCNNode(geometry: logGeo)
        logNode.position = SCNVector3(0, 0.2, 0)
        log.addChildNode(logNode)

        return log
    }

    // MARK: - Display (Enchanting Table Book / Sign)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "signPost"

        // Wooden sign post
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(hex: "#6B5B4F")
        woodMat.roughness.contents = 0.85

        // Post
        let post = SCNBox(width: 0.1, height: 1.0, length: 0.1, chamferRadius: 0)
        post.materials = [woodMat]
        let postNode = SCNNode(geometry: post)
        postNode.position = SCNVector3(0, 0.5, -0.05)
        display.addChildNode(postNode)

        // Sign board (lighter wood)
        let signMat = SCNMaterial()
        let skScene = createPixelSignContent(width: 512, height: 320)
        signMat.diffuse.contents = skScene
        signMat.emission.contents = skScene
        signMat.emission.intensity = 0.15
        signMat.isDoubleSided = true

        let sign = SCNPlane(width: width, height: height)
        sign.materials = [signMat]
        let signNode = SCNNode(geometry: sign)
        signNode.position = SCNVector3(0, Float(height) / 2.0 + 0.3, 0)
        signNode.name = "screen"
        display.addChildNode(signNode)

        // Dark border frame
        let frameMat = SCNMaterial()
        frameMat.diffuse.contents = NSColor(hex: "#4A3728")
        frameMat.roughness.contents = 0.9

        let frameTop = SCNBox(width: width + 0.06, height: 0.03, length: 0.03, chamferRadius: 0)
        frameTop.materials = [frameMat]
        let frameTopNode = SCNNode(geometry: frameTop)
        frameTopNode.position = SCNVector3(0, Float(height) + 0.31, 0)
        display.addChildNode(frameTopNode)

        let frameBottom = SCNBox(width: width + 0.06, height: 0.03, length: 0.03, chamferRadius: 0)
        frameBottom.materials = [frameMat]
        let frameBottomNode = SCNNode(geometry: frameBottom)
        frameBottomNode.position = SCNVector3(0, 0.29, 0)
        display.addChildNode(frameBottomNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Bright blue sky ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#87CEEB")
        ambient.intensity = CGFloat(intensity * 0.5)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Sun (warm directional)
        let sunSpot = SCNLight()
        sunSpot.type = .spot
        sunSpot.color = NSColor(hex: "#FFF8DC")
        sunSpot.intensity = CGFloat(intensity * 1.2)
        sunSpot.spotInnerAngle = 30
        sunSpot.spotOuterAngle = 65
        sunSpot.castsShadow = true
        sunSpot.shadowRadius = 4
        sunSpot.shadowSampleCount = 8
        let sunNode = SCNNode()
        sunNode.light = sunSpot
        sunNode.position = SCNVector3(4, 10, 2)
        sunNode.look(at: SCNVector3(0, 0, 4))
        sunNode.name = "mainSpotLight"
        scene.rootNode.addChildNode(sunNode)

        // Fill light
        let fill = SCNLight()
        fill.type = .spot
        fill.color = NSColor(hex: "#E0F0FF")
        fill.intensity = CGFloat(intensity * 0.4)
        fill.spotInnerAngle = 40
        fill.spotOuterAngle = 70
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-6, 6, 5)
        fillNode.look(at: SCNVector3(0, 0, 4))
        fillNode.name = "fillLight"
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Voxel trees
        let treePositions: [(Float, Float)] = [
            (-6, 1), (7, 3), (-7, 7), (6, 9), (-4, 11)
        ]
        for (i, pos) in treePositions.enumerated() {
            let tree = buildVoxelTree()
            tree.position = SCNVector3(pos.0, 0, pos.1)
            tree.name = "tree_\(i)"
            decorations.addChildNode(tree)
        }

        // Flowers
        let flowerColors = ["#FF0000", "#FFFF00", "#FF69B4", "#00BFFF"]
        for i in 0..<12 {
            let flower = buildFlower(color: flowerColors[i % flowerColors.count])
            flower.position = SCNVector3(
                Float.random(in: -7...7),
                0.05,
                Float.random(in: 0...10)
            )
            flower.name = "flower_\(i)"
            decorations.addChildNode(flower)
        }

        // Torches (Minecraft-style)
        let torchPositions: [(Float, Float)] = [(-3, 0), (3, 0), (-3, 6), (3, 6)]
        for (i, pos) in torchPositions.enumerated() {
            let torch = buildMinecraftTorch()
            torch.position = SCNVector3(pos.0, 0, pos.1)
            torch.name = "mcTorch_\(i)"
            decorations.addChildNode(torch)
        }

        // Sun and clouds in the sky
        let sun = buildBlockySun()
        sun.position = SCNVector3(8, 12, -5)
        decorations.addChildNode(sun)

        for i in 0..<4 {
            let cloud = buildBlockyCloud()
            cloud.position = SCNVector3(
                Float.random(in: -10...10),
                Float.random(in: 8...12),
                Float.random(in: -3...10)
            )
            cloud.name = "cloud_\(i)"
            decorations.addChildNode(cloud)
        }

        return decorations
    }

    // MARK: - Agent Floor Tile

    func buildAgentFloorTile(isLeader: Bool) -> SCNNode {
        // Minecraft grass block style tile
        let node = SCNNode()
        node.name = "agentFloorTile"

        // Dirt block
        let dirt = SCNBox(width: 1.2, height: 0.1, length: 1.2, chamferRadius: 0)
        let dirtMat = SCNMaterial()
        dirtMat.diffuse.contents = NSColor(hex: "#8B6914")
        dirtMat.roughness.contents = 0.9
        dirt.materials = [dirtMat]
        let dirtNode = SCNNode(geometry: dirt)
        node.addChildNode(dirtNode)

        // Green grass top
        let grass = SCNBox(width: 1.2, height: 0.03, length: 1.2, chamferRadius: 0)
        let grassMat = SCNMaterial()
        grassMat.diffuse.contents = NSColor(hex: isLeader ? "#6DB33F" : "#5B8731")
        grassMat.roughness.contents = 0.85
        grass.materials = [grassMat]
        let grassNode = SCNNode(geometry: grass)
        grassNode.position = SCNVector3(0, 0.065, 0)
        node.addChildNode(grassNode)

        return node
    }

    func cameraConfigOverride() -> CameraConfig? {
        CameraConfig(
            position: ScenePosition(x: 0, y: 10, z: 16, rotation: 0),
            lookAtTarget: ScenePosition(x: 0, y: 0, z: 2, rotation: 0),
            fieldOfView: 60
        )
    }

    // MARK: - Private Helpers

    private func buildGrassFloor(width: CGFloat, depth: CGFloat) -> SCNNode {
        let floor = SCNNode()
        floor.name = "grassFloor"

        // Bottom dirt layer
        let dirt = SCNBox(width: width, height: 0.1, length: depth, chamferRadius: 0)
        let dirtMat = SCNMaterial()
        dirtMat.diffuse.contents = NSColor(hex: "#8B6914")
        dirtMat.roughness.contents = 0.9
        dirt.materials = [dirtMat]
        let dirtNode = SCNNode(geometry: dirt)
        floor.addChildNode(dirtNode)

        // Green grass top
        let grass = SCNBox(width: width, height: 0.03, length: depth, chamferRadius: 0)
        let grassMat = SCNMaterial()
        grassMat.diffuse.contents = NSColor(hex: "#5B8731")
        grassMat.roughness.contents = 0.85
        grass.materials = [grassMat]
        let grassNode = SCNNode(geometry: grass)
        grassNode.position = SCNVector3(0, 0.065, 0)
        floor.addChildNode(grassNode)

        return floor
    }

    private func addTerrainHills(to room: SCNNode, dimensions: RoomDimensions) {
        let grassMat = SCNMaterial()
        grassMat.diffuse.contents = NSColor(hex: "#5B8731")
        grassMat.roughness.contents = 0.85

        let dirtMat = SCNMaterial()
        dirtMat.diffuse.contents = NSColor(hex: "#8B6914")
        dirtMat.roughness.contents = 0.9

        // A few raised blocks on the edges
        let hillPositions: [(Float, Float, Int)] = [
            (-7, 1, 2), (7, 4, 3), (-8, 8, 2), (8, 2, 1), (-6, 11, 2)
        ]
        for pos in hillPositions {
            for layer in 0..<pos.2 {
                let block = SCNBox(width: 1, height: 0.5, length: 1, chamferRadius: 0)
                block.materials = layer == pos.2 - 1 ? [grassMat] : [dirtMat]
                let blockNode = SCNNode(geometry: block)
                blockNode.position = SCNVector3(pos.0, Float(layer) * 0.5 + 0.25, pos.1)
                room.addChildNode(blockNode)
            }
        }
    }

    private func buildVoxelTree() -> SCNNode {
        let tree = SCNNode()

        let logMat = SCNMaterial()
        logMat.diffuse.contents = NSColor(hex: "#6B5B4F")
        logMat.roughness.contents = 0.9

        let leafMat = SCNMaterial()
        leafMat.diffuse.contents = NSColor(hex: "#2E7D32")
        leafMat.roughness.contents = 0.8

        // Trunk (stacked blocks)
        let trunkHeight = Int.random(in: 3...5)
        for i in 0..<trunkHeight {
            let block = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0)
            block.materials = [logMat]
            let blockNode = SCNNode(geometry: block)
            blockNode.position = SCNVector3(0, Float(i) * 0.5 + 0.25, 0)
            tree.addChildNode(blockNode)
        }

        // Leaf canopy (cluster of blocks)
        let topY = Float(trunkHeight) * 0.5
        let leafPositions: [(Float, Float, Float)] = [
            (0, topY + 0.5, 0),
            (0, topY + 1.0, 0),
            (-0.5, topY + 0.5, 0), (0.5, topY + 0.5, 0),
            (0, topY + 0.5, -0.5), (0, topY + 0.5, 0.5),
            (-0.5, topY, 0), (0.5, topY, 0),
            (0, topY, -0.5), (0, topY, 0.5),
            (-0.5, topY, -0.5), (0.5, topY, 0.5),
            (0.5, topY, -0.5), (-0.5, topY, 0.5)
        ]
        for pos in leafPositions {
            let block = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0)
            block.materials = [leafMat]
            let blockNode = SCNNode(geometry: block)
            blockNode.position = SCNVector3(pos.0, pos.1, pos.2)
            tree.addChildNode(blockNode)
        }

        return tree
    }

    private func buildFlower(color: String) -> SCNNode {
        let flower = SCNNode()

        // Stem
        let stemMat = SCNMaterial()
        stemMat.diffuse.contents = NSColor(hex: "#2E7D32")
        let stem = SCNBox(width: 0.02, height: 0.15, length: 0.02, chamferRadius: 0)
        stem.materials = [stemMat]
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.075, 0)
        flower.addChildNode(stemNode)

        // Flower head (small colored block)
        let headMat = SCNMaterial()
        headMat.diffuse.contents = NSColor(hex: color)
        headMat.emission.contents = NSColor(hex: color)
        headMat.emission.intensity = 0.1
        let head = SCNBox(width: 0.08, height: 0.08, length: 0.08, chamferRadius: 0)
        head.materials = [headMat]
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0.19, 0)
        flower.addChildNode(headNode)

        return flower
    }

    private func buildMinecraftTorch() -> SCNNode {
        let torch = SCNNode()

        // Stick
        let stickMat = SCNMaterial()
        stickMat.diffuse.contents = NSColor(hex: "#8B6914")
        stickMat.roughness.contents = 0.8
        let stick = SCNBox(width: 0.08, height: 0.6, length: 0.08, chamferRadius: 0)
        stick.materials = [stickMat]
        let stickNode = SCNNode(geometry: stick)
        stickNode.position = SCNVector3(0, 0.3, 0)
        torch.addChildNode(stickNode)

        // Flame block (orange glowing cube)
        let flameMat = SCNMaterial()
        flameMat.diffuse.contents = NSColor(hex: "#FF8C00")
        flameMat.emission.contents = NSColor(hex: "#FFD700")
        flameMat.emission.intensity = 1.0
        let flame = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        flame.materials = [flameMat]
        let flameNode = SCNNode(geometry: flame)
        flameNode.position = SCNVector3(0, 0.65, 0)
        flameNode.runAction(.repeatForever(.sequence([
            .scale(to: 1.1, duration: 0.3),
            .scale(to: 0.9, duration: 0.2),
            .scale(to: 1.0, duration: 0.3)
        ])))
        torch.addChildNode(flameNode)

        // Light
        let light = SCNLight()
        light.type = .omni
        light.color = NSColor(hex: "#FF8C00")
        light.intensity = 200
        light.attenuationStartDistance = 0
        light.attenuationEndDistance = 5.0
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 0.65, 0)
        lightNode.runAction(.repeatForever(.sequence([
            .run { n in n.light?.intensity = CGFloat(Float.random(in: 150...250)) },
            .wait(duration: 0.15)
        ])))
        torch.addChildNode(lightNode)

        return torch
    }

    private func buildBlockySun() -> SCNNode {
        let sun = SCNNode()
        sun.name = "blockySun"

        let sunMat = SCNMaterial()
        sunMat.diffuse.contents = NSColor(hex: "#FFD700")
        sunMat.emission.contents = NSColor(hex: "#FFD700")
        sunMat.emission.intensity = 1.0

        let sunBlock = SCNBox(width: 2, height: 2, length: 0.2, chamferRadius: 0)
        sunBlock.materials = [sunMat]
        let sunNode = SCNNode(geometry: sunBlock)
        sun.addChildNode(sunNode)

        // Billboard
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        sun.constraints = [billboard]

        return sun
    }

    private func buildBlockyCloud() -> SCNNode {
        let cloud = SCNNode()

        let cloudMat = SCNMaterial()
        cloudMat.diffuse.contents = NSColor.white.withAlphaComponent(0.9)

        let blockPositions: [(Float, Float, Float)] = [
            (0, 0, 0), (0.5, 0, 0), (-0.5, 0, 0),
            (0, 0, 0.5), (0, 0, -0.5),
            (0.5, 0.3, 0), (-0.3, 0.3, 0)
        ]
        for pos in blockPositions {
            let block = SCNBox(width: 0.6, height: 0.4, length: 0.6, chamferRadius: 0)
            block.materials = [cloudMat]
            let blockNode = SCNNode(geometry: block)
            blockNode.position = SCNVector3(pos.0, pos.1, pos.2)
            cloud.addChildNode(blockNode)
        }

        // Slow drift
        let driftDuration = Double.random(in: 15...25)
        let drift = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: CGFloat(Float.random(in: 2...5)), y: 0, z: 0, duration: driftDuration),
                SCNAction.moveBy(x: CGFloat(-Float.random(in: 2...5)), y: 0, z: 0, duration: driftDuration)
            ])
        )
        cloud.runAction(drift)

        return cloud
    }

    private func createPixelSignContent(width: CGFloat, height: CGFloat) -> SKScene {
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = NSColor(hex: "#C4A882")

        let title = SKLabelNode(text: "AGENT COMMAND")
        title.fontName = "Menlo-Bold"
        title.fontSize = 28
        title.fontColor = NSColor(hex: "#4A3728")
        title.position = CGPoint(x: width / 2, y: height - 50)
        scene.addChild(title)

        let status = SKLabelNode(text: "> Ready to craft")
        status.fontName = "Menlo"
        status.fontSize = 16
        status.fontColor = NSColor(hex: "#2E7D32")
        status.position = CGPoint(x: width / 2, y: height / 2)
        let blink = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.8),
                SKAction.fadeAlpha(to: 1.0, duration: 0.8)
            ])
        )
        status.run(blink)
        scene.addChild(status)

        return scene
    }
}
