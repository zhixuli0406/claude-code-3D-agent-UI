import SceneKit

class SceneCoordinator: NSObject, SCNSceneRendererDelegate {
    var onAgentSelected: ((UUID) -> Void)?
    var onAgentDoubleClicked: ((UUID) -> Void)?
    var onAgentRightClicked: ((UUID, CGPoint) -> Void)?
    var onAgentHovered: ((UUID?, CGPoint?) -> Void)?
    var onInteractiveObjectHovered: ((Bool) -> Void)?
    var firstPersonUpdateHandler: (() -> Void)?
    /// Reference to the scene manager for interactive object handling
    weak var sceneManager: ThemeableScene?
    private var lastUpdateTime: TimeInterval = 0
    private var lastHoveredAgentId: UUID?

    init(onAgentSelected: ((UUID) -> Void)?) {
        self.onAgentSelected = onAgentSelected
        super.init()
    }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let deltaTime = time - lastUpdateTime
        lastUpdateTime = time

        // Avoid large deltas on first frame
        guard deltaTime < 1.0 else { return }

        // Track agent in first-person mode
        firstPersonUpdateHandler?()
    }

    /// Handle click to select an agent in the 3D scene
    func handleClick(at point: CGPoint, in view: SCNView) {
        // Check for interactive object click first
        if sceneManager?.handleInteractiveObjectClick(at: point, in: view) == true {
            return
        }

        let hitResults = view.hitTest(point, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: false)
        ])

        for hit in hitResults {
            if let characterNode = hit.node.findParentVoxelCharacter(),
               let agentId = characterNode.agentId {
                onAgentSelected?(agentId)
                return
            }
        }
    }

    /// Handle double-click to zoom camera to an agent
    func handleDoubleClick(at point: CGPoint, in view: SCNView) {
        let hitResults = view.hitTest(point, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: false)
        ])

        for hit in hitResults {
            if let characterNode = hit.node.findParentVoxelCharacter(),
               let agentId = characterNode.agentId {
                onAgentDoubleClicked?(agentId)
                return
            }
        }
    }

    /// Handle right-click to show context menu for an agent
    func handleRightClick(at point: CGPoint, in view: SCNView) -> UUID? {
        let hitResults = view.hitTest(point, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: false)
        ])

        for hit in hitResults {
            if let characterNode = hit.node.findParentVoxelCharacter(),
               let agentId = characterNode.agentId {
                return agentId
            }
        }
        return nil
    }

    /// Handle mouse hover to show tooltip for agents
    func handleHover(at point: CGPoint, in view: SCNView) {
        // Check interactive object hover
        let isOverInteractive = sceneManager?.handleInteractiveObjectHover(at: point, in: view) ?? false
        onInteractiveObjectHovered?(isOverInteractive)

        let hitResults = view.hitTest(point, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: true)
        ])

        for hit in hitResults {
            if let characterNode = hit.node.findParentVoxelCharacter(),
               let agentId = characterNode.agentId {
                // Project the character's head position to 2D screen coords
                let worldPos = characterNode.worldPosition
                let headPos = SCNVector3(worldPos.x, worldPos.y + 2.2, worldPos.z)
                let projected = view.projectPoint(headPos)
                // SceneKit origin is bottom-left, SwiftUI is top-left: flip Y
                let viewHeight = Float(view.bounds.height)
                let screenPoint = CGPoint(x: CGFloat(projected.x), y: CGFloat(viewHeight - Float(projected.y)))

                if agentId != lastHoveredAgentId {
                    lastHoveredAgentId = agentId
                }
                onAgentHovered?(agentId, screenPoint)
                return
            }
        }

        // No agent hit
        if lastHoveredAgentId != nil {
            lastHoveredAgentId = nil
            onAgentHovered?(nil, nil)
        }
    }

    func clearHover() {
        lastHoveredAgentId = nil
        onAgentHovered?(nil, nil)
    }
}
