import Foundation

/// Lightweight metadata for a recorded session, stored in the index
struct SessionSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let theme: String
    var taskCount: Int
    var agentCount: Int
    var eventCount: Int
    var primaryTaskTitle: String?
    var isComplete: Bool

    var filename: String { "session-\(id.uuidString).json" }

    var duration: TimeInterval? {
        guard let ended = endedAt else { return nil }
        return ended.timeIntervalSince(startedAt)
    }
}

/// Full session data for persistence and replay
struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let theme: String

    var agents: [Agent]
    var tasks: [AgentTask]
    var timelineEvents: [TimelineEvent]
    var cliOutputs: [String: [CLIOutputEntry]]  // taskId string -> entries (UUID keys not directly Codable as dict keys)

    var sceneConfig: SceneConfiguration?

    /// Store CLI outputs keyed by UUID
    mutating func setCLIOutputs(_ outputs: [UUID: [CLIOutputEntry]]) {
        cliOutputs = Dictionary(uniqueKeysWithValues: outputs.map { (key, value) in
            (key.uuidString, value)
        })
    }

    /// Retrieve CLI outputs keyed by UUID
    func getCLIOutputs() -> [UUID: [CLIOutputEntry]] {
        Dictionary(uniqueKeysWithValues: cliOutputs.compactMap { (key, value) in
            guard let uuid = UUID(uuidString: key) else { return nil }
            return (uuid, value)
        })
    }
}

/// Transient search result (not persisted)
struct SessionSearchResult: Identifiable {
    let id: UUID = UUID()
    let sessionSummary: SessionSummary
    let matchingEvents: [TimelineEvent]
    let matchContext: String
}
