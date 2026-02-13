import SceneKit

/// State machine that drives character animations based on AgentStatus
class AgentAnimationController {
    private weak var characterNode: VoxelCharacterNode?
    private var currentStatus: AgentStatus = .idle
    private var idleStartTime: Date?
    private var sleepTimer: Timer?
    private var isSleeping = false
    private var consecutiveErrors: Int = 0

    /// How long (seconds) before idle transitions to sleeping
    private let sleepAfterIdleSeconds: TimeInterval = 60

    init(characterNode: VoxelCharacterNode) {
        self.characterNode = characterNode
    }

    deinit {
        sleepTimer?.invalidate()
    }

    func transitionTo(_ newStatus: AgentStatus) {
        guard let character = characterNode else { return }

        // Track consecutive errors for frustration animation
        if newStatus == .error {
            consecutiveErrors += 1
        } else if newStatus != .idle {
            consecutiveErrors = 0
        }

        // Cancel sleep timer when leaving idle
        if currentStatus == .idle || isSleeping {
            sleepTimer?.invalidate()
            sleepTimer = nil
            if isSleeping {
                SleepingAnimation.remove(from: character)
                isSleeping = false
            }
        }

        // Remove current animation
        removeCurrentAnimation(from: character)

        // Reset body part rotations smoothly
        resetPose(character, then: {
            // Apply new animation
            switch newStatus {
            case .idle:
                IdleAnimation.apply(to: character)
                self.startSleepTimer()
            case .working:
                WorkingAnimation.apply(to: character)
            case .thinking:
                ThinkingAnimation.apply(to: character)
            case .completed:
                CompletedAnimation.apply(to: character)
                let sparkles = ParticleEffectBuilder.buildCompletionSparkles()
                sparkles.position = SCNVector3(0, 1.0, 0)
                character.addChildNode(sparkles)
            case .error:
                ErrorAnimation.apply(to: character)
                let smoke = ParticleEffectBuilder.buildErrorSmoke()
                smoke.position = SCNVector3(0, 1.2, 0)
                character.addChildNode(smoke)
            case .requestingPermission:
                RequestingPermissionAnimation.apply(to: character)
            case .waitingForAnswer:
                WaitingForAnswerAnimation.apply(to: character)
            case .reviewingPlan:
                ReviewingPlanAnimation.apply(to: character)
            case .suspended:
                WaitingForAnswerAnimation.apply(to: character)
            }

            // Update status indicator color
            character.updateStatusColor(newStatus)
        })

        currentStatus = newStatus
    }

    /// Play a one-shot waving animation (for new agents joining)
    func playWaveAnimation(completion: (() -> Void)? = nil) {
        guard let character = characterNode else { return }
        removeCurrentAnimation(from: character)
        WavingAnimation.apply(to: character) { [weak self] in
            // After waving, return to current status animation
            if let self = self, let char = self.characterNode {
                self.applyCurrentAnimation(to: char)
            }
            completion?()
        }
    }

    private func applyCurrentAnimation(to character: VoxelCharacterNode) {
        switch currentStatus {
        case .idle: IdleAnimation.apply(to: character)
        case .working: WorkingAnimation.apply(to: character)
        case .thinking: ThinkingAnimation.apply(to: character)
        case .completed: CompletedAnimation.apply(to: character)
        case .error: ErrorAnimation.apply(to: character)
        case .requestingPermission: RequestingPermissionAnimation.apply(to: character)
        case .waitingForAnswer: WaitingForAnswerAnimation.apply(to: character)
        case .reviewingPlan: ReviewingPlanAnimation.apply(to: character)
        case .suspended: WaitingForAnswerAnimation.apply(to: character)
        }
    }

    // MARK: - Sleep Timer

    private func startSleepTimer() {
        idleStartTime = Date()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: sleepAfterIdleSeconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.transitionToSleeping()
            }
        }
    }

    private func transitionToSleeping() {
        guard let character = characterNode, currentStatus == .idle else { return }

        // Remove idle animation and apply sleeping
        IdleAnimation.remove(from: character)
        isSleeping = true

        resetPose(character) {
            SleepingAnimation.apply(to: character)
        }
    }

    // MARK: - Animation Removal

    private func removeCurrentAnimation(from character: VoxelCharacterNode) {
        if isSleeping {
            SleepingAnimation.remove(from: character)
            isSleeping = false
            return
        }

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
        case .requestingPermission:
            RequestingPermissionAnimation.remove(from: character)
        case .waitingForAnswer:
            WaitingForAnswerAnimation.remove(from: character)
        case .reviewingPlan:
            ReviewingPlanAnimation.remove(from: character)
        case .suspended:
            WaitingForAnswerAnimation.remove(from: character)
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
        character.leftLegNode.eulerAngles = SCNVector3Zero
        character.rightLegNode.eulerAngles = SCNVector3Zero

        SCNTransaction.commit()
    }
}
