import Foundation

/// Full application state snapshot for recovery after app restart.
/// Saved periodically and on app termination.
struct AgentStateSnapshot: Codable {
    let savedAt: Date
    let appVersion: String

    // Active agents (not in pool)
    let agents: [Agent]
    let tasks: [AgentTask]

    // Suspended contexts (can be resumed)
    let resumeContexts: [ResumeContext]
}
