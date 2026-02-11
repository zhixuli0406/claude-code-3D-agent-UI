import SceneKit
import SpriteKit

/// A 3D speech/thought bubble that floats above an agent
class ChatBubbleNode: SCNNode {

    enum BubbleStyle {
        case speech
        case thought
    }

    private let planeNode: SCNNode
    private let skScene: SKScene
    private let backgroundShape: SKShapeNode
    private let textLabel: SKLabelNode
    private let iconSprite: SKSpriteNode
    private let typingDotsNode: SKNode

    private static let skWidth: CGFloat = 320
    private static let skHeight: CGFloat = 100
    private static let maxChars = 60

    override init() {
        // SpriteKit scene as texture
        skScene = SKScene(size: CGSize(width: Self.skWidth, height: Self.skHeight))
        skScene.backgroundColor = .clear

        // Background
        backgroundShape = SKShapeNode()
        backgroundShape.zPosition = 0
        skScene.addChild(backgroundShape)

        // Text
        textLabel = SKLabelNode(fontNamed: "Menlo")
        textLabel.fontSize = 13
        textLabel.fontColor = .white
        textLabel.preferredMaxLayoutWidth = Self.skWidth - 40
        textLabel.numberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.verticalAlignmentMode = .center
        textLabel.horizontalAlignmentMode = .left
        textLabel.position = CGPoint(x: 36, y: Self.skHeight / 2)
        textLabel.zPosition = 1
        skScene.addChild(textLabel)

        // Icon
        iconSprite = SKSpriteNode()
        iconSprite.size = CGSize(width: 18, height: 18)
        iconSprite.position = CGPoint(x: 18, y: Self.skHeight / 2)
        iconSprite.zPosition = 1
        iconSprite.isHidden = true
        skScene.addChild(iconSprite)

        // Typing dots
        typingDotsNode = SKNode()
        typingDotsNode.position = CGPoint(x: Self.skWidth / 2, y: Self.skHeight / 2)
        typingDotsNode.isHidden = true
        typingDotsNode.zPosition = 1
        for i in 0..<3 {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat(i - 1) * 14, y: 0)
            dot.alpha = 0.4

            let wait = SKAction.wait(forDuration: Double(i) * 0.2)
            let up = SKAction.moveBy(x: 0, y: 6, duration: 0.3)
            up.timingMode = .easeInEaseOut
            let down = SKAction.moveBy(x: 0, y: -6, duration: 0.3)
            down.timingMode = .easeInEaseOut
            let pause = SKAction.wait(forDuration: 0.4)
            dot.run(.repeatForever(.sequence([wait, up, down, pause])))

            typingDotsNode.addChild(dot)
        }
        skScene.addChild(typingDotsNode)

        // SCNPlane with SpriteKit texture
        let plane = SCNPlane(width: 2.0, height: 0.625)
        let material = SCNMaterial()
        material.diffuse.contents = skScene
        material.isDoubleSided = true
        material.lightingModel = .constant
        material.transparency = 0.95
        plane.materials = [material]

        planeNode = SCNNode(geometry: plane)
        planeNode.name = "chatBubblePlane"

        super.init()
        self.name = "chatBubble"
        addChildNode(planeNode)

        // Billboard constraint: always face camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        constraints = [billboard]

        // Start hidden
        opacity = 0
        scale = SCNVector3(0.01, 0.01, 0.01)

        // Draw initial background
        drawBackground(style: .speech)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    func updateText(_ text: String, style: BubbleStyle) {
        typingDotsNode.isHidden = true
        textLabel.isHidden = false

        let trimmed = String(text.prefix(Self.maxChars))
        textLabel.text = trimmed
        drawBackground(style: style)
    }

    func showTypingIndicator() {
        textLabel.isHidden = true
        iconSprite.isHidden = true
        typingDotsNode.isHidden = false
        drawBackground(style: .speech)
    }

    func hideTypingIndicator() {
        typingDotsNode.isHidden = true
    }

    func setToolIcon(_ icon: ToolIcon) {
        if let image = NSImage(systemSymbolName: icon.rawValue, accessibilityDescription: nil) {
            let tinted = image.tinted(with: .white)
            iconSprite.texture = SKTexture(image: tinted)
            iconSprite.isHidden = false
        } else {
            iconSprite.isHidden = true
        }
    }

    func clearToolIcon() {
        iconSprite.isHidden = true
    }

    func animateIn() {
        removeAllActions()
        let scaleUp = SCNAction.scale(to: 1.0, duration: 0.25)
        scaleUp.timingMode = .easeOut
        let fadeIn = SCNAction.fadeIn(duration: 0.2)
        runAction(.group([scaleUp, fadeIn]))
    }

    func animateOut(completion: (() -> Void)? = nil) {
        let scaleDown = SCNAction.scale(to: 0.01, duration: 0.2)
        scaleDown.timingMode = .easeIn
        let fadeOut = SCNAction.fadeOut(duration: 0.15)
        let done = SCNAction.run { _ in completion?() }
        runAction(.sequence([.group([scaleDown, fadeOut]), done]))
    }

    // MARK: - Drawing

    private func drawBackground(style: BubbleStyle) {
        backgroundShape.removeAllChildren()
        let rect = CGRect(x: 4, y: 4, width: Self.skWidth - 8, height: Self.skHeight - 8)

        switch style {
        case .speech:
            let path = CGMutablePath()
            path.addRoundedRect(in: rect, cornerWidth: 10, cornerHeight: 10)
            backgroundShape.path = path
            backgroundShape.fillColor = NSColor(white: 0.1, alpha: 0.85)
            backgroundShape.strokeColor = NSColor(white: 0.3, alpha: 0.6)
            backgroundShape.lineWidth = 1

        case .thought:
            let path = CGMutablePath()
            path.addRoundedRect(in: rect, cornerWidth: 14, cornerHeight: 14)
            backgroundShape.path = path
            backgroundShape.fillColor = NSColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 0.85)
            backgroundShape.strokeColor = NSColor(hex: "#9C27B0").withAlphaComponent(0.5)
            backgroundShape.lineWidth = 1

            // Thought dots below
            for i in 0..<2 {
                let dotRadius: CGFloat = CGFloat(4 - i * 1)
                let dot = SKShapeNode(circleOfRadius: dotRadius)
                dot.fillColor = backgroundShape.fillColor
                dot.strokeColor = backgroundShape.strokeColor
                dot.lineWidth = 1
                dot.position = CGPoint(x: Self.skWidth / 2 - CGFloat(i) * 8, y: -CGFloat(i) * 6 - 2)
                backgroundShape.addChild(dot)
            }
        }
    }
}

// MARK: - NSImage tinting helper

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
