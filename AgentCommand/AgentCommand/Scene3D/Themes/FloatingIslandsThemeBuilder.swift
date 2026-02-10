import SceneKit
import SpriteKit

struct FloatingIslandsThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .floatingIslands
    let palette: ThemeColorPalette = .floatingIslands

    // MARK: - Environment

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        let env = SCNNode()
        env.name = "floatingIslands_environment"

        // Main island (grass + dirt + stone layers)
        let mainIsland = buildIsland(width: 4.0, depth: 3.0, grassHeight: 0.3, dirtHeight: 0.5, stoneHeight: 0.4)
        mainIsland.position = SCNVector3(0, -0.6, 0)
        mainIsland.name = "mainIsland"
        env.addChildNode(mainIsland)

        // Workstation islands
        let positions: [(Float, Float, Float)] = [
            (-4.0, -0.8, 2.0),
            (4.0, -0.8, 2.0),
            (-4.0, -1.0, 5.0),
            (4.0, -1.0, 5.0)
        ]
        for (i, pos) in positions.enumerated() {
            let island = buildIsland(width: 2.5, depth: 2.0, grassHeight: 0.25, dirtHeight: 0.4, stoneHeight: 0.3)
            island.position = SCNVector3(pos.0, pos.1, pos.2)
            island.name = "workIsland_\(i)"
            addFloatingAnimation(to: island, delay: Double(i) * 0.5)
            env.addChildNode(island)
        }

        // Bridges between main island and workstation islands
        for pos in positions {
            let bridge = buildBridge(
                from: SCNVector3(0, -0.3, 0),
                to: SCNVector3(pos.0, pos.1 + 0.3, pos.2)
            )
            env.addChildNode(bridge)
        }

        addFloatingAnimation(to: mainIsland, delay: 0)

        return env
    }

    // MARK: - Workstation

    func buildWorkstation(size: DeskSize) -> SCNNode {
        let stump = SCNNode()
        stump.name = "treeStump"

        let w = CGFloat(size.width) * 0.4
        let trunkHeight: CGFloat = 0.6

        // Tree stump trunk
        let trunk = SCNCylinder(radius: w * 0.5, height: trunkHeight)
        let trunkMaterial = SCNMaterial()
        trunkMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        trunkMaterial.roughness.contents = 0.9
        trunk.materials = [trunkMaterial]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkHeight) / 2.0, 0)
        stump.addChildNode(trunkNode)

        // Flat top surface (table top)
        let top = SCNCylinder(radius: w * 0.6, height: 0.05)
        let topMaterial = SCNMaterial()
        topMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor).blended(withFraction: 0.2, of: .white)
            ?? NSColor(hex: palette.surfaceColor)
        topMaterial.roughness.contents = 0.8
        top.materials = [topMaterial]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, Float(trunkHeight) + 0.025, 0)
        stump.addChildNode(topNode)

        return stump
    }

    // MARK: - Seating

    func buildSeating() -> SCNNode {
        let seat = SCNNode()
        seat.name = "stoneSeat"

        // Flat stone seat
        let stone = SCNBox(width: 0.5, height: 0.3, length: 0.5, chamferRadius: 0.05)
        let stoneMaterial = SCNMaterial()
        stoneMaterial.diffuse.contents = NSColor(hex: "#808080")
        stoneMaterial.roughness.contents = 0.95
        stone.materials = [stoneMaterial]
        let stoneNode = SCNNode(geometry: stone)
        stoneNode.position = SCNVector3(0, 0.15, 0)
        seat.addChildNode(stoneNode)

        return seat
    }

    // MARK: - Display

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        let display = SCNNode()
        display.name = "scrollDisplay"

        // Floating parchment scroll
        let scroll = SCNBox(width: width, height: height, length: 0.01, chamferRadius: 0.01)
        let scrollMaterial = SCNMaterial()
        let skScene = MonitorBuilder.createScreenContent(
            width: 512, height: 320, accentColor: palette.accentColor
        )
        skScene.backgroundColor = NSColor(hex: "#F5DEB3")

        // Override header color for parchment style
        if let header = skScene.childNode(withName: "//SKLabelNode") as? SKLabelNode {
            header.fontColor = NSColor(hex: "#4A2800")
        }

        scrollMaterial.diffuse.contents = skScene
        scrollMaterial.emission.contents = skScene
        scrollMaterial.emission.intensity = 0.2
        scrollMaterial.transparency = 0.9
        scroll.materials = [scrollMaterial]
        let scrollNode = SCNNode(geometry: scroll)
        scrollNode.position = SCNVector3(0, Float(height) / 2.0, 0)
        scrollNode.name = "screen"
        display.addChildNode(scrollNode)

        // Scroll roll on top
        let roll = SCNCylinder(radius: 0.02, height: width + 0.04)
        let rollMaterial = SCNMaterial()
        rollMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        roll.materials = [rollMaterial]
        let topRoll = SCNNode(geometry: roll)
        topRoll.eulerAngles.z = CGFloat.pi / 2
        topRoll.position = SCNVector3(0, Float(height), 0)
        display.addChildNode(topRoll)

        // Gentle floating animation
        let hover = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 1.5),
                SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 1.5)
            ])
        )
        display.runAction(hover)

        return display
    }

    // MARK: - Lighting

    func applyLighting(to scene: SCNScene, intensity: Float) {
        // Warm sunlight
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.color = NSColor(hex: "#FFF8E1")
        sunLight.intensity = CGFloat(intensity * 1.2)
        sunLight.castsShadow = true
        sunLight.shadowRadius = 4
        sunLight.shadowSampleCount = 8
        let sunNode = SCNNode()
        sunNode.light = sunLight
        sunNode.position = SCNVector3(5, 10, 5)
        sunNode.look(at: SCNVector3(0, 0, 0))
        sunNode.name = "sunLight"
        scene.rootNode.addChildNode(sunNode)

        // Bright ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(hex: "#B3E5FC")
        ambient.intensity = CGFloat(intensity * 0.5)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Fill light from below (sky reflection)
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.color = NSColor(hex: "#87CEEB")
        fillLight.intensity = CGFloat(intensity * 0.2)
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(0, -3, 0)
        fillNode.name = "fillLight"
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Decorations

    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? {
        let decorations = SCNNode()
        decorations.name = "decorations"

        // Clouds
        let cloudPositions: [(Float, Float, Float)] = [
            (-6, 4, -3), (5, 5, -1), (-3, 6, 4),
            (7, 3.5, 6), (-8, 5, 7), (2, 7, -4),
            (8, 4.5, 2), (-5, 6, 0)
        ]
        for (i, pos) in cloudPositions.enumerated() {
            let cloud = buildCloud()
            cloud.position = SCNVector3(pos.0, pos.1, pos.2)

            let driftSpeed = Double.random(in: 15...25)
            let driftDistance = Float.random(in: 2...4)
            let drift = SCNAction.repeatForever(
                SCNAction.sequence([
                    SCNAction.moveBy(x: CGFloat(driftDistance), y: 0, z: 0, duration: driftSpeed),
                    SCNAction.moveBy(x: CGFloat(-driftDistance), y: 0, z: 0, duration: driftSpeed)
                ])
            )
            cloud.runAction(drift)
            cloud.name = "cloud_\(i)"
            decorations.addChildNode(cloud)
        }

        // Small trees on main island
        let treePositions: [(Float, Float)] = [(-1.5, -0.5), (1.5, -0.8), (-1.0, 1.0)]
        for (i, pos) in treePositions.enumerated() {
            let tree = buildBlockTree()
            tree.position = SCNVector3(pos.0, 0, pos.1)
            tree.name = "tree_\(i)"
            decorations.addChildNode(tree)
        }

        // Grass tufts
        for _ in 0..<12 {
            let grass = buildGrassTuft()
            grass.position = SCNVector3(
                Float.random(in: -1.8...1.8),
                0.01,
                Float.random(in: -1.2...1.2)
            )
            decorations.addChildNode(grass)
        }

        return decorations
    }

    func cameraConfigOverride() -> CameraConfig? {
        CameraConfig(
            position: ScenePosition(x: 0, y: 10, z: 16, rotation: 0),
            lookAtTarget: ScenePosition(x: 0, y: 0, z: 2, rotation: 0),
            fieldOfView: 55
        )
    }

    // MARK: - Private Helpers

    private func buildIsland(width: CGFloat, depth: CGFloat, grassHeight: CGFloat, dirtHeight: CGFloat, stoneHeight: CGFloat) -> SCNNode {
        let island = SCNNode()

        // Grass layer (top)
        let grass = SCNBox(width: width, height: grassHeight, length: depth, chamferRadius: 0.05)
        let grassMaterial = SCNMaterial()
        grassMaterial.diffuse.contents = NSColor(hex: "#4CAF50")
        grassMaterial.roughness.contents = 0.9
        grass.materials = [grassMaterial]
        let grassNode = SCNNode(geometry: grass)
        grassNode.position = SCNVector3(0, 0, 0)
        island.addChildNode(grassNode)

        // Dirt layer (middle)
        let dirt = SCNBox(width: width * 0.95, height: dirtHeight, length: depth * 0.95, chamferRadius: 0.03)
        let dirtMaterial = SCNMaterial()
        dirtMaterial.diffuse.contents = NSColor(hex: "#8B4513")
        dirtMaterial.roughness.contents = 0.95
        dirt.materials = [dirtMaterial]
        let dirtNode = SCNNode(geometry: dirt)
        dirtNode.position = SCNVector3(0, -Float(grassHeight / 2 + dirtHeight / 2), 0)
        island.addChildNode(dirtNode)

        // Stone layer (bottom) - slightly narrower for natural look
        let stone = SCNBox(width: width * 0.85, height: stoneHeight, length: depth * 0.85, chamferRadius: 0.08)
        let stoneMaterial = SCNMaterial()
        stoneMaterial.diffuse.contents = NSColor(hex: "#696969")
        stoneMaterial.roughness.contents = 0.9
        stone.materials = [stoneMaterial]
        let stoneNode = SCNNode(geometry: stone)
        stoneNode.position = SCNVector3(0, -Float(grassHeight / 2 + dirtHeight + stoneHeight / 2), 0)
        island.addChildNode(stoneNode)

        return island
    }

    private func buildBridge(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let bridge = SCNNode()
        bridge.name = "bridge"

        let direction = to - from
        let distance = direction.length
        let normalized = direction.normalized
        let plankCount = max(8, Int(distance / 0.3))

        let plankMaterial = SCNMaterial()
        plankMaterial.diffuse.contents = NSColor(hex: "#8B6914")
        plankMaterial.roughness.contents = 0.9

        let ropeMaterial = SCNMaterial()
        ropeMaterial.diffuse.contents = NSColor(hex: "#6B4226")

        for i in 0..<plankCount {
            let t = Float(i) / Float(plankCount - 1)
            let pos = from + normalized * (t * distance)

            // Plank
            let plank = SCNBox(width: 0.3, height: 0.03, length: 0.12, chamferRadius: 0)
            plank.materials = [plankMaterial]
            let plankNode = SCNNode(geometry: plank)

            // Sag curve
            let sag = CGFloat(sin(Float.pi * t) * 0.3)
            plankNode.position = SCNVector3(pos.x, pos.y - sag, pos.z)
            plankNode.look(at: to)
            bridge.addChildNode(plankNode)
        }

        // Rope on left side
        for side: CGFloat in [-0.15, 0.15] {
            for i in 0..<(plankCount - 1) {
                let t0 = Float(i) / Float(plankCount - 1)
                let t1 = Float(i + 1) / Float(plankCount - 1)
                let p0 = from + normalized * (t0 * distance)
                let p1 = from + normalized * (t1 * distance)
                let sag0 = CGFloat(sin(Float.pi * t0) * 0.3)
                let sag1 = CGFloat(sin(Float.pi * t1) * 0.3)

                let ropeLen = CGFloat(0.3 / Float(plankCount - 1) * distance)
                let rope = SCNCylinder(radius: 0.01, height: max(0.05, ropeLen))
                rope.materials = [ropeMaterial]
                let ropeNode = SCNNode(geometry: rope)
                let rx = (p0.x + p1.x) / 2 + side
                let ry = ((p0.y - sag0) + (p1.y - sag1)) / 2
                let rz = (p0.z + p1.z) / 2
                ropeNode.position = SCNVector3(rx, ry, rz)
                bridge.addChildNode(ropeNode)
            }
        }

        return bridge
    }

    private func buildCloud() -> SCNNode {
        let cloud = SCNNode()
        let cloudMaterial = SCNMaterial()
        cloudMaterial.diffuse.contents = NSColor.white
        cloudMaterial.transparency = 0.7

        let sphereCount = Int.random(in: 3...5)
        for _ in 0..<sphereCount {
            let radius = CGFloat.random(in: 0.3...0.6)
            let sphere = SCNSphere(radius: radius)
            sphere.materials = [cloudMaterial]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(
                CGFloat.random(in: -0.4...0.4),
                CGFloat.random(in: -0.1...0.1),
                CGFloat.random(in: -0.3...0.3)
            )
            cloud.addChildNode(node)
        }

        return cloud
    }

    private func buildBlockTree() -> SCNNode {
        let tree = SCNNode()

        // Trunk
        let trunk = SCNBox(width: 0.15, height: 0.6, length: 0.15, chamferRadius: 0)
        let trunkMaterial = SCNMaterial()
        trunkMaterial.diffuse.contents = NSColor(hex: "#6D4C41")
        trunk.materials = [trunkMaterial]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 0.3, 0)
        tree.addChildNode(trunkNode)

        // Canopy (block style)
        let canopy = SCNBox(width: 0.5, height: 0.4, length: 0.5, chamferRadius: 0)
        let canopyMaterial = SCNMaterial()
        canopyMaterial.diffuse.contents = NSColor(hex: "#2E7D32")
        canopy.materials = [canopyMaterial]
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.position = SCNVector3(0, 0.7, 0)
        tree.addChildNode(canopyNode)

        // Top canopy block
        let topCanopy = SCNBox(width: 0.35, height: 0.25, length: 0.35, chamferRadius: 0)
        topCanopy.materials = [canopyMaterial]
        let topNode = SCNNode(geometry: topCanopy)
        topNode.position = SCNVector3(0, 1.0, 0)
        tree.addChildNode(topNode)

        return tree
    }

    private func buildGrassTuft() -> SCNNode {
        let tuft = SCNNode()
        let grassMaterial = SCNMaterial()
        grassMaterial.diffuse.contents = NSColor(hex: "#66BB6A")
        grassMaterial.isDoubleSided = true

        for _ in 0..<3 {
            let blade = SCNBox(width: 0.02, height: 0.1, length: 0.005, chamferRadius: 0)
            blade.materials = [grassMaterial]
            let bladeNode = SCNNode(geometry: blade)
            bladeNode.position = SCNVector3(
                CGFloat.random(in: -0.03...0.03),
                0.05,
                CGFloat.random(in: -0.03...0.03)
            )
            bladeNode.eulerAngles.z = CGFloat.random(in: -0.2...0.2)
            tuft.addChildNode(bladeNode)
        }

        return tuft
    }

    private func addFloatingAnimation(to node: SCNNode, delay: Double) {
        let amplitude = CGFloat.random(in: 0.05...0.12)
        let duration = Double.random(in: 2.5...4.0)
        let floatAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: amplitude, z: 0, duration: duration),
                SCNAction.moveBy(x: 0, y: -amplitude, z: 0, duration: duration)
            ])
        )
        let delayed = SCNAction.sequence([
            SCNAction.wait(duration: delay),
            floatAction
        ])
        node.runAction(delayed)
    }
}
