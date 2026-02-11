import SceneKit
import AppKit

/// A 3D speech/thought bubble that floats above an agent.
///
/// Uses CoreGraphics-rendered static images as material textures instead of
/// live SpriteKit scenes. This avoids a thread-safety crash where the main
/// thread modifies SKScene content while SceneKit's render thread reads it
/// (EXC_BAD_ACCESS in SKCShapeNode::addRenderOps).
class ChatBubbleNode: SCNNode {

    enum BubbleStyle {
        case speech
        case thought
    }

    private let planeNode: SCNNode
    private let material: SCNMaterial

    // Current state (mutated on main thread, rendered to static image)
    private var currentText: String?
    private var currentStyle: BubbleStyle = .speech
    private var currentIcon: ToolIcon?
    private var isShowingTyping = false
    private var typingDotPhase: Int = 0
    private var typingTimer: Timer?

    private static let texWidth: CGFloat = 320
    private static let texHeight: CGFloat = 100
    private static let maxChars = 60

    override init() {
        let plane = SCNPlane(width: 2.0, height: 0.625)
        material = SCNMaterial()
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

        renderBubble()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        typingTimer?.invalidate()
    }

    // MARK: - Public API

    func updateText(_ text: String, style: BubbleStyle) {
        isShowingTyping = false
        stopTypingTimer()
        currentText = String(text.prefix(Self.maxChars))
        currentStyle = style
        renderBubble()
    }

    func showTypingIndicator() {
        isShowingTyping = true
        currentText = nil
        currentIcon = nil
        currentStyle = .speech
        typingDotPhase = 0
        renderBubble()

        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.typingDotPhase = (self.typingDotPhase + 1) % 4
            self.renderBubble()
        }
    }

    func hideTypingIndicator() {
        isShowingTyping = false
        stopTypingTimer()
        renderBubble()
    }

    func setToolIcon(_ icon: ToolIcon) {
        currentIcon = icon
        renderBubble()
    }

    func clearToolIcon() {
        currentIcon = nil
        renderBubble()
    }

    func animateIn() {
        removeAllActions()
        let scaleUp = SCNAction.scale(to: 1.0, duration: 0.25)
        scaleUp.timingMode = .easeOut
        let fadeIn = SCNAction.fadeIn(duration: 0.2)
        runAction(.group([scaleUp, fadeIn]))
    }

    func animateOut(completion: (() -> Void)? = nil) {
        stopTypingTimer()
        let scaleDown = SCNAction.scale(to: 0.01, duration: 0.2)
        scaleDown.timingMode = .easeIn
        let fadeOut = SCNAction.fadeOut(duration: 0.15)
        let done = SCNAction.run { _ in completion?() }
        runAction(.sequence([.group([scaleDown, fadeOut]), done]))
    }

    // MARK: - Private

    private func stopTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = nil
    }

    /// Render the bubble to a static image and set as material texture.
    /// Thread-safe: SceneKit only reads the finished NSImage, never a live
    /// SpriteKit scene graph that could be mutated concurrently.
    private func renderBubble() {
        let w = Self.texWidth
        let h = Self.texHeight

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(w * 2), pixelsHigh: Int(h * 2),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = NSSize(width: w, height: h)

        guard let gfx = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gfx
        let ctx = gfx.cgContext

        // AppKit coordinate system: origin at bottom-left, y increases upward
        drawBubbleBackground(ctx: ctx, w: w, h: h)

        if isShowingTyping {
            drawTypingDots(ctx: ctx, w: w, h: h)
        } else {
            if let icon = currentIcon {
                drawToolIcon(icon, h: h)
            }
            if let text = currentText {
                drawTextContent(text, w: w, h: h)
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: w, height: h))
        image.addRepresentation(rep)
        material.diffuse.contents = image
    }

    private func drawBubbleBackground(ctx: CGContext, w: CGFloat, h: CGFloat) {
        let rect = CGRect(x: 4, y: 4, width: w - 8, height: h - 8)

        let fillColor: CGColor
        let strokeColor: CGColor
        let cornerRadius: CGFloat

        switch currentStyle {
        case .speech:
            fillColor = CGColor(gray: 0.1, alpha: 0.85)
            strokeColor = CGColor(gray: 0.3, alpha: 0.6)
            cornerRadius = 10
        case .thought:
            fillColor = CGColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 0.85)
            strokeColor = NSColor(hex: "#9C27B0").withAlphaComponent(0.5).cgColor
            cornerRadius = 14
        }

        let path = CGMutablePath()
        path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        ctx.addPath(path)
        ctx.setFillColor(fillColor)
        ctx.fillPath()

        ctx.addPath(path)
        ctx.setStrokeColor(strokeColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
    }

    /// Draw text using NSString.draw (uses current NSGraphicsContext)
    private func drawTextContent(_ text: String, w: CGFloat, h: CGFloat) {
        let hasIcon = currentIcon != nil
        let leftX: CGFloat = hasIcon ? 36 : 16
        let textRect = NSRect(x: leftX, y: (h - 30) / 2, width: w - leftX - 16, height: 30)

        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }

    /// Draw SF Symbol icon using NSImage.draw (uses current NSGraphicsContext)
    private func drawToolIcon(_ icon: ToolIcon, h: CGFloat) {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(hierarchicalColor: .white))
        guard let image = NSImage(systemSymbolName: icon.rawValue, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        let iconSize: CGFloat = 18
        let iconRect = NSRect(x: 10, y: (h - iconSize) / 2, width: iconSize, height: iconSize)
        image.draw(in: iconRect)
    }

    private func drawTypingDots(ctx: CGContext, w: CGFloat, h: CGFloat) {
        let dotRadius: CGFloat = 4
        let centerY = h / 2

        for i in 0..<3 {
            let cx = w / 2 + CGFloat(i - 1) * 14
            let isActive = typingDotPhase == i
            let yShift: CGFloat = isActive ? 6 : 0
            let alpha: CGFloat = isActive ? 1.0 : 0.4

            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
            ctx.fillEllipse(in: CGRect(
                x: cx - dotRadius,
                y: centerY + yShift - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
        }
    }
}
