import SceneKit

struct LightingSetup {
    static func apply(to scene: SCNScene, intensity: Float, palette: ThemeColorPalette = .commandCenter) {
        let accentColor = NSColor(hex: palette.accentColor)
        let ambientColor = NSColor(hex: palette.backgroundColor).blended(withFraction: 0.5, of: .white) ?? NSColor(white: 0.3, alpha: 1.0)

        // Ambient light - soft fill
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = ambientColor
        ambientLight.intensity = CGFloat(intensity * 0.3)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)

        // Main overhead spotlight
        let mainSpot = SCNLight()
        mainSpot.type = .spot
        mainSpot.color = NSColor.white
        mainSpot.intensity = CGFloat(intensity)
        mainSpot.spotInnerAngle = 30
        mainSpot.spotOuterAngle = 60
        mainSpot.castsShadow = true
        mainSpot.shadowRadius = 3
        mainSpot.shadowSampleCount = 8
        let mainSpotNode = SCNNode()
        mainSpotNode.light = mainSpot
        mainSpotNode.position = SCNVector3(0, 6, 0)
        mainSpotNode.look(at: SCNVector3(0, 0, -2))
        mainSpotNode.name = "mainSpotLight"
        scene.rootNode.addChildNode(mainSpotNode)

        // Left accent light
        let leftSpot = SCNLight()
        leftSpot.type = .spot
        leftSpot.color = accentColor
        leftSpot.intensity = CGFloat(intensity * 0.4)
        leftSpot.spotInnerAngle = 40
        leftSpot.spotOuterAngle = 70
        leftSpot.castsShadow = false
        let leftSpotNode = SCNNode()
        leftSpotNode.light = leftSpot
        leftSpotNode.position = SCNVector3(-6, 5, 3)
        leftSpotNode.look(at: SCNVector3(-4, 0, 3))
        leftSpotNode.name = "leftSpotLight"
        scene.rootNode.addChildNode(leftSpotNode)

        // Right accent light
        let rightSpot = SCNLight()
        rightSpot.type = .spot
        rightSpot.color = accentColor
        rightSpot.intensity = CGFloat(intensity * 0.4)
        rightSpot.spotInnerAngle = 40
        rightSpot.spotOuterAngle = 70
        rightSpot.castsShadow = false
        let rightSpotNode = SCNNode()
        rightSpotNode.light = rightSpot
        rightSpotNode.position = SCNVector3(6, 5, 3)
        rightSpotNode.look(at: SCNVector3(4, 0, 3))
        rightSpotNode.name = "rightSpotLight"
        scene.rootNode.addChildNode(rightSpotNode)
    }
}
