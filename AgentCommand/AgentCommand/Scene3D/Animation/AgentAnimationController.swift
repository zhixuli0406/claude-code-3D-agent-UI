import SceneKit

/// State machine that drives character animations based on AgentStatus
class AgentAnimationController {
    private weak var characterNode: VoxelCharacterNode?
    private var currentStatus: AgentStatus = .idle

    init(characterNode: VoxelCharacterNode) {
        self.characterNode = characterNode
    }

    func transitionTo(_ newStatus: AgentStatus) {
        guard let character = characterNode else { return }

        // Remove current animation
        removeCurrentAnimation(from: character)

        // Reset body part rotations smoothly
        resetPose(character, then: {
            // Apply new animation
            switch newStatus {
            case .idle:
                IdleAnimation.apply(to: character)
            case .working:
                WorkingAnimation.apply(to: character)
            case .thinking:
                ThinkingAnimation.apply(to: character)
            case .completed:
                CompletedAnimation.apply(to: character)
            case .error:
                ErrorAnimation.apply(to: character)
            }

            // Update status indicator color
            character.updateStatusColor(newStatus)
        })

        currentStatus = newStatus
    }

    private func removeCurrentAnimation(from character: VoxelCharacterNode) {
        switch currentStatus {
        case .idle:
            IdleAnimation.remove(from: character)
        case .working:
            WorkingAnimation.remove(from: character)
        case .thinking:
            ThinkingAnimation.remove(from: character)
        case .completed:
            CompletedAnimation.remove(from: character)
        case .error:
            ErrorAnimation.remove(from: character)
        }
    }

    private func resetPose(_ character: VoxelCharacterNode, then completion: @escaping () -> Void) {
        let duration = 0.3

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.completionBlock = completion

        character.headNode.eulerAngles = SCNVector3Zero
        character.bodyNode.eulerAngles = SCNVector3Zero
        character.bodyNode.position = character.bodyNode.position  // Keep position
        character.leftArmNode.eulerAngles = SCNVector3Zero
        character.rightArmNode.eulerAngles = SCNVector3Zero

        SCNTransaction.commit()
    }
}
