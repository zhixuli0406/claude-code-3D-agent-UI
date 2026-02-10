import SceneKit

class SceneCoordinator: NSObject, SCNSceneRendererDelegate {
    var onAgentSelected: ((UUID) -> Void)?
    private var lastUpdateTime: TimeInterval = 0

    init(onAgentSelected: ((UUID) -> Void)?) {
        self.onAgentSelected = onAgentSelected
        super.init()
    }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let deltaTime = time - lastUpdateTime
        lastUpdateTime = time

        // Avoid large deltas on first frame
        guard deltaTime < 1.0 else { return }
    }

    /// Handle click to select an agent in the 3D scene
    func handleClick(at point: CGPoint, in view: SCNView) {
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
}
