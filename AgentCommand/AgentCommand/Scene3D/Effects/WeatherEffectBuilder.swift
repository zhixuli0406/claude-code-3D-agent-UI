import SceneKit

/// Builds weather particle effects tied to task success rate
struct WeatherEffectBuilder {

    enum Weather {
        case sunny
        case cloudy
        case rainy
        case stormy
    }

    /// Determine weather based on recent task success rate (0.0 = all failures, 1.0 = all successes)
    static func weatherForSuccessRate(_ rate: Double) -> Weather {
        if rate >= 0.8 { return .sunny }
        if rate >= 0.5 { return .cloudy }
        if rate >= 0.3 { return .rainy }
        return .stormy
    }

    /// Build weather effect nodes for the given weather type
    static func buildWeather(_ weather: Weather, dimensions: RoomDimensions) -> SCNNode {
        let container = SCNNode()
        container.name = "weatherEffect"

        switch weather {
        case .sunny:
            buildSunshineEffect(in: container, dimensions: dimensions)
        case .cloudy:
            buildCloudEffect(in: container, dimensions: dimensions)
        case .rainy:
            buildRainEffect(in: container, dimensions: dimensions)
        case .stormy:
            buildStormEffect(in: container, dimensions: dimensions)
        }

        return container
    }

    // MARK: - Sunshine

    private static func buildSunshineEffect(in container: SCNNode, dimensions: RoomDimensions) {
        // Warm golden light rays
        for _ in 0..<6 {
            let ray = SCNBox(width: 0.02, height: CGFloat(dimensions.depth), length: 0.02, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: "#FFD54F").withAlphaComponent(0.15)
            mat.emission.contents = NSColor(hex: "#FFD54F")
            mat.emission.intensity = 0.3
            ray.materials = [mat]

            let node = SCNNode(geometry: ray)
            node.position = SCNVector3(
                Float.random(in: -dimensions.width/2...dimensions.width/2),
                dimensions.height - 0.5,
                Float.random(in: 0...dimensions.depth)
            )
            node.eulerAngles.x = .pi / 2
            node.eulerAngles.z = CGFloat.random(in: -0.2...0.2)

            // Gentle shimmer
            let shimmerUp = SCNAction.fadeOpacity(to: 0.8, duration: Double.random(in: 2.0...4.0))
            shimmerUp.timingMode = .easeInEaseOut
            let shimmerDown = SCNAction.fadeOpacity(to: 0.3, duration: Double.random(in: 2.0...4.0))
            shimmerDown.timingMode = .easeInEaseOut
            node.opacity = 0.5
            node.runAction(.repeatForever(.sequence([shimmerUp, shimmerDown])))

            container.addChildNode(node)
        }
    }

    // MARK: - Clouds

    private static func buildCloudEffect(in container: SCNNode, dimensions: RoomDimensions) {
        for _ in 0..<4 {
            let cloud = buildCloud()
            cloud.position = SCNVector3(
                Float.random(in: -dimensions.width/2...dimensions.width/2),
                dimensions.height - 1.0,
                Float.random(in: 0...dimensions.depth * 0.7)
            )

            // Slow drift
            let driftDistance = CGFloat(Float.random(in: 2.0...4.0))
            let driftDuration = Double.random(in: 10.0...20.0)
            let driftRight = SCNAction.moveBy(x: driftDistance, y: 0, z: 0, duration: driftDuration)
            driftRight.timingMode = .easeInEaseOut
            let driftLeft = SCNAction.moveBy(x: -driftDistance, y: 0, z: 0, duration: driftDuration)
            driftLeft.timingMode = .easeInEaseOut
            cloud.runAction(.repeatForever(.sequence([driftRight, driftLeft])))

            container.addChildNode(cloud)
        }
    }

    private static func buildCloud() -> SCNNode {
        let cloud = SCNNode()
        let gray = NSColor(hex: "#B0BEC5").withAlphaComponent(0.4)
        let mat = SCNMaterial()
        mat.diffuse.contents = gray
        mat.emission.contents = gray
        mat.emission.intensity = 0.2

        for _ in 0..<5 {
            let puff = SCNSphere(radius: CGFloat.random(in: 0.3...0.6))
            puff.materials = [mat]
            let puffNode = SCNNode(geometry: puff)
            puffNode.position = SCNVector3(
                Float.random(in: -0.5...0.5),
                Float.random(in: -0.1...0.1),
                Float.random(in: -0.3...0.3)
            )
            cloud.addChildNode(puffNode)
        }

        return cloud
    }

    // MARK: - Rain

    private static func buildRainEffect(in container: SCNNode, dimensions: RoomDimensions) {
        // Add clouds first
        buildCloudEffect(in: container, dimensions: dimensions)

        // Rain drops spawn continuously
        let spawnRain = SCNAction.run { [dimensions] node in
            let drop = SCNBox(width: 0.01, height: 0.08, length: 0.01, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: "#90CAF9").withAlphaComponent(0.6)
            mat.emission.contents = NSColor(hex: "#42A5F5")
            mat.emission.intensity = 0.3
            drop.materials = [mat]

            let dropNode = SCNNode(geometry: drop)
            dropNode.position = SCNVector3(
                Float.random(in: -dimensions.width/2...dimensions.width/2),
                dimensions.height - 0.5,
                Float.random(in: -1...dimensions.depth)
            )

            let fallDuration = Double.random(in: 0.5...1.0)
            let fall = SCNAction.moveBy(x: 0, y: CGFloat(-dimensions.height), z: 0, duration: fallDuration)
            fall.timingMode = .linear

            dropNode.runAction(.sequence([fall, .removeFromParentNode()]))
            node.addChildNode(dropNode)
        }

        container.runAction(.repeatForever(.sequence([
            spawnRain,
            .wait(duration: 0.03)
        ])), forKey: "rainSpawn")
    }

    // MARK: - Storm

    private static func buildStormEffect(in container: SCNNode, dimensions: RoomDimensions) {
        // Heavy rain
        buildRainEffect(in: container, dimensions: dimensions)

        // Lightning flashes
        let flash = SCNAction.run { [dimensions] node in
            let flashLight = SCNNode()
            let light = SCNLight()
            light.type = .omni
            light.color = NSColor.white
            light.intensity = 2000
            flashLight.light = light
            flashLight.position = SCNVector3(
                Float.random(in: -dimensions.width/4...dimensions.width/4),
                dimensions.height - 0.5,
                Float.random(in: 0...dimensions.depth * 0.5)
            )

            flashLight.runAction(.sequence([
                .wait(duration: 0.05),
                SCNAction.run { n in n.light?.intensity = 500 },
                .wait(duration: 0.1),
                SCNAction.run { n in n.light?.intensity = 1500 },
                .wait(duration: 0.05),
                .fadeOut(duration: 0.3),
                .removeFromParentNode()
            ]))

            node.addChildNode(flashLight)
        }

        container.runAction(.repeatForever(.sequence([
            .wait(duration: Double.random(in: 3.0...8.0)),
            flash
        ])), forKey: "stormFlash")
    }
}
