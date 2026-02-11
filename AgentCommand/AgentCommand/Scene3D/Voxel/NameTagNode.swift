import SceneKit

/// Builds a floating name tag with optional title displayed above the agent
enum NameTagNode {

    static func build(agentName: String, title: String?) -> SCNNode {
        let node = SCNNode()
        node.name = "nameTag"

        // Build display text
        let displayText: String
        if let title = title {
            displayText = "[\(title)] \(agentName)"
        } else {
            displayText = agentName
        }

        // Text node
        let text = SCNText(string: displayText, extrusionDepth: 0.005)
        text.font = NSFont.systemFont(ofSize: 0.08, weight: .medium)
        text.flatness = 0.1

        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = NSColor.white
        textMaterial.emission.contents = NSColor.white
        textMaterial.emission.intensity = 0.3
        text.materials = [textMaterial]

        let textNode = SCNNode(geometry: text)

        // Center text
        let (min, max) = textNode.boundingBox
        let textWidth = max.x - min.x
        let textHeight = max.y - min.y
        textNode.position = SCNVector3(-textWidth / 2, -textHeight / 2, 0)

        // Background panel
        let padding: CGFloat = 0.04
        let bgWidth = CGFloat(textWidth) + padding * 2
        let bgHeight = CGFloat(textHeight) + padding * 2

        let bgMaterial = SCNMaterial()
        bgMaterial.diffuse.contents = NSColor.black.withAlphaComponent(0.6)
        bgMaterial.isDoubleSided = true

        let bg = SCNBox(width: bgWidth, height: bgHeight, length: 0.004, chamferRadius: 0.01)
        bg.materials = [bgMaterial]
        let bgNode = SCNNode(geometry: bg)
        bgNode.position = SCNVector3(0, 0, -0.003)
        node.addChildNode(bgNode)
        node.addChildNode(textNode)

        // Title color accent (left bar)
        if title != nil {
            let accentMaterial = SCNMaterial()
            accentMaterial.diffuse.contents = NSColor(hex: "#FFD700")
            accentMaterial.emission.contents = NSColor(hex: "#FFD700")
            accentMaterial.emission.intensity = 0.5

            let accent = SCNBox(width: 0.01, height: bgHeight, length: 0.005, chamferRadius: 0)
            accent.materials = [accentMaterial]
            let accentNode = SCNNode(geometry: accent)
            accentNode.position = SCNVector3(-Float(bgWidth) / 2 - 0.008, 0, 0)
            node.addChildNode(accentNode)
        }

        // Billboard constraint - always face camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        node.constraints = [billboard]

        // Position above the character
        node.position = SCNVector3(0, 2.0, 0)

        return node
    }
}
