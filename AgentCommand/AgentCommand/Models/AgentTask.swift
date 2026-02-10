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
}

struct SubTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
}
