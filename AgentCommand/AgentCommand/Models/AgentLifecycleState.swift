import Foundation

/// Enhanced agent lifecycle states extending the original AgentStatus
/// with explicit initialization, suspension, pooling, and destruction phases.
enum AgentLifecycleState: String, Codable, CaseIterable {

    // === Creation Phase ===
    case initializing      // Agent created, loading resources

    // === Active Phase ===
    case idle              // Ready for task assignment
    case working           // Executing CLI process
    case thinking          // AI model is reasoning

    // === Interaction Phase ===
    case requestingPermission  // Dangerous command needs approval
    case waitingForAnswer      // AskUserQuestion pending
    case reviewingPlan         // Plan mode review pending

    // === Suspended Phase ===
    case suspended         // CLI process terminated; waiting for user resume
    case suspendedIdle     // Task completed/failed; agent awaiting reuse or cleanup

    // === Completion Phase ===
    case completed         // Task finished successfully
    case error             // Task failed with error

    // === Lifecycle Terminal Phase ===
    case pooled            // Returned to pool, available for reuse
    case destroying        // Disband animation in progress
    case destroyed         // Fully removed (terminal state)

    // MARK: - Metadata

    var isTerminal: Bool {
        self == .destroyed
    }

    var isActive: Bool {
        [.working, .thinking, .requestingPermission,
         .waitingForAnswer, .reviewingPlan].contains(self)
    }

    var isAvailableForTask: Bool {
        [.idle, .pooled, .suspendedIdle].contains(self)
    }

    var isCleanupCandidate: Bool {
        [.completed, .error, .suspendedIdle, .idle].contains(self)
    }

    var isSuspended: Bool {
        [.suspended, .suspendedIdle].contains(self)
    }

    var displayName: String {
        switch self {
        case .initializing: return "Initializing"
        case .idle: return "Idle"
        case .working: return "Working"
        case .thinking: return "Thinking"
        case .requestingPermission: return "Requesting Permission"
        case .waitingForAnswer: return "Waiting for Answer"
        case .reviewingPlan: return "Reviewing Plan"
        case .suspended: return "Suspended"
        case .suspendedIdle: return "Suspended (Idle)"
        case .completed: return "Completed"
        case .error: return "Error"
        case .pooled: return "Pooled"
        case .destroying: return "Destroying"
        case .destroyed: return "Destroyed"
        }
    }

    var hexColor: String {
        switch self {
        case .initializing: return "#9E9E9E"
        case .idle: return "#888888"
        case .working: return "#4CAF50"
        case .thinking: return "#FF9800"
        case .requestingPermission: return "#FF9800"
        case .waitingForAnswer: return "#2196F3"
        case .reviewingPlan: return "#9C27B0"
        case .suspended: return "#607D8B"
        case .suspendedIdle: return "#78909C"
        case .completed: return "#2196F3"
        case .error: return "#F44336"
        case .pooled: return "#00BCD4"
        case .destroying: return "#795548"
        case .destroyed: return "#424242"
        }
    }

    /// Map to legacy AgentStatus for backward compatibility
    var legacyStatus: AgentStatus {
        switch self {
        case .initializing, .idle, .pooled, .suspendedIdle:
            return .idle
        case .working:
            return .working
        case .thinking:
            return .thinking
        case .requestingPermission:
            return .requestingPermission
        case .waitingForAnswer:
            return .waitingForAnswer
        case .reviewingPlan:
            return .reviewingPlan
        case .completed:
            return .completed
        case .error:
            return .error
        case .suspended:
            return .waitingForAnswer
        case .destroying, .destroyed:
            return .idle
        }
    }
}
