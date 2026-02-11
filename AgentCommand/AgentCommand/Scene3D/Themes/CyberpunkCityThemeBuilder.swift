import SceneKit
import SpriteKit

struct CyberpunkCityThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .cyberpunkCity
    let palette: ThemeColorPalette = .cyberpunkCity

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let room = SCNNode()
        room.name = "cyberpunk_environment"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Dark wet street floor
        let floor = SCNBox(width: w, height: 0.1, length: d, chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(hex: palette.floorColor)
        floorMaterial.metalness.contents = 0.4
        floorMaterial.roughness.contents = 0.3
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        floorNode.name = "floor"
        room.addChildNode(floorNode)

        // Neon grid lines on floor
        addNeonGrid(to: room, dimensions: dimensions)

        // Building silhouettes on sides
        addBuildingSilhouettes(to: room, dimensions: dimensions)

        return room
    }

    // MARK: - Workstation (Neon Terminal Desk)

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let desk = SCNNode()
        desk.name = "neonTerminal"

        let w = CGFloat(size.width)
        let d = CGFloat(size.depth)
        let deskHeight: CGFloat = 0.75

        let darkMetal = SCNMaterial()
        darkMetal.diffuse.contents = NSColor(hex: "#1A0A2E")
        darkMetal.metalness.contents = 0.5
        darkMetal.roughness.contents = 0.4

        // Main desk body
        let body = SCNBox(width: w, height: deskHeight, length: d * 0.6, chamferRadius: 0.01)
        body.materials = [darkMetal]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, Float(deskHeight) / 2.0, 0)
        desk.addChildNode(bodyNode)

        // Neon edge strips (pink)
        let stripMaterial = SCNMaterial()
        stripMaterial.diffuse.contents = NSColor(hex: palette.accentColor)
        stripMaterial.emission.contents = NSColor(hex: palette.accentColor)
        stripMaterial.emission.intensity = 1.0

        for zOff: Float in [-Float(d) * 0.3, Float(d) * 0.3] {
            let strip = SCNBox(width: w + 0.02, height: 0.02, length: 0.02, chamferRadius: 0)
            strip.materials = [stripMaterial]
            let stripNode = SCNNode(geometry: strip)
            stripNode.position = SCNVector3(0, Float(deskHeight), zOff)
            desk.addChildNode(stripNode)
        }

        // Cyan accent strip on front
        let cyanStrip = SCNMaterial()
        cyanStrip.diffuse.contents = NSColor(hex: palette.accentColorSecondary)
        cyanStrip.emission.contents = NSColor(hex: palette.accentColorSecondary)
        cyanStrip.emission.intensity = 0.8

        let frontStrip = SCNBox(width: w + 0.02, height: 0.015, length: 0.015, chamferRadius: 0)
        frontStrip.materials = [cyanStrip]
        let frontStripNode = SCNNode(geometry: frontStrip)
        frontStripNode.position = SCNVector3(0, Float(deskHeight) * 0.5, Float(d) * 0.3 + 0.01)
        desk.addChildNode(frontStripNode)

        return desk
    }

    // MARK: - Seating (Neon Bar Stool)

    func buildSeating() -> SCNNode {
        let stool = SCNNode()
        stool.name = "neonStool"

        let darkMaterial = SCNMaterial()
        darkMaterial.diffuse.contents = NSColor(hex: "#1A0A2E")
        darkMaterial.metalness.contents = 0.5

        // Seat
        let seat = SCNCylinder(radius: 0.2, height: 0.05)
        seat.materials = [darkMaterial]
        let seatNode = SCNNode(geometry: seat)
        seatNode.position = SCNVector3(0, 0.45, 0)
        stool.addChildNode(seatNode)

        // Neon ring under seat
        let ring = SCNTorus(ringRadius: 0.2, pipeRadius: 0.01)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = NSColor(hex: palette.accentColor)
        ringMaterial.emission.contents = NSColor(hex: palette.accentColor)
        ringMaterial.emission.intensity = 0.8
        ring.materials = [ringMaterial]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.42, 0)
        stool.addChildNode(ringNode)

        // Pedestal
        let pedestal = SCNCylinder(radius: 0.03, height: 0.42)
        pedestal.materials = [darkMaterial]
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(0, 0.21, 0)
        stool.addChildNode(pedestalNode)

        // Base
        let base = SCNCylinder(radius: 0.15, height: 0.02)
        base.materials = [darkMaterial]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.01, 0)
        stool.addChildNode(baseNode)

        return stool
    }

    // MARK: - Display (Holographic Billboard)

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "holoBillboard"

        // Frame with neon edges
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = NSColor(hex: "#1A0A2E")
        frameMaterial.metalness.contents = 0.5

        let frame = SCNBox(width: width + 0.06, height: height + 0.06, length: 0.03, chamferRadius: 0.01)
        frame.materials = [frameMaterial]
        let frameNode = SCNNode(geometry: frame)
        frameNode.position = SCNVector3(0, Float(height) / 2.0 + 0.2, 0)
        display.addChildNode(frameNode)

        // Screen
        let screen = SCNPlane(width: width, height: height)
        let screenMaterial = SCNMaterial()
        let skScene = MonitorBuilder.createScreenContent(
            width: 512, height: 320, accentColor: palette.accentColor
        )
        screenMaterial.diffuse.contents = skScene
        screenMaterial.emission.contents = skScene
        screenMaterial.emission.intensity = 0.9
        screen.materials = [screenMaterial]
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, Float(height) / 2.0 + 0.2, 0.02)
        screenNode.name = "screen"
        display.addChildNode(screenNode)

        // Neon glow border
        let glowColors = [palette.accentColor, palette.accentColorSecondary]
        for (i, edge) in buildNeonBorderEdges(width: width, height: height).enumerated() {
            let mat = SCNMaterial()
            let color = glowColors[i % 2]
            mat.diffuse.contents = NSColor(hex: color)
            mat.emission.contents = NSColor(hex: color)
            mat.emission.intensity = 1.0
            edge.geometry?.materials = [mat]
            edge.position.z = 0.025
            edge.position.y += CGFloat(height / 2.0 + 0.2)
            display.addChildNode(edge)
        }

        // Glitch scan line
        let scanLine = SCNPlane(width: width, height: 0.015)
        let scanMaterial = SCNMaterial()
        scanMaterial.diffuse.contents = NSColor(hex: palette.accentColorSecondary).withAlphaComponent(0.5)
        scanMaterial.emission.contents = NSColor(hex: palette.accentColorSecondary)
        scanMaterial.emission.intensity = 0.8
        scanMaterial.isDoubleSided = true
        scanLine.materials = [scanMaterial]
        let scanNode = SCNNode(geometry: scanLine)
        scanNode.position = SCNVector3(0, 0.2, 0.03)
        let scanAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.move(to: SCNVector3(0, 0.2, 0.03), duration: 0),
                SCNAction.move(to: SCNVector3(0, Float(height) + 0.2, 0.03), duration: 1.5),
                SCNAction.wait(duration: 0.3)
            ])
        )
        scanNode.runAction(scanAction)
        display.addChildNode(scanNode)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Dark ambient with purple tint
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#1A0A2E")
        ambient.intensity = CGFloat(intensity * 0.3)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Main spot (slightly warm)
        let mainSpot = SCNLight()
        mainSpot.type = .spot
        mainSpot.color = NSColor(hex: "#E0D0FF")
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

        // Pink neon accent left
        let leftAccent = SCNLight()
        leftAccent.type = .spot
        leftAccent.color = NSColor(hex: palette.accentColor)
        leftAccent.intensity = CGFloat(intensity * 0.6)
        leftAccent.spotInnerAngle = 40
        leftAccent.spotOuterAngle = 70
        let leftNode = SCNNode()
        leftNode.light = leftAccent
        leftNode.position = SCNVector3(-6, 5, 3)
        leftNode.look(at: SCNVector3(-4, 0, 3))
        leftNode.name = "leftAccentLight"
        scene.rootNode.addChildNode(leftNode)

        // Cyan neon accent right
        let rightAccent = SCNLight()
        rightAccent.type = .spot
        rightAccent.color = NSColor(hex: palette.accentColorSecondary)
        rightAccent.intensity = CGFloat(intensity * 0.6)
        rightAccent.spotInnerAngle = 40
        rightAccent.spotOuterAngle = 70
        let rightNode = SCNNode()
        rightNode.light = rightAccent
        rightNode.position = SCNVector3(6, 5, 3)
        rightNode.look(at: SCNVector3(4, 0, 3))
        rightNode.name = "rightAccentLight"
        scene.rootNode.addChildNode(rightNode)

        // Neon floor glow lights
        let neonColors = [palette.accentColor, palette.accentColorSecondary]
        for (i, xPos) in [-4.0, -1.0, 2.0, 5.0].enumerated() {
            let neonLight = SCNLight()
            neonLight.type = .omni
            neonLight.color = NSColor(hex: neonColors[i % 2])
            neonLight.intensity = CGFloat(intensity * 0.25)
            neonLight.attenuationStartDistance = 0
            neonLight.attenuationEndDistance = 3.5
            let neonNode = SCNNode()
            neonNode.light = neonLight
            neonNode.position = SCNVector3(Float(xPos), 0.2, 4)
            scene.rootNode.addChildNode(neonNode)
        }
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Holographic billboards floating in the air
        let billboardPositions: [(Float, Float, Float)] = [
            (-7, 4, 2), (7, 3.5, 5), (-5, 5, 9), (6, 4.5, 1)
        ]
        for (i, pos) in billboardPositions.enumerated() {
            let billboard = buildFloatingBillboard()
            billboard.position = SCNVector3(pos.0, pos.1, pos.2)
            billboard.name = "billboard_\(i)"
            decorations.addChildNode(billboard)
        }

        // Neon signs
        let signPositions: [(Float, Float, Float, String)] = [
            (-8, 2.5, 0, palette.accentColor),
            (8, 2.5, 4, palette.accentColorSecondary),
            (-8, 2.5, 8, palette.accentColor)
        ]
        for (i, pos) in signPositions.enumerated() {
            let sign = buildNeonSign(color: pos.3)
            sign.position = SCNVector3(pos.0, pos.1, pos.2)
            sign.name = "neonSign_\(i)"
            decorations.addChildNode(sign)
        }

        return decorations
    }

    // MARK: - Agent Floor Tile

    func buildAgentFloorTile(isLeader: Bool) -> SCNNode {
        let tile = SCNBox(width: 1.2, height: 0.1, length: 1.2, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: palette.floorColor)
        material.metalness.contents = 0.4
        material.roughness.contents = 0.3
        tile.materials = [material]
        let node = SCNNode(geometry: tile)
        node.name = "agentFloorTile"

        // Neon edge glow
        let edgeColor = isLeader ? palette.accentColor : palette.accentColorSecondary
        let ring = SCNBox(width: 1.22, height: 0.02, length: 1.22, chamferRadius: 0)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = NSColor(hex: edgeColor).withAlphaComponent(0.4)
        ringMaterial.emission.contents = NSColor(hex: edgeColor)
        ringMaterial.emission.intensity = 0.6
        ring.materials = [ringMaterial]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.06, 0)
        node.addChildNode(ringNode)

        return node
    }

    // MARK: - Private Helpers

    private func addNeonGrid(to room: SCNNode, dimensions: RoomDimensions) {
        let colors = [palette.accentColor, palette.accentColorSecondary]
        let spacing: Float = 2.0
        let halfW = dimensions.width / 2.0

        var lineIndex = 0
        let xCount = Int(dimensions.depth / spacing)
        for i in 0...xCount {
            let z = Float(i) * spacing - 2.0
            let line = SCNBox(width: CGFloat(dimensions.width), height: 0.008, length: 0.03, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: colors[lineIndex % 2]).withAlphaComponent(0.3)
            mat.emission.contents = NSColor(hex: colors[lineIndex % 2])
            mat.emission.intensity = 0.4
            line.materials = [mat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(0, 0.002, z)
            room.addChildNode(lineNode)
            lineIndex += 1
        }

        let zCount = Int(dimensions.width / spacing)
        for i in 0...zCount {
            let x = Float(i) * spacing - halfW
            let line = SCNBox(width: 0.03, height: 0.008, length: CGFloat(dimensions.depth), chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: colors[lineIndex % 2]).withAlphaComponent(0.3)
            mat.emission.contents = NSColor(hex: colors[lineIndex % 2])
            mat.emission.intensity = 0.4
            line.materials = [mat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x, 0.002, dimensions.depth / 2.0 - 2.0)
            room.addChildNode(lineNode)
            lineIndex += 1
        }
    }

    private func addBuildingSilhouettes(to room: SCNNode, dimensions: RoomDimensions) {
        let buildingMaterial = SCNMaterial()
        buildingMaterial.diffuse.contents = NSColor(hex: "#0D0221")
        buildingMaterial.roughness.contents = 0.9

        for side: Float in [-1, 1] {
            let xBase = side * (dimensions.width / 2.0 + 1.5)
            for i in 0..<5 {
                let height = CGFloat(Float.random(in: 3...8))
                let width = CGFloat(Float.random(in: 1.0...2.0))
                let depth = CGFloat(Float.random(in: 1.0...2.0))
                let building = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
                building.materials = [buildingMaterial]
                let buildingNode = SCNNode(geometry: building)
                buildingNode.position = SCNVector3(
                    xBase + Float.random(in: -1...1),
                    Float(height) / 2.0,
                    Float(i) * 3.0 - 1.0
                )
                room.addChildNode(buildingNode)

                // Random lit windows
                addWindowLights(to: buildingNode, buildingWidth: width, buildingHeight: height, side: side)
            }
        }
    }

    private func addWindowLights(to building: SCNNode, buildingWidth: CGFloat, buildingHeight: CGFloat, side: Float) {
        let windowColors = [palette.accentColor, palette.accentColorSecondary, "#FFD700", "#FFFFFF"]
        let rows = Int(buildingHeight / 0.6)
        let cols = Int(buildingWidth / 0.4)
        for r in 0..<rows {
            for c in 0..<cols {
                guard Float.random(in: 0...1) > 0.5 else { continue }
                let window = SCNPlane(width: 0.15, height: 0.2)
                let mat = SCNMaterial()
                let color = windowColors.randomElement()!
                mat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.6)
                mat.emission.contents = NSColor(hex: color)
                mat.emission.intensity = 0.5
                window.materials = [mat]
                let windowNode = SCNNode(geometry: window)
                windowNode.position = SCNVector3(
                    side > 0 ? -Float(buildingWidth) / 2.0 - 0.01 : Float(buildingWidth) / 2.0 + 0.01,
                    Float(r) * 0.6 - Float(buildingHeight) / 2.0 + 0.4,
                    Float(c) * 0.4 - Float(buildingWidth) / 2.0 + 0.2
                )
                windowNode.eulerAngles.y = side > 0 ? CGFloat.pi / 2 : -CGFloat.pi / 2
                building.addChildNode(windowNode)
            }
        }
    }

    private func buildFloatingBillboard() -> SCNNode {
        let billboard = SCNNode()

        let plane = SCNPlane(width: 1.5, height: 0.8)
        let material = SCNMaterial()
        let colors = [palette.accentColor, palette.accentColorSecondary]
        let color = colors.randomElement()!
        material.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.3)
        material.emission.contents = NSColor(hex: color)
        material.emission.intensity = 0.5
        material.isDoubleSided = true
        plane.materials = [material]
        let planeNode = SCNNode(geometry: plane)
        billboard.addChildNode(planeNode)

        // Billboard constraint
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .Y
        billboard.constraints = [billboardConstraint]

        // Gentle float
        let float = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 2.5),
                SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 2.5)
            ])
        )
        billboard.runAction(float)

        // Flicker effect
        let flicker = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.fadeOpacity(to: 0.7, duration: 0.05),
                SCNAction.fadeOpacity(to: 1.0, duration: 0.05),
                SCNAction.wait(duration: Double.random(in: 2...6))
            ])
        )
        billboard.runAction(flicker)

        return billboard
    }

    private func buildNeonSign(color: String) -> SCNNode {
        let sign = SCNNode()

        let tube = SCNCylinder(radius: 0.02, height: 1.0)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: color)
        mat.emission.contents = NSColor(hex: color)
        mat.emission.intensity = 1.0
        tube.materials = [mat]
        let tubeNode = SCNNode(geometry: tube)
        tubeNode.eulerAngles.z = CGFloat.pi / 2
        sign.addChildNode(tubeNode)

        // Glow light
        let light = SCNLight()
        light.type = .omni
        light.color = NSColor(hex: color)
        light.intensity = 200
        light.attenuationStartDistance = 0
        light.attenuationEndDistance = 3.0
        let lightNode = SCNNode()
        lightNode.light = light
        sign.addChildNode(lightNode)

        // Flicker
        let flicker = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.run { node in
                    node.light?.intensity = CGFloat(Float.random(in: 150...250))
                },
                SCNAction.wait(duration: 0.15)
            ])
        )
        lightNode.runAction(flicker)

        return sign
    }

    private func buildNeonBorderEdges(width: CGFloat, height: CGFloat) -> [SCNNode] {
        var edges: [SCNNode] = []
        let thickness: CGFloat = 0.015

        // Top
        let top = SCNBox(width: width + 0.04, height: thickness, length: thickness, chamferRadius: 0)
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, Float(height) / 2.0 + 0.01, 0)
        edges.append(topNode)

        // Bottom
        let bottom = SCNBox(width: width + 0.04, height: thickness, length: thickness, chamferRadius: 0)
        let bottomNode = SCNNode(geometry: bottom)
        bottomNode.position = SCNVector3(0, -Float(height) / 2.0 - 0.01, 0)
        edges.append(bottomNode)

        // Left
        let left = SCNBox(width: thickness, height: height + 0.04, length: thickness, chamferRadius: 0)
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(-Float(width) / 2.0 - 0.01, 0, 0)
        edges.append(leftNode)

        // Right
        let right = SCNBox(width: thickness, height: height + 0.04, length: thickness, chamferRadius: 0)
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(Float(width) / 2.0 + 0.01, 0, 0)
        edges.append(rightNode)

        return edges
    }
}
