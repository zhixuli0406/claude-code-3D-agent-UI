import SceneKit
import SpriteKit

struct JapaneseGardenThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .japaneseGarden
    let palette: ThemeColorPalette = .japaneseGarden

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "garden_environment"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Sand/gravel ground with raked patterns
        let floor = SCNBox(width: w, height: 0.1, length: d, chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(hex: "#C4A882")
        floorMaterial.roughness.contents = 0.95
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        floorNode.name = "floor"
        room.addChildNode(floorNode)

        // Raked sand lines
        addRakedSandLines(to: room, dimensions: dimensions)

        // Koi pond
        let pond = buildKoiPond()
        pond.position = SCNVector3(-4, 0, 6)
        room.addChildNode(pond)

        return room
    }

    // MARK: - Workstation (Low Wooden Table)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let table = SCNNode()
        table.name = "lowTable"

        let w = CGFloat(size.width)
        let d = CGFloat(size.depth)
        let tableHeight: CGFloat = 0.35

        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        woodMaterial.roughness.contents = 0.8

        // Table top
        let top = SCNBox(width: w, height: 0.04, length: d, chamferRadius: 0.01)
        top.materials = [woodMaterial]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, Float(tableHeight), 0)
        table.addChildNode(topNode)

        // Short legs
        let legMat = SCNMaterial()
        legMat.diffuse.contents = NSColor(hex: "#6B4226")
        legMat.roughness.contents = 0.85

        let legPositions: [(Float, Float)] = [
            (-Float(w) / 2.0 + 0.06, -Float(d) / 2.0 + 0.06),
            (Float(w) / 2.0 - 0.06, -Float(d) / 2.0 + 0.06),
            (-Float(w) / 2.0 + 0.06, Float(d) / 2.0 - 0.06),
            (Float(w) / 2.0 - 0.06, Float(d) / 2.0 - 0.06)
        ]
        for pos in legPositions {
            let leg = SCNBox(width: 0.06, height: tableHeight - 0.02, length: 0.06, chamferRadius: 0)
            leg.materials = [legMat]
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(pos.0, Float(tableHeight) / 2.0, pos.1)
            table.addChildNode(legNode)
        }

        // Tea cup on table
        let cup = buildTeaCup()
        cup.position = SCNVector3(Float(w) * 0.3, Float(tableHeight) + 0.02, 0)
        table.addChildNode(cup)

        return table
    }

    // MARK: - Seating (Zabuton cushion)

    func buildSeating() -> SCNNode {
        let cushion = SCNNode()
        cushion.name = "zabuton"

        let cushionMat = SCNMaterial()
        cushionMat.diffuse.contents = NSColor(hex: "#8B0000")
        cushionMat.roughness.contents = 0.9

        let pad = SCNBox(width: 0.5, height: 0.06, length: 0.5, chamferRadius: 0.04)
        pad.materials = [cushionMat]
        let padNode = SCNNode(geometry: pad)
        padNode.position = SCNVector3(0, 0.03, 0)
        cushion.addChildNode(padNode)

        // Gold trim edge
        let trimMat = SCNMaterial()
        trimMat.diffuse.contents = NSColor(hex: "#DAA520")
        trimMat.emission.contents = NSColor(hex: "#DAA520")
        trimMat.emission.intensity = 0.2

        let trim = SCNBox(width: 0.52, height: 0.01, length: 0.52, chamferRadius: 0.04)
        trim.materials = [trimMat]
        let trimNode = SCNNode(geometry: trim)
        trimNode.position = SCNVector3(0, 0.065, 0)
        cushion.addChildNode(trimNode)

        return cushion
    }

    // MARK: - Display (Shoji Screen with ink painting)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "shojiScreen"

        // Wooden frame
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(hex: "#6B4226")
        woodMat.roughness.contents = 0.8

        // Vertical posts
        for xOff in [-Float(width) / 2.0 - 0.02, Float(width) / 2.0 + 0.02] {
            let post = SCNBox(width: 0.03, height: height + 0.04, length: 0.03, chamferRadius: 0)
            post.materials = [woodMat]
            let postNode = SCNNode(geometry: post)
            postNode.position = SCNVector3(xOff, Float(height) / 2.0 + 0.15, 0)
            display.addChildNode(postNode)
        }

        // Top bar
        let topBar = SCNBox(width: width + 0.08, height: 0.03, length: 0.03, chamferRadius: 0)
        topBar.materials = [woodMat]
        let topBarNode = SCNNode(geometry: topBar)
        topBarNode.position = SCNVector3(0, Float(height) + 0.17, 0)
        display.addChildNode(topBarNode)

        // Paper screen
        let paper = SCNPlane(width: width, height: height)
        let paperMat = SCNMaterial()
        let skScene = createInkPaintingContent(width: 512, height: 320)
        paperMat.diffuse.contents = skScene
        paperMat.emission.contents = skScene
        paperMat.emission.intensity = 0.2
        paperMat.isDoubleSided = true
        paper.materials = [paperMat]
        let paperNode = SCNNode(geometry: paper)
        paperNode.position = SCNVector3(0, Float(height) / 2.0 + 0.15, 0)
        paperNode.name = "screen"
        display.addChildNode(paperNode)

        // Soft back-light glow
        let backLight = SCNLight()
        backLight.type = .omni
        backLight.color = NSColor(hex: "#FFF8E7")
        backLight.intensity = 40
        backLight.attenuationStartDistance = 0
        backLight.attenuationEndDistance = 2.0
        let lightNode = SCNNode()
        lightNode.light = backLight
        lightNode.position = SCNVector3(0, Float(height) / 2.0 + 0.15, -0.1)
        display.addChildNode(lightNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Warm soft ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#FFF8E7")
        ambient.intensity = CGFloat(intensity * 0.5)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Warm sunlight from above
        let mainSpot = SCNLight()
        mainSpot.type = .spot
        mainSpot.color = NSColor(hex: "#FFE0B2")
        mainSpot.intensity = CGFloat(intensity * 1.1)
        mainSpot.spotInnerAngle = 30
        mainSpot.spotOuterAngle = 65
        mainSpot.castsShadow = true
        mainSpot.shadowRadius = 5
        mainSpot.shadowSampleCount = 8
        let mainSpotNode = SCNNode()
        mainSpotNode.light = mainSpot
        mainSpotNode.position = SCNVector3(2, 8, 3)
        mainSpotNode.look(at: SCNVector3(0, 0, 3))
        mainSpotNode.name = "mainSpotLight"
        scene.rootNode.addChildNode(mainSpotNode)

        // Soft pink accent (cherry blossom reflection)
        let pinkAccent = SCNLight()
        pinkAccent.type = .spot
        pinkAccent.color = NSColor(hex: palette.accentColor)
        pinkAccent.intensity = CGFloat(intensity * 0.3)
        pinkAccent.spotInnerAngle = 40
        pinkAccent.spotOuterAngle = 70
        let pinkNode = SCNNode()
        pinkNode.light = pinkAccent
        pinkNode.position = SCNVector3(-5, 5, 5)
        pinkNode.look(at: SCNVector3(-2, 0, 5))
        pinkNode.name = "pinkAccentLight"
        scene.rootNode.addChildNode(pinkNode)

        // Warm fill from right
        let fillLight = SCNLight()
        fillLight.type = .spot
        fillLight.color = NSColor(hex: "#FFE8CC")
        fillLight.intensity = CGFloat(intensity * 0.35)
        fillLight.spotInnerAngle = 40
        fillLight.spotOuterAngle = 70
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(6, 5, 3)
        fillNode.look(at: SCNVector3(3, 0, 3))
        fillNode.name = "fillLight"
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Cherry blossom trees
        let treePositions: [(Float, Float, Float)] = [
            (-6, 0, 1), (6, 0, 1), (-5, 0, 9), (5, 0, 9)
        ]
        for (i, pos) in treePositions.enumerated() {
            let tree = buildCherryBlossomTree()
            tree.position = SCNVector3(pos.0, pos.1, pos.2)
            tree.name = "cherryTree_\(i)"
            decorations.addChildNode(tree)
        }

        // Stone lanterns
        let lanternPositions: [(Float, Float, Float)] = [
            (-3, 0, 0), (3, 0, 0), (-3, 0, 10), (3, 0, 10)
        ]
        for (i, pos) in lanternPositions.enumerated() {
            let lantern = buildStoneLantern()
            lantern.position = SCNVector3(pos.0, pos.1, pos.2)
            lantern.name = "lantern_\(i)"
            decorations.addChildNode(lantern)
        }

        // Stepping stones
        let stonePositions: [(Float, Float)] = [
            (0, 1), (0.3, 2.5), (-0.2, 4), (0.1, 5.5)
        ]
        for (i, pos) in stonePositions.enumerated() {
            let stone = buildSteppingStone()
            stone.position = SCNVector3(pos.0, 0.02, pos.1)
            stone.name = "steppingStone_\(i)"
            decorations.addChildNode(stone)
        }

        // Bamboo fence on one side
        let fence = buildBambooFence(length: dimensions.depth)
        fence.position = SCNVector3(dimensions.width / 2.0 - 0.5, 0, dimensions.depth / 2.0 - 2.0)
        decorations.addChildNode(fence)

        return decorations
    }

    // MARK: - Agent Floor Tile

    func buildAgentFloorTile(isLeader: Bool) -> SCNNode {
        // Tatami mat style
        let tile = SCNBox(width: 1.2, height: 0.08, length: 1.2, chamferRadius: 0.01)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: isLeader ? "#B8A07E" : "#A89068")
        mat.roughness.contents = 0.9
        tile.materials = [mat]
        let node = SCNNode(geometry: tile)
        node.name = "agentFloorTile"

        // Dark border
        let borderMat = SCNMaterial()
        borderMat.diffuse.contents = NSColor(hex: "#4A3728")
        let border = SCNBox(width: 1.22, height: 0.02, length: 1.22, chamferRadius: 0.01)
        border.materials = [borderMat]
        let borderNode = SCNNode(geometry: border)
        borderNode.position = SCNVector3(0, 0.05, 0)
        node.addChildNode(borderNode)

        return node
    }

    func cameraConfigOverride() -> CameraConfig? {
        CameraConfig(
            position: ScenePosition(x: 0, y: 8, z: 14, rotation: 0),
            lookAtTarget: ScenePosition(x: 0, y: 0, z: 3, rotation: 0),
            fieldOfView: 55
        )
    }

    // MARK: - Private Helpers

    private func addRakedSandLines(to room: SCNNode, dimensions: RoomDimensions) {
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = NSColor(hex: "#B8A07E")
        lineMat.roughness.contents = 0.95

        let spacing: Float = 0.3
        let xCount = Int(dimensions.depth / spacing)
        for i in 0...xCount {
            let z = Float(i) * spacing - 2.0
            let line = SCNBox(width: CGFloat(dimensions.width) * 0.8, height: 0.005, length: 0.02, chamferRadius: 0)
            line.materials = [lineMat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(0, 0.003, z)
            room.addChildNode(lineNode)
        }
    }

    private func buildKoiPond() -> SCNNode {
        let pond = SCNNode()
        pond.name = "koiPond"

        // Water surface
        let water = SCNCylinder(radius: 1.5, height: 0.05)
        let waterMat = SCNMaterial()
        waterMat.diffuse.contents = NSColor(hex: "#1A5276").withAlphaComponent(0.6)
        waterMat.emission.contents = NSColor(hex: "#2E86C1")
        waterMat.emission.intensity = 0.15
        waterMat.transparency = 0.5
        waterMat.isDoubleSided = true
        water.materials = [waterMat]
        let waterNode = SCNNode(geometry: water)
        waterNode.position = SCNVector3(0, -0.02, 0)
        pond.addChildNode(waterNode)

        // Stone rim
        let rim = SCNTorus(ringRadius: 1.5, pipeRadius: 0.1)
        let rimMat = SCNMaterial()
        rimMat.diffuse.contents = NSColor(hex: "#808080")
        rimMat.roughness.contents = 0.9
        rim.materials = [rimMat]
        let rimNode = SCNNode(geometry: rim)
        rimNode.position = SCNVector3(0, 0.02, 0)
        pond.addChildNode(rimNode)

        return pond
    }

    private func buildTeaCup() -> SCNNode {
        let cup = SCNNode()

        let cupGeo = SCNCylinder(radius: 0.03, height: 0.04)
        let cupMat = SCNMaterial()
        cupMat.diffuse.contents = NSColor(hex: "#F5F5DC")
        cupMat.roughness.contents = 0.7
        cupGeo.materials = [cupMat]
        let cupNode = SCNNode(geometry: cupGeo)
        cupNode.position = SCNVector3(0, 0.02, 0)
        cup.addChildNode(cupNode)

        return cup
    }

    private func buildCherryBlossomTree() -> SCNNode {
        let tree = SCNNode()

        // Trunk
        let trunkMat = SCNMaterial()
        trunkMat.diffuse.contents = NSColor(hex: "#4A3728")
        trunkMat.roughness.contents = 0.9

        let trunk = SCNCylinder(radius: 0.12, height: 2.5)
        trunk.materials = [trunkMat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 1.25, 0)
        tree.addChildNode(trunkNode)

        // Canopy (pink blossoms)
        let blossomMat = SCNMaterial()
        blossomMat.diffuse.contents = NSColor(hex: "#FFB7C5").withAlphaComponent(0.8)
        blossomMat.emission.contents = NSColor(hex: "#FFB7C5")
        blossomMat.emission.intensity = 0.15

        let canopyPositions: [(Float, Float, Float, CGFloat)] = [
            (0, 3.0, 0, 0.8),
            (-0.4, 2.6, 0.3, 0.5),
            (0.3, 2.7, -0.3, 0.5),
            (0.5, 2.4, 0.2, 0.4),
            (-0.3, 2.8, -0.2, 0.45)
        ]
        for (_, pos) in canopyPositions.enumerated() {
            let blossom = SCNSphere(radius: pos.3)
            blossom.materials = [blossomMat]
            let blossomNode = SCNNode(geometry: blossom)
            blossomNode.position = SCNVector3(pos.0, pos.1, pos.2)
            tree.addChildNode(blossomNode)
        }

        // Branches
        for _ in 0..<3 {
            let branch = SCNCylinder(radius: 0.03, height: 0.8)
            branch.materials = [trunkMat]
            let branchNode = SCNNode(geometry: branch)
            branchNode.position = SCNVector3(
                Float.random(in: -0.3...0.3),
                Float.random(in: 2.0...2.8),
                Float.random(in: -0.3...0.3)
            )
            branchNode.eulerAngles.z = CGFloat(Float.random(in: -0.5...0.5))
            tree.addChildNode(branchNode)
        }

        return tree
    }

    private func buildStoneLantern() -> SCNNode {
        let lantern = SCNNode()

        let stoneMat = SCNMaterial()
        stoneMat.diffuse.contents = NSColor(hex: "#808080")
        stoneMat.roughness.contents = 0.95

        // Base
        let base = SCNCylinder(radius: 0.2, height: 0.1)
        base.materials = [stoneMat]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.05, 0)
        lantern.addChildNode(baseNode)

        // Pillar
        let pillar = SCNCylinder(radius: 0.08, height: 0.6)
        pillar.materials = [stoneMat]
        let pillarNode = SCNNode(geometry: pillar)
        pillarNode.position = SCNVector3(0, 0.4, 0)
        lantern.addChildNode(pillarNode)

        // Lantern body (hexagonal shape approximated by box)
        let body = SCNBox(width: 0.3, height: 0.25, length: 0.3, chamferRadius: 0.02)
        body.materials = [stoneMat]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.825, 0)
        lantern.addChildNode(bodyNode)

        // Light opening (glowing interior)
        let opening = SCNBox(width: 0.15, height: 0.12, length: 0.31, chamferRadius: 0)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor(hex: "#FFD700").withAlphaComponent(0.5)
        glowMat.emission.contents = NSColor(hex: "#FFD700")
        glowMat.emission.intensity = 0.6
        opening.materials = [glowMat]
        let openingNode = SCNNode(geometry: opening)
        openingNode.position = SCNVector3(0, 0.825, 0)
        lantern.addChildNode(openingNode)

        // Roof
        let roof = SCNPyramid(width: 0.4, height: 0.15, length: 0.4)
        roof.materials = [stoneMat]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 0.95, 0)
        lantern.addChildNode(roofNode)

        // Light
        let light = SCNLight()
        light.type = .omni
        light.color = NSColor(hex: "#FFD700")
        light.intensity = 80
        light.attenuationStartDistance = 0
        light.attenuationEndDistance = 3.0
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 0.825, 0)
        lantern.addChildNode(lightNode)

        // Gentle flicker
        lightNode.runAction(.repeatForever(.sequence([
            .run { n in n.light?.intensity = CGFloat(Float.random(in: 60...100)) },
            .wait(duration: 0.2)
        ])))

        return lantern
    }

    private func buildSteppingStone() -> SCNNode {
        let stone = SCNNode()

        let stoneMat = SCNMaterial()
        stoneMat.diffuse.contents = NSColor(hex: "#808080")
        stoneMat.roughness.contents = 0.95

        let geo = SCNCylinder(radius: CGFloat.random(in: 0.2...0.35), height: 0.06)
        geo.materials = [stoneMat]
        let stoneNode = SCNNode(geometry: geo)
        stone.addChildNode(stoneNode)

        return stone
    }

    private func buildBambooFence(length: Float) -> SCNNode {
        let fence = SCNNode()
        fence.name = "bambooFence"

        let bambooMat = SCNMaterial()
        bambooMat.diffuse.contents = NSColor(hex: "#7D8A2E")
        bambooMat.roughness.contents = 0.7

        let spacing: Float = 0.3
        let count = Int(length / spacing)
        for i in 0..<count {
            let pole = SCNCylinder(radius: 0.02, height: CGFloat(Float.random(in: 1.2...1.8)))
            pole.materials = [bambooMat]
            let poleNode = SCNNode(geometry: pole)
            poleNode.position = SCNVector3(0, Float(pole.height) / 2.0, Float(i) * spacing - length / 2.0)
            fence.addChildNode(poleNode)
        }

        // Horizontal bars
        for yPos: Float in [0.5, 1.0] {
            let bar = SCNCylinder(radius: 0.015, height: CGFloat(length))
            bar.materials = [bambooMat]
            let barNode = SCNNode(geometry: bar)
            barNode.position = SCNVector3(0, yPos, 0)
            barNode.eulerAngles.x = CGFloat.pi / 2
            fence.addChildNode(barNode)
        }

        return fence
    }

    private func createInkPaintingContent(width: CGFloat, height: CGFloat) -> SKScene {
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = NSColor(hex: "#FFF8E7")

        let title = SKLabelNode(text: "命令")
        title.fontName = "HiraginoSans-W6"
        title.fontSize = 48
        title.fontColor = NSColor(hex: "#2C1810")
        title.position = CGPoint(x: width / 2, y: height / 2 + 20)
        scene.addChild(title)

        let subtitle = SKLabelNode(text: "Agent Command")
        subtitle.fontName = "Menlo"
        subtitle.fontSize = 14
        subtitle.fontColor = NSColor(hex: "#6B4226")
        subtitle.position = CGPoint(x: width / 2, y: height / 2 - 30)
        scene.addChild(subtitle)

        // Decorative circle (enso)
        let enso = SKShapeNode(circleOfRadius: 60)
        enso.strokeColor = NSColor(hex: "#2C1810").withAlphaComponent(0.3)
        enso.lineWidth = 3
        enso.fillColor = .clear
        enso.position = CGPoint(x: width / 2, y: height / 2)
        scene.addChild(enso)

        return scene
    }
}
