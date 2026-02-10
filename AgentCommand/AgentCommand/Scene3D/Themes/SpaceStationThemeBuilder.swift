import SceneKit
import SpriteKit

struct SpaceStationThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .spaceStation
    let palette: ThemeColorPalette = .spaceStation

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "spaceStation_environment"

        let w = CGFloat(dimensions.width)
        let h = CGFloat(dimensions.height)
        let d = CGFloat(dimensions.depth)

        // Metallic floor
        let floor = SCNBox(width: w, height: 0.1, length: d, chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(hex: palette.floorColor)
        floorMaterial.metalness.contents = 0.6
        floorMaterial.roughness.contents = 0.4
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        floorNode.name = "floor"
        room.addChildNode(floorNode)

        // Floor glow grid
        addFloorGlowGrid(to: room, dimensions: dimensions)

        // Metal wall panels
        let wallMaterial = SCNMaterial()
        wallMaterial.diffuse.contents = NSColor(hex: palette.wallColor)
        wallMaterial.metalness.contents = 0.5
        wallMaterial.roughness.contents = 0.3

        // Back wall with window cutouts
        let backWall = SCNBox(width: w, height: h, length: 0.15, chamferRadius: 0)
        backWall.materials = [wallMaterial]
        let backWallNode = SCNNode(geometry: backWall)
        backWallNode.position = SCNVector3(0, Float(h) / 2.0, -2.0)
        backWallNode.name = "backWall"
        room.addChildNode(backWallNode)

        // Windows on back wall (starfield views)
        let windowPositions: [Float] = [-4.0, 0.0, 4.0]
        for (i, xPos) in windowPositions.enumerated() {
            let window = buildStarfieldWindow(width: 2.0, height: 1.5)
            window.position = SCNVector3(xPos, Float(h) * 0.55, -1.9)
            window.name = "window_\(i)"
            room.addChildNode(window)
        }

        // Side walls
        let sideWall = SCNBox(width: 0.15, height: h, length: d, chamferRadius: 0)
        sideWall.materials = [wallMaterial]

        let leftWall = SCNNode(geometry: sideWall)
        leftWall.position = SCNVector3(-Float(w) / 2.0, Float(h) / 2.0, Float(d) / 2.0 - 2.0)
        leftWall.name = "leftWall"
        room.addChildNode(leftWall)

        let rightWall = SCNNode(geometry: sideWall.copy() as? SCNGeometry ?? sideWall)
        rightWall.position = SCNVector3(Float(w) / 2.0, Float(h) / 2.0, Float(d) / 2.0 - 2.0)
        rightWall.name = "rightWall"
        room.addChildNode(rightWall)

        // Ceiling with visible panels
        let ceiling = SCNBox(width: w, height: 0.15, length: d, chamferRadius: 0)
        let ceilingMaterial = SCNMaterial()
        ceilingMaterial.diffuse.contents = NSColor(hex: "#1E1E3E")
        ceilingMaterial.metalness.contents = 0.4
        ceiling.materials = [ceilingMaterial]
        let ceilingNode = SCNNode(geometry: ceiling)
        ceilingNode.position = SCNVector3(0, Float(h), Float(d) / 2.0 - 2.0)
        room.addChildNode(ceilingNode)

        // Wall seam lines
        addWallSeams(to: room, dimensions: dimensions)

        return room
    }

    // MARK: - Workstation (Metal Console)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let console = SCNNode()
        console.name = "metalConsole"

        let w = CGFloat(size.width)
        let d = CGFloat(size.depth)
        let consoleHeight: CGFloat = 0.75

        let metalMaterial = SCNMaterial()
        metalMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        metalMaterial.metalness.contents = 0.6
        metalMaterial.roughness.contents = 0.3

        // Main console body
        let body = SCNBox(width: w, height: consoleHeight, length: d * 0.6, chamferRadius: 0.02)
        body.materials = [metalMaterial]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, Float(consoleHeight) / 2.0, 0)
        console.addChildNode(bodyNode)

        // Tilted control panel on top
        let panel = SCNBox(width: w * 0.9, height: 0.03, length: d * 0.5, chamferRadius: 0.01)
        let panelMaterial = SCNMaterial()
        panelMaterial.diffuse.contents = NSColor(hex: "#1A1A3E")
        panelMaterial.metalness.contents = 0.3
        panel.materials = [panelMaterial]
        let panelNode = SCNNode(geometry: panel)
        panelNode.position = SCNVector3(0, Float(consoleHeight) + 0.02, Float(d) * 0.1)
        panelNode.eulerAngles.x = CGFloat(0.3)
        console.addChildNode(panelNode)

        // Colored buttons on panel
        let buttonColors = ["#FF1744", "#00E676", "#2979FF", "#FFD600"]
        for (i, color) in buttonColors.enumerated() {
            let button = SCNCylinder(radius: 0.02, height: 0.01)
            let buttonMaterial = SCNMaterial()
            buttonMaterial.diffuse.contents = NSColor(hex: color)
            buttonMaterial.emission.contents = NSColor(hex: color)
            buttonMaterial.emission.intensity = 0.5
            button.materials = [buttonMaterial]
            let buttonNode = SCNNode(geometry: button)
            let spacing = Float(w) * 0.15
            buttonNode.position = SCNVector3(
                Float(-2 + i) * spacing + spacing / 2,
                Float(consoleHeight) + 0.04,
                Float(d) * 0.1
            )
            console.addChildNode(buttonNode)
        }

        // Edge glow strip
        let strip = SCNBox(width: w + 0.02, height: 0.02, length: 0.02, chamferRadius: 0)
        let stripMaterial = SCNMaterial()
        stripMaterial.diffuse.contents = NSColor(hex: palette.accentColorSecondary)
        stripMaterial.emission.contents = NSColor(hex: palette.accentColorSecondary)
        stripMaterial.emission.intensity = 0.8
        strip.materials = [stripMaterial]
        let stripNode = SCNNode(geometry: strip)
        stripNode.position = SCNVector3(0, Float(consoleHeight), Float(d) * 0.3 + 0.01)
        console.addChildNode(stripNode)

        return console
    }

    // MARK: - Seating (Pilot Chair)

    func buildSeating() -> SCNNode {
        let chair = SCNNode()
        chair.name = "pilotChair"

        let metalMaterial = SCNMaterial()
        metalMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        metalMaterial.metalness.contents = 0.6
        metalMaterial.roughness.contents = 0.3

        let seatMaterial = SCNMaterial()
        seatMaterial.diffuse.contents = NSColor(hex: "#2A2A4E")
        seatMaterial.roughness.contents = 0.7

        // Seat
        let seat = SCNBox(width: 0.5, height: 0.06, length: 0.5, chamferRadius: 0.02)
        seat.materials = [seatMaterial]
        let seatNode = SCNNode(geometry: seat)
        seatNode.position = SCNVector3(0, 0.45, 0)
        chair.addChildNode(seatNode)

        // Backrest
        let backrest = SCNBox(width: 0.5, height: 0.6, length: 0.06, chamferRadius: 0.02)
        backrest.materials = [seatMaterial]
        let backrestNode = SCNNode(geometry: backrest)
        backrestNode.position = SCNVector3(0, 0.75, -0.22)
        chair.addChildNode(backrestNode)

        // Armrests
        for side: Float in [-0.28, 0.28] {
            let armrest = SCNBox(width: 0.06, height: 0.04, length: 0.35, chamferRadius: 0.01)
            armrest.materials = [metalMaterial]
            let armNode = SCNNode(geometry: armrest)
            armNode.position = SCNVector3(side, 0.55, -0.05)
            chair.addChildNode(armNode)
        }

        // Pedestal
        let pedestal = SCNCylinder(radius: 0.04, height: 0.45)
        pedestal.materials = [metalMaterial]
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(0, 0.225, 0)
        chair.addChildNode(pedestalNode)

        // Base
        let basePart = SCNBox(width: 0.4, height: 0.03, length: 0.06, chamferRadius: 0.01)
        basePart.materials = [metalMaterial]
        let base1 = SCNNode(geometry: basePart)
        let base2 = SCNNode(geometry: basePart)
        base2.eulerAngles.y = CGFloat.pi / 2
        chair.addChildNode(base1)
        chair.addChildNode(base2)

        return chair
    }

    // MARK: - Display (Holographic Projector)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "holoProjector"

        // Projector base
        let base = SCNCylinder(radius: 0.12, height: 0.08)
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        baseMaterial.metalness.contents = 0.7
        base.materials = [baseMaterial]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.04, 0)
        display.addChildNode(baseNode)

        // Glow ring on base
        let ring = SCNTorus(ringRadius: 0.12, pipeRadius: 0.01)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = NSColor(hex: palette.accentColorSecondary)
        ringMaterial.emission.contents = NSColor(hex: palette.accentColorSecondary)
        ringMaterial.emission.intensity = 1.0
        ring.materials = [ringMaterial]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.08, 0)
        display.addChildNode(ringNode)

        // Holographic display plane (semi-transparent)
        let holoPlane = SCNPlane(width: width, height: height)
        let holoMaterial = SCNMaterial()
        let skScene = MonitorBuilder.createScreenContent(
            width: 512, height: 320, accentColor: palette.accentColorSecondary
        )
        holoMaterial.diffuse.contents = skScene
        holoMaterial.emission.contents = skScene
        holoMaterial.emission.intensity = 0.8
        holoMaterial.transparency = 0.7
        holoMaterial.isDoubleSided = true
        holoPlane.materials = [holoMaterial]
        let holoNode = SCNNode(geometry: holoPlane)
        holoNode.position = SCNVector3(0, Float(height) / 2.0 + 0.2, 0)
        holoNode.name = "screen"
        display.addChildNode(holoNode)

        // Scan line animation (moving bright band)
        let scanLine = SCNPlane(width: width * 1.02, height: 0.02)
        let scanMaterial = SCNMaterial()
        scanMaterial.diffuse.contents = NSColor(hex: palette.accentColorSecondary).withAlphaComponent(0.6)
        scanMaterial.emission.contents = NSColor(hex: palette.accentColorSecondary)
        scanMaterial.emission.intensity = 1.0
        scanMaterial.isDoubleSided = true
        scanLine.materials = [scanMaterial]
        let scanNode = SCNNode(geometry: scanLine)
        scanNode.position = SCNVector3(0, 0.2, 0.001)

        let scanAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.move(to: SCNVector3(0, 0.2, 0.001), duration: 0),
                SCNAction.move(to: SCNVector3(0, Float(height) + 0.2, 0.001), duration: 2.0),
                SCNAction.wait(duration: 0.5)
            ])
        )
        scanNode.runAction(scanAction)
        display.addChildNode(scanNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Cold blue-purple ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#1A1A3E")
        ambient.intensity = CGFloat(intensity * 0.25)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Main blue-white spot
        let mainSpot = SCNLight()
        mainSpot.type = .spot
        mainSpot.color = NSColor(hex: "#E0E8FF")
        mainSpot.intensity = CGFloat(intensity * 0.8)
        mainSpot.spotInnerAngle = 30
        mainSpot.spotOuterAngle = 60
        mainSpot.castsShadow = true
        mainSpot.shadowRadius = 3
        let mainSpotNode = SCNNode()
        mainSpotNode.light = mainSpot
        mainSpotNode.position = SCNVector3(0, 6, 2)
        mainSpotNode.look(at: SCNVector3(0, 0, 0))
        mainSpotNode.name = "mainSpotLight"
        scene.rootNode.addChildNode(mainSpotNode)

        // Purple accent left
        let leftAccent = SCNLight()
        leftAccent.type = .spot
        leftAccent.color = NSColor(hex: palette.accentColor)
        leftAccent.intensity = CGFloat(intensity * 0.3)
        leftAccent.spotInnerAngle = 40
        leftAccent.spotOuterAngle = 70
        let leftNode = SCNNode()
        leftNode.light = leftAccent
        leftNode.position = SCNVector3(-6, 5, 3)
        leftNode.look(at: SCNVector3(-4, 0, 3))
        leftNode.name = "leftAccentLight"
        scene.rootNode.addChildNode(leftNode)

        // Cyan accent right
        let rightAccent = SCNLight()
        rightAccent.type = .spot
        rightAccent.color = NSColor(hex: palette.accentColorSecondary)
        rightAccent.intensity = CGFloat(intensity * 0.3)
        rightAccent.spotInnerAngle = 40
        rightAccent.spotOuterAngle = 70
        let rightNode = SCNNode()
        rightNode.light = rightAccent
        rightNode.position = SCNVector3(6, 5, 3)
        rightNode.look(at: SCNVector3(4, 0, 3))
        rightNode.name = "rightAccentLight"
        scene.rootNode.addChildNode(rightNode)

        // Floor strip lights
        for xPos: Float in [-3, 3] {
            let stripLight = SCNLight()
            stripLight.type = .omni
            stripLight.color = NSColor(hex: palette.accentColor)
            stripLight.intensity = CGFloat(intensity * 0.15)
            stripLight.attenuationStartDistance = 0
            stripLight.attenuationEndDistance = 4.0
            let stripNode = SCNNode()
            stripNode.light = stripLight
            stripNode.position = SCNVector3(xPos, 0.1, 4)
            scene.rootNode.addChildNode(stripNode)
        }
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Floating holographic symbols
        let symbolPositions: [(Float, Float, Float)] = [
            (-6, 3, 2), (6, 2.5, 5), (-3, 4, 8), (5, 3.5, 1)
        ]
        for (i, pos) in symbolPositions.enumerated() {
            let symbol = buildHoloSymbol()
            symbol.position = SCNVector3(pos.0, pos.1, pos.2)
            symbol.name = "holoSymbol_\(i)"
            decorations.addChildNode(symbol)
        }

        // Ceiling pipes
        let pipePositions: [(Float, Float)] = [(-3, 0), (3, 0), (-3, 6), (3, 6)]
        for (i, pos) in pipePositions.enumerated() {
            let pipe = buildCeilingPipe(length: CGFloat(dimensions.depth) * 0.7)
            pipe.position = SCNVector3(pos.0, dimensions.height - 0.3, pos.1)
            pipe.name = "pipe_\(i)"
            decorations.addChildNode(pipe)
        }

        return decorations
    }

    // MARK: - Private Helpers

    private func addFloorGlowGrid(to room: SCNNode, dimensions: RoomDimensions) {
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = NSColor(hex: palette.gridColor)
        gridMaterial.emission.contents = NSColor(hex: palette.accentColor)
        gridMaterial.emission.intensity = 0.4

        let spacing: Float = 1.0
        let halfW = dimensions.width / 2.0
        let depth = dimensions.depth

        let xCount = Int(depth / spacing)
        for i in 0...xCount {
            let z = Float(i) * spacing - 2.0
            let line = SCNBox(width: CGFloat(dimensions.width), height: 0.008, length: 0.025, chamferRadius: 0)
            line.materials = [gridMaterial]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(0, 0.002, z)
            room.addChildNode(lineNode)
        }

        let zCount = Int(dimensions.width / spacing)
        for i in 0...zCount {
            let x = Float(i) * spacing - halfW
            let line = SCNBox(width: 0.025, height: 0.008, length: CGFloat(depth), chamferRadius: 0)
            line.materials = [gridMaterial]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x, 0.002, depth / 2.0 - 2.0)
            room.addChildNode(lineNode)
        }
    }

    private func addWallSeams(to room: SCNNode, dimensions: RoomDimensions) {
        let seamMaterial = SCNMaterial()
        seamMaterial.diffuse.contents = NSColor(hex: "#0A0A1E")
        seamMaterial.emission.contents = NSColor(hex: palette.accentColor)
        seamMaterial.emission.intensity = 0.2

        // Horizontal seams on back wall
        let panelHeight: Float = 1.5
        let seamCount = Int(dimensions.height / panelHeight)
        for i in 1..<seamCount {
            let seam = SCNBox(width: CGFloat(dimensions.width) + 0.01, height: 0.01, length: 0.16, chamferRadius: 0)
            seam.materials = [seamMaterial]
            let seamNode = SCNNode(geometry: seam)
            seamNode.position = SCNVector3(0, Float(i) * panelHeight, -2.0)
            room.addChildNode(seamNode)
        }
    }

    private func buildStarfieldWindow(width: CGFloat, height: CGFloat) -> SCNNode {
        let window = SCNNode()

        // Window frame (recessed)
        let frame = SCNBox(width: width + 0.1, height: height + 0.1, length: 0.05, chamferRadius: 0.02)
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = NSColor(hex: "#1A1A3E")
        frameMaterial.metalness.contents = 0.5
        frame.materials = [frameMaterial]
        let frameNode = SCNNode(geometry: frame)
        window.addChildNode(frameNode)

        // Starfield content (SpriteKit)
        let starPlane = SCNPlane(width: width, height: height)
        let starMaterial = SCNMaterial()
        let starScene = createStarfieldScene(width: 512, height: 384)
        starMaterial.diffuse.contents = starScene
        starMaterial.emission.contents = starScene
        starMaterial.emission.intensity = 0.3
        starPlane.materials = [starMaterial]
        let starNode = SCNNode(geometry: starPlane)
        starNode.position = SCNVector3(0, 0, 0.03)
        window.addChildNode(starNode)

        return window
    }

    private func createStarfieldScene(width: CGFloat, height: CGFloat) -> SKScene {
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = NSColor(hex: "#000005")

        // Stars
        for _ in 0..<80 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.0))
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height)
            )
            star.alpha = CGFloat.random(in: 0.3...1.0)

            let twinkle = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: CGFloat.random(in: 0.2...0.5), duration: Double.random(in: 0.5...2)),
                    SKAction.fadeAlpha(to: CGFloat.random(in: 0.7...1.0), duration: Double.random(in: 0.5...2))
                ])
            )
            star.run(twinkle)
            scene.addChild(star)
        }

        // Distant nebula (colored glow)
        let nebula = SKShapeNode(circleOfRadius: 40)
        nebula.fillColor = NSColor(hex: "#4A0E8F").withAlphaComponent(0.3)
        nebula.strokeColor = .clear
        nebula.position = CGPoint(x: width * 0.7, y: height * 0.4)
        nebula.setScale(2.0)
        scene.addChild(nebula)

        let nebula2 = SKShapeNode(circleOfRadius: 30)
        nebula2.fillColor = NSColor(hex: "#00BCD4").withAlphaComponent(0.15)
        nebula2.strokeColor = .clear
        nebula2.position = CGPoint(x: width * 0.3, y: height * 0.7)
        nebula2.setScale(1.5)
        scene.addChild(nebula2)

        return scene
    }

    private func buildHoloSymbol() -> SCNNode {
        let symbol = SCNNode()

        let plane = SCNPlane(width: 0.3, height: 0.3)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: palette.accentColorSecondary).withAlphaComponent(0.4)
        material.emission.contents = NSColor(hex: palette.accentColorSecondary)
        material.emission.intensity = 0.6
        material.isDoubleSided = true
        plane.materials = [material]
        let planeNode = SCNNode(geometry: plane)
        symbol.addChildNode(planeNode)

        // Slow rotation
        let rotate = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8)
        )
        symbol.runAction(rotate)

        // Gentle float
        let float = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 2),
                SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 2)
            ])
        )
        symbol.runAction(float)

        return symbol
    }

    private func buildCeilingPipe(length: CGFloat) -> SCNNode {
        let pipe = SCNCylinder(radius: 0.05, height: length)
        let pipeMaterial = SCNMaterial()
        pipeMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        pipeMaterial.metalness.contents = 0.7
        pipeMaterial.roughness.contents = 0.3
        pipe.materials = [pipeMaterial]
        let pipeNode = SCNNode(geometry: pipe)
        pipeNode.eulerAngles.x = CGFloat.pi / 2
        return pipeNode
    }
}
