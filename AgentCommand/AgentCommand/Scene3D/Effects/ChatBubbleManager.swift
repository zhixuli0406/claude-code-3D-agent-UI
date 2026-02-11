import SceneKit

/// Manages chat bubbles above agent characters in the 3D scene
class ChatBubbleManager {
    private var bubbles: [UUID: ChatBubbleNode] = [:]
    private weak var scene: SCNScene?
    private var agentNodeProvider: ((UUID) -> VoxelCharacterNode?)?

    /// Throttle: track last update time per agent
    private var lastUpdateTime: [UUID: Date] = [:]
    private let updateInterval: TimeInterval = 0.3

    func setup(scene: SCNScene, agentNodeProvider: @escaping (UUID) -> VoxelCharacterNode?) {
        self.scene = scene
        self.agentNodeProvider = agentNodeProvider
    }

    func updateBubble(agentId: UUID, text: String?, style: ChatBubbleNode.BubbleStyle, toolIcon: ToolIcon?) {
        // Throttle updates
        let now = Date()
        if let lastTime = lastUpdateTime[agentId], now.timeIntervalSince(lastTime) < updateInterval {
            return
        }
        lastUpdateTime[agentId] = now

        guard let text = text, !text.isEmpty else {
            hideBubble(agentId: agentId)
            return
        }

        let bubble = getOrCreateBubble(agentId: agentId)
        bubble.updateText(text, style: style)

        if let icon = toolIcon {
            bubble.setToolIcon(icon)
        } else {
            bubble.clearToolIcon()
        }
    }

    func showTyping(agentId: UUID) {
        let bubble = getOrCreateBubble(agentId: agentId)
        bubble.showTypingIndicator()
    }

    func hideBubble(agentId: UUID) {
        guard let bubble = bubbles[agentId] else { return }
        bubble.animateOut { [weak self] in
            bubble.removeFromParentNode()
            self?.bubbles.removeValue(forKey: agentId)
        }
        lastUpdateTime.removeValue(forKey: agentId)
    }

    func removeAll() {
        for (_, bubble) in bubbles {
            bubble.removeFromParentNode()
        }
        bubbles.removeAll()
        lastUpdateTime.removeAll()
    }

    // MARK: - Private

    private func getOrCreateBubble(agentId: UUID) -> ChatBubbleNode {
        if let existing = bubbles[agentId] {
            return existing
        }

        let bubble = ChatBubbleNode()

        // Position above agent's head
        if let agentNode = agentNodeProvider?(agentId) {
            let headY: CGFloat = 2.5
            bubble.position = SCNVector3(
                agentNode.worldPosition.x,
                agentNode.worldPosition.y + headY,
                agentNode.worldPosition.z
            )
        }

        scene?.rootNode.addChildNode(bubble)
        bubbles[agentId] = bubble
        bubble.animateIn()

        return bubble
    }
}
