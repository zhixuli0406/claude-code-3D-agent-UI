import Foundation

struct AgentTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var status: TaskStatus
    var priority: TaskPriority
    var assignedAgentId: UUID?
    var subtasks: [SubTask]
    var progress: Double
    var createdAt: Date
    var completedAt: Date?
    var estimatedDuration: TimeInterval

    // Team
    var teamAgentIds: [UUID] = []

    // CLI execution fields
    var isRealExecution: Bool = false
    var cliResult: String?
    var outputLogCount: Int = 0
    var sessionId: String?
}

struct SubTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
}
