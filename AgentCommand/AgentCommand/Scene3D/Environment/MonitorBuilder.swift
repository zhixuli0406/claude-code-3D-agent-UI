import SceneKit
import SpriteKit

struct MonitorBuilder {
    static func build(width: CGFloat = 0.6, height: CGFloat = 0.4, palette: ThemeColorPalette = .commandCenter) -> SCNNode {
        let monitor = SCNNode()
        monitor.name = "monitor"

        // Screen
        let screen = SCNBox(width: width, height: height, length: 0.02, chamferRadius: 0.005)
        let screenMaterial = SCNMaterial()
        let skScene = createScreenContent(width: 512, height: 320, accentColor: palette.accentColor)
        screenMaterial.diffuse.contents = skScene
        screenMaterial.emission.contents = skScene
        screenMaterial.emission.intensity = 0.5
        screen.materials = [screenMaterial]
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, Float(height) / 2.0, 0)
        screenNode.name = "screen"
        monitor.addChildNode(screenNode)

        // Bezel
        let bezel = SCNBox(width: width + 0.04, height: height + 0.04, length: 0.015, chamferRadius: 0.005)
        let bezelMaterial = SCNMaterial()
        bezelMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        bezel.materials = [bezelMaterial]
        let bezelNode = SCNNode(geometry: bezel)
        bezelNode.position = SCNVector3(0, Float(height) / 2.0, -0.005)
        monitor.addChildNode(bezelNode)

        // Stand neck
        let neck = SCNCylinder(radius: 0.02, height: 0.1)
        let neckMaterial = SCNMaterial()
        neckMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        neckMaterial.metalness.contents = 0.5
        neck.materials = [neckMaterial]
        let neckNode = SCNNode(geometry: neck)
        neckNode.position = SCNVector3(0, -0.05, 0)
        monitor.addChildNode(neckNode)

        // Stand base
        let base = SCNBox(width: 0.15, height: 0.01, length: 0.1, chamferRadius: 0.005)
        base.materials = [neckMaterial]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, -0.1, 0)
        monitor.addChildNode(baseNode)

        return monitor
    }

    static func createScreenContent(width: CGFloat, height: CGFloat, accentColor: String = "#00BCD4") -> SKScene {
        let skScene = SKScene(size: CGSize(width: width, height: height))
        skScene.backgroundColor = NSColor(hex: "#0D1117")

        let header = SKLabelNode(text: "AGENT COMMAND v1.0")
        header.fontName = "Menlo-Bold"
        header.fontSize = 18
        header.fontColor = NSColor(hex: accentColor)
        header.position = CGPoint(x: width / 2, y: height - 30)
        skScene.addChild(header)

        let statusLine = SKLabelNode(text: "> System Ready")
        statusLine.fontName = "Menlo"
        statusLine.fontSize = 14
        statusLine.fontColor = NSColor(hex: "#4CAF50")
        statusLine.position = CGPoint(x: width / 2, y: height - 60)
        statusLine.name = "statusLine"
        skScene.addChild(statusLine)

        let cursor = SKLabelNode(text: "_")
        cursor.fontName = "Menlo"
        cursor.fontSize = 14
        cursor.fontColor = NSColor(hex: accentColor)
        cursor.position = CGPoint(x: width / 2, y: height - 90)
        let blink = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.fadeIn(withDuration: 0.5)
            ])
        )
        cursor.run(blink)
        skScene.addChild(cursor)

        return skScene
    }

    static func updateScreen(_ screenNode: SCNNode, taskTitle: String, progress: Double, status: String) {
        guard let material = screenNode.geometry?.materials.first,
              let skScene = material.diffuse.contents as? SKScene else { return }

        if let statusLabel = skScene.childNode(withName: "statusLine") as? SKLabelNode {
            statusLabel.text = "> \(status): \(taskTitle)"
            statusLabel.fontColor = progress >= 1.0
                ? NSColor(hex: "#4CAF50")
                : NSColor(hex: "#FF9800")
        }
    }
}
