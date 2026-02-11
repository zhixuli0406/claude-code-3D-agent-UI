import SceneKit
import SpriteKit

struct UnderwaterLabThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .underwaterLab
    let palette: ThemeColorPalette = .underwaterLab

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "underwater_environment"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Metal-grate floor
        let floor = SCNBox(width: w, height: 0.1, length: d, chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(hex: palette.floorColor)
        floorMaterial.metalness.contents = 0.5
        floorMaterial.roughness.contents = 0.5
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        floorNode.name = "floor"
        room.addChildNode(floorNode)

        // Glowing cyan grid
        addGlowGrid(to: room, dimensions: dimensions)

        // Viewport windows showing underwater scene
        addViewportWindows(to: room, dimensions: dimensions)

        return room
    }

    // MARK: - Workstation (Submarine Console)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let console = SCNNode()
        console.name = "subConsole"

        let w = CGFloat(size.width)
        let d = CGFloat(size.depth)
        let consoleHeight: CGFloat = 0.75

        let metalMaterial = SCNMaterial()
        metalMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        metalMaterial.metalness.contents = 0.6
        metalMaterial.roughness.contents = 0.4

        // Console body
        let body = SCNBox(width: w, height: consoleHeight, length: d * 0.6, chamferRadius: 0.03)
        body.materials = [metalMaterial]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, Float(consoleHeight) / 2.0, 0)
        console.addChildNode(bodyNode)

        // Cyan glow strip on edge
        let stripMaterial = SCNMaterial()
        stripMaterial.diffuse.contents = NSColor(hex: palette.accentColor)
        stripMaterial.emission.contents = NSColor(hex: palette.accentColor)
        stripMaterial.emission.intensity = 0.8
        let strip = SCNBox(width: w + 0.02, height: 0.02, length: 0.02, chamferRadius: 0)
        strip.materials = [stripMaterial]
        let stripNode = SCNNode(geometry: strip)
        stripNode.position = SCNVector3(0, Float(consoleHeight), Float(d) * 0.3)
        console.addChildNode(stripNode)

        // Pressure gauge
        let gauge = SCNCylinder(radius: 0.06, height: 0.02)
        let gaugeMat = SCNMaterial()
        gaugeMat.diffuse.contents = NSColor(hex: "#1A4A5E")
        gaugeMat.metalness.contents = 0.7
        gauge.materials = [gaugeMat]
        let gaugeNode = SCNNode(geometry: gauge)
        gaugeNode.position = SCNVector3(Float(w) * 0.35, Float(consoleHeight) + 0.02, 0)
        console.addChildNode(gaugeNode)

        // Gauge glow
        let gaugeGlow = SCNSphere(radius: 0.03)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor(hex: palette.accentColorSecondary)
        glowMat.emission.contents = NSColor(hex: palette.accentColorSecondary)
        glowMat.emission.intensity = 0.8
        gaugeGlow.materials = [glowMat]
        let glowNode = SCNNode(geometry: gaugeGlow)
        glowNode.position = SCNVector3(Float(w) * 0.35, Float(consoleHeight) + 0.04, 0)
        glowNode.runAction(.repeatForever(.sequence([
            .fadeOpacity(to: 0.4, duration: 1.0),
            .fadeOpacity(to: 1.0, duration: 1.0)
        ])))
        console.addChildNode(glowNode)

        return console
    }

    // MARK: - Seating (Submarine Stool)

    func buildSeating() -> SCNNode {
        let stool = SCNNode()
        stool.name = "subStool"

        let metalMat = SCNMaterial()
        metalMat.diffuse.contents = NSColor(hex: palette.structuralColor)
        metalMat.metalness.contents = 0.6

        let seatMat = SCNMaterial()
        seatMat.diffuse.contents = NSColor(hex: "#0D3B54")
        seatMat.roughness.contents = 0.6

        // Seat
        let seat = SCNCylinder(radius: 0.18, height: 0.05)
        seat.materials = [seatMat]
        let seatNode = SCNNode(geometry: seat)
        seatNode.position = SCNVector3(0, 0.45, 0)
        stool.addChildNode(seatNode)

        // Pedestal
        let pedestal = SCNCylinder(radius: 0.04, height: 0.42)
        pedestal.materials = [metalMat]
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(0, 0.21, 0)
        stool.addChildNode(pedestalNode)

        // Base plate
        let base = SCNBox(width: 0.35, height: 0.02, length: 0.35, chamferRadius: 0.02)
        base.materials = [metalMat]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.01, 0)
        stool.addChildNode(baseNode)

        return stool
    }

    // MARK: - Display (Sonar Screen)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "sonarScreen"

        // Base pedestal
        let baseMat = SCNMaterial()
        baseMat.diffuse.contents = NSColor(hex: palette.structuralColor)
        baseMat.metalness.contents = 0.6
        let base = SCNCylinder(radius: 0.1, height: 0.15)
        base.materials = [baseMat]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.075, 0)
        display.addChildNode(baseNode)

        // Screen frame
        let frame = SCNBox(width: width + 0.06, height: height + 0.06, length: 0.04, chamferRadius: 0.02)
        frame.materials = [baseMat]
        let frameNode = SCNNode(geometry: frame)
        frameNode.position = SCNVector3(0, Float(height) / 2.0 + 0.2, 0)
        display.addChildNode(frameNode)

        // Screen content
        let screen = SCNPlane(width: width, height: height)
        let screenMat = SCNMaterial()
        let skScene = createSonarContent(width: 512, height: 320)
        screenMat.diffuse.contents = skScene
        screenMat.emission.contents = skScene
        screenMat.emission.intensity = 0.7
        screen.materials = [screenMat]
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, Float(height) / 2.0 + 0.2, 0.025)
        screenNode.name = "screen"
        display.addChildNode(screenNode)

        // Glow ring around screen
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: palette.accentColor).withAlphaComponent(0.4)
        ringMat.emission.contents = NSColor(hex: palette.accentColor)
        ringMat.emission.intensity = 0.5
        let glowBox = SCNBox(width: width + 0.08, height: height + 0.08, length: 0.01, chamferRadius: 0.02)
        glowBox.materials = [ringMat]
        let glowNode = SCNNode(geometry: glowBox)
        glowNode.position = SCNVector3(0, Float(height) / 2.0 + 0.2, -0.01)
        display.addChildNode(glowNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Deep blue ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#0A2A3C")
        ambient.intensity = CGFloat(intensity * 0.4)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Main cool white spotlight
        let mainSpot = SCNLight()
        mainSpot.type = .spot
        mainSpot.color = NSColor(hex: "#D0E8FF")
        mainSpot.intensity = CGFloat(intensity * 0.9)
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

        // Cyan accent left
        let leftAccent = SCNLight()
        leftAccent.type = .spot
        leftAccent.color = NSColor(hex: palette.accentColor)
        leftAccent.intensity = CGFloat(intensity * 0.5)
        leftAccent.spotInnerAngle = 40
        leftAccent.spotOuterAngle = 70
        let leftNode = SCNNode()
        leftNode.light = leftAccent
        leftNode.position = SCNVector3(-6, 5, 3)
        leftNode.look(at: SCNVector3(-4, 0, 3))
        leftNode.name = "leftAccentLight"
        scene.rootNode.addChildNode(leftNode)

        // Green accent right
        let rightAccent = SCNLight()
        rightAccent.type = .spot
        rightAccent.color = NSColor(hex: palette.accentColorSecondary)
        rightAccent.intensity = CGFloat(intensity * 0.4)
        rightAccent.spotInnerAngle = 40
        rightAccent.spotOuterAngle = 70
        let rightNode = SCNNode()
        rightNode.light = rightAccent
        rightNode.position = SCNVector3(6, 5, 3)
        rightNode.look(at: SCNVector3(4, 0, 3))
        rightNode.name = "rightAccentLight"
        scene.rootNode.addChildNode(rightNode)

        // Bioluminescent point lights
        let bioPositions: [(Float, Float, Float)] = [
            (-5, 1, 2), (5, 1.5, 5), (-3, 0.8, 8), (4, 1.2, 1)
        ]
        for pos in bioPositions {
            let bioLight = SCNLight()
            bioLight.type = .omni
            bioLight.color = NSColor(hex: palette.accentColor)
            bioLight.intensity = CGFloat(intensity * 0.15)
            bioLight.attenuationStartDistance = 0
            bioLight.attenuationEndDistance = 3.0
            let bioNode = SCNNode()
            bioNode.light = bioLight
            bioNode.position = SCNVector3(pos.0, pos.1, pos.2)
            scene.rootNode.addChildNode(bioNode)
        }
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Pipes along ceiling
        addCeilingPipes(to: decorations, dimensions: dimensions)

        // Jellyfish (bioluminescent decorations)
        let jellyPositions: [(Float, Float, Float)] = [
            (-5, 3, 3), (4, 3.5, 6), (-2, 4, 9), (6, 2.8, 2)
        ]
        for (i, pos) in jellyPositions.enumerated() {
            let jelly = buildJellyfish()
            jelly.position = SCNVector3(pos.0, pos.1, pos.2)
            jelly.name = "jellyfish_\(i)"
            decorations.addChildNode(jelly)
        }

        // Fish swimming around
        for i in 0..<6 {
            let fish = buildFish()
            fish.position = SCNVector3(
                Float.random(in: -7...7),
                Float.random(in: 1.5...4.0),
                Float.random(in: 0...10)
            )
            fish.name = "fish_\(i)"
            decorations.addChildNode(fish)
        }

        return decorations
    }

    // MARK: - Agent Floor Tile

    func buildAgentFloorTile(isLeader: Bool) -> SCNNode {
        let tile = SCNBox(width: 1.2, height: 0.1, length: 1.2, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: palette.floorColor)
        material.metalness.contents = 0.5
        material.roughness.contents = 0.5
        tile.materials = [material]
        let node = SCNNode(geometry: tile)
        node.name = "agentFloorTile"

        // Cyan glow ring
        let ring = SCNBox(width: 1.22, height: 0.02, length: 1.22, chamferRadius: 0)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: palette.accentColor).withAlphaComponent(0.3)
        ringMat.emission.contents = NSColor(hex: palette.accentColor)
        ringMat.emission.intensity = 0.4
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.06, 0)
        node.addChildNode(ringNode)

        return node
    }

    // MARK: - Private Helpers

    private func addGlowGrid(to room: SCNNode, dimensions: RoomDimensions) {
        let gridMat = SCNMaterial()
        gridMat.diffuse.contents = NSColor(hex: palette.accentColor).withAlphaComponent(0.2)
        gridMat.emission.contents = NSColor(hex: palette.accentColor)
        gridMat.emission.intensity = 0.3

        let spacing: Float = 1.5
        let halfW = dimensions.width / 2.0

        let xCount = Int(dimensions.depth / spacing)
        for i in 0...xCount {
            let z = Float(i) * spacing - 2.0
            let line = SCNBox(width: CGFloat(dimensions.width), height: 0.008, length: 0.02, chamferRadius: 0)
            line.materials = [gridMat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(0, 0.002, z)
            room.addChildNode(lineNode)
        }

        let zCount = Int(dimensions.width / spacing)
        for i in 0...zCount {
            let x = Float(i) * spacing - halfW
            let line = SCNBox(width: 0.02, height: 0.008, length: CGFloat(dimensions.depth), chamferRadius: 0)
            line.materials = [gridMat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x, 0.002, dimensions.depth / 2.0 - 2.0)
            room.addChildNode(lineNode)
        }
    }

    private func addViewportWindows(to room: SCNNode, dimensions: RoomDimensions) {
        let windowPositions: [(Float, Float, Float, Float)] = [
            (-dimensions.width / 2.0 - 0.01, 2.5, 3, Float.pi / 2),
            (dimensions.width / 2.0 + 0.01, 2.5, 3, -Float.pi / 2),
            (-dimensions.width / 2.0 - 0.01, 2.5, 7, Float.pi / 2),
            (dimensions.width / 2.0 + 0.01, 2.5, 7, -Float.pi / 2)
        ]

        for (i, pos) in windowPositions.enumerated() {
            let window = buildViewport()
            window.position = SCNVector3(pos.0, pos.1, pos.2)
            window.eulerAngles.y = CGFloat(pos.3)
            window.name = "viewport_\(i)"
            room.addChildNode(window)
        }
    }

    private func buildViewport() -> SCNNode {
        let viewport = SCNNode()

        // Frame
        let frame = SCNTorus(ringRadius: 0.6, pipeRadius: 0.05)
        let frameMat = SCNMaterial()
        frameMat.diffuse.contents = NSColor(hex: palette.structuralColor)
        frameMat.metalness.contents = 0.7
        frame.materials = [frameMat]
        let frameNode = SCNNode(geometry: frame)
        frameNode.eulerAngles.x = CGFloat.pi / 2
        viewport.addChildNode(frameNode)

        // Glass (deep blue with light)
        let glass = SCNCylinder(radius: 0.55, height: 0.02)
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents = NSColor(hex: "#0077B6").withAlphaComponent(0.4)
        glassMat.emission.contents = NSColor(hex: "#00B4D8")
        glassMat.emission.intensity = 0.3
        glassMat.transparency = 0.5
        glassMat.isDoubleSided = true
        glass.materials = [glassMat]
        let glassNode = SCNNode(geometry: glass)
        glassNode.eulerAngles.x = CGFloat.pi / 2
        viewport.addChildNode(glassNode)

        // Light from viewport
        let vpLight = SCNLight()
        vpLight.type = .omni
        vpLight.color = NSColor(hex: "#00B4D8")
        vpLight.intensity = 100
        vpLight.attenuationStartDistance = 0
        vpLight.attenuationEndDistance = 3.0
        let lightNode = SCNNode()
        lightNode.light = vpLight
        lightNode.position = SCNVector3(0, 0, 0.1)
        viewport.addChildNode(lightNode)

        return viewport
    }

    private func addCeilingPipes(to decorations: SCNNode, dimensions: RoomDimensions) {
        let pipeMat = SCNMaterial()
        pipeMat.diffuse.contents = NSColor(hex: "#37474F")
        pipeMat.metalness.contents = 0.7
        pipeMat.roughness.contents = 0.3

        let pipePositions: [(Float, Float)] = [(-4, 4.5), (4, 4.5), (0, 4.8)]
        for pos in pipePositions {
            let pipe = SCNCylinder(radius: 0.08, height: CGFloat(dimensions.depth))
            pipe.materials = [pipeMat]
            let pipeNode = SCNNode(geometry: pipe)
            pipeNode.position = SCNVector3(pos.0, pos.1, dimensions.depth / 2.0 - 2.0)
            pipeNode.eulerAngles.x = CGFloat.pi / 2
            decorations.addChildNode(pipeNode)
        }
    }

    private func buildJellyfish() -> SCNNode {
        let jelly = SCNNode()

        // Bell
        let bell = SCNSphere(radius: 0.2)
        let bellMat = SCNMaterial()
        bellMat.diffuse.contents = NSColor(hex: palette.accentColor).withAlphaComponent(0.3)
        bellMat.emission.contents = NSColor(hex: palette.accentColor)
        bellMat.emission.intensity = 0.6
        bellMat.transparency = 0.6
        bellMat.isDoubleSided = true
        bell.materials = [bellMat]
        let bellNode = SCNNode(geometry: bell)
        bellNode.scale = SCNVector3(1, 0.7, 1)
        jelly.addChildNode(bellNode)

        // Tentacles
        for i in 0..<5 {
            let angle = Float(i) / 5.0 * Float.pi * 2
            let tentacle = SCNCylinder(radius: 0.01, height: 0.4)
            let tentMat = SCNMaterial()
            tentMat.diffuse.contents = NSColor(hex: palette.accentColor).withAlphaComponent(0.4)
            tentMat.emission.contents = NSColor(hex: palette.accentColor)
            tentMat.emission.intensity = 0.4
            tentacle.materials = [tentMat]
            let tentNode = SCNNode(geometry: tentacle)
            tentNode.position = SCNVector3(cos(angle) * 0.1, -0.3, sin(angle) * 0.1)
            jelly.addChildNode(tentNode)
        }

        // Pulsing animation
        let pulse = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.scale(to: 1.1, duration: 1.0),
                SCNAction.scale(to: 0.9, duration: 1.0)
            ])
        )
        jelly.runAction(pulse)

        // Gentle float
        let float = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 3.0),
                SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 3.0)
            ])
        )
        jelly.runAction(float)

        // Glow light
        let glowLight = SCNLight()
        glowLight.type = .omni
        glowLight.color = NSColor(hex: palette.accentColor)
        glowLight.intensity = 30
        glowLight.attenuationStartDistance = 0
        glowLight.attenuationEndDistance = 1.5
        let glowLightNode = SCNNode()
        glowLightNode.light = glowLight
        jelly.addChildNode(glowLightNode)

        return jelly
    }

    private func buildFish() -> SCNNode {
        let fish = SCNNode()

        // Body (elongated sphere)
        let body = SCNSphere(radius: 0.08)
        let bodyMat = SCNMaterial()
        let fishColors = ["#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF"]
        bodyMat.diffuse.contents = NSColor(hex: fishColors.randomElement()!)
        bodyMat.roughness.contents = 0.3
        body.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.scale = SCNVector3(1.5, 0.8, 0.6)
        fish.addChildNode(bodyNode)

        // Tail
        let tail = SCNPyramid(width: 0.06, height: 0.08, length: 0.02)
        tail.materials = [bodyMat]
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(-0.12, 0, 0)
        tailNode.eulerAngles.z = CGFloat.pi / 2
        fish.addChildNode(tailNode)

        // Swimming animation (figure-8 path)
        let swimDuration = Double.random(in: 6...12)
        let radius: Float = Float.random(in: 2...5)
        let swim = SCNAction.customAction(duration: swimDuration) { node, elapsed in
            let t = CGFloat(elapsed / CGFloat(swimDuration)) * CGFloat.pi * 2
            let startPos = node.position
            node.position = SCNVector3(
                startPos.x + cos(t) * 0.01,
                startPos.y + sin(t * 2) * 0.005,
                startPos.z + sin(t) * 0.01
            )
        }
        fish.runAction(.repeatForever(swim))

        // Drift in one direction
        let drift = SCNAction.moveBy(
            x: CGFloat(Float.random(in: -radius...radius)),
            y: 0,
            z: CGFloat(Float.random(in: -radius...radius)),
            duration: swimDuration
        )
        let driftBack = drift.reversed()
        fish.runAction(.repeatForever(.sequence([drift, driftBack])))

        return fish
    }

    private func createSonarContent(width: CGFloat, height: CGFloat) -> SKScene {
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = NSColor(hex: "#001B2E")

        // Title
        let title = SKLabelNode(text: "SONAR ARRAY")
        title.fontName = "Menlo-Bold"
        title.fontSize = 20
        title.fontColor = NSColor(hex: palette.accentColor)
        title.position = CGPoint(x: width / 2, y: height - 30)
        scene.addChild(title)

        // Status
        let status = SKLabelNode(text: "DEPTH: 2,847m")
        status.fontName = "Menlo"
        status.fontSize = 14
        status.fontColor = NSColor(hex: palette.accentColor)
        status.position = CGPoint(x: width / 2, y: 30)
        scene.addChild(status)

        // Sonar sweep circle
        let circle = SKShapeNode(circleOfRadius: 80)
        circle.strokeColor = NSColor(hex: palette.accentColor).withAlphaComponent(0.5)
        circle.lineWidth = 1
        circle.position = CGPoint(x: width / 2, y: height / 2)
        scene.addChild(circle)

        let innerCircle = SKShapeNode(circleOfRadius: 40)
        innerCircle.strokeColor = NSColor(hex: palette.accentColor).withAlphaComponent(0.3)
        innerCircle.lineWidth = 1
        innerCircle.position = CGPoint(x: width / 2, y: height / 2)
        scene.addChild(innerCircle)

        // Sweep line
        let sweepLine = SKShapeNode(rectOf: CGSize(width: 2, height: 80))
        sweepLine.fillColor = NSColor(hex: palette.accentColor).withAlphaComponent(0.6)
        sweepLine.strokeColor = .clear
        sweepLine.position = CGPoint(x: width / 2, y: height / 2 + 40)
        let rotate = SKAction.repeatForever(SKAction.rotate(byAngle: -CGFloat.pi * 2, duration: 4.0))
        sweepLine.run(rotate)
        scene.addChild(sweepLine)

        return scene
    }
}
