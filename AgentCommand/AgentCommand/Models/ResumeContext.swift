import Foundation

/// Complete context needed to resume a suspended agent after app restart
struct ResumeContext: Codable, Identifiable {
    var id: UUID { agentId }

    // Agent identity
    let agentId: UUID
    let agentName: String
    let agentRole: AgentRole
    let agentModel: ClaudeModel
    let agentPersonality: AgentPersonality
    let agentAppearance: VoxelAppearance

    // CLI session
    let sessionId: String
    let workingDirectory: String

    // Task context
    let taskId: UUID
    let taskTitle: String
    let originalPrompt: String

    // Suspension info
    let suspendedAt: Date
    let suspensionReason: SuspensionReason
    let toolCallCount: Int
    let progressEstimate: Double

    // Team context
    let commanderId: UUID?
    let teamAgentIds: [UUID]

    // Orchestration context (if part of auto-decomposition)
    let orchestrationId: UUID?
    let orchestrationTaskIndex: Int?

    // Pending interaction (what user needs to respond to)
    let pendingInteraction: PendingInteraction?
}

enum SuspensionReason: String, Codable {
    case userQuestion       // AskUserQuestion tool
    case planReview         // ExitPlanMode tool
    case permissionDenied   // User denied dangerous command
    case userPaused         // Manual pause
    case appTerminated      // App quit while running
    case processTimeout     // Process exceeded time limit
}

struct PendingInteraction: Codable {
    let type: InteractionType
    let sessionId: String
    let inputJSON: String
    let receivedAt: Date

    enum InteractionType: String, Codable {
        case question
        case planReview
        case permissionRequest
    }
}
