import Foundation

// MARK: - I4: Multi-Project Workspace Models

struct ProjectWorkspace: Identifiable {
    let id: UUID
    var name: String
    var path: String
    var isActive: Bool
    var activeAgentCount: Int
    var totalTasks: Int
    var completedTasks: Int
    var failedTasks: Int
    var lastActivityAt: Date?
    var iconColor: String

    var successRate: Double {
        let total = completedTasks + failedTasks
        return total > 0 ? Double(completedTasks) / Double(total) : 0
    }
}

struct ProjectComparison: Identifiable {
    let id: UUID
    var projects: [ProjectMetrics]
}

struct ProjectMetrics: Identifiable {
    let id: UUID
    var projectName: String
    var totalTasks: Int
    var completedTasks: Int
    var avgDuration: TimeInterval
    var totalCost: Double
    var tokenUsage: Int
    var agentCount: Int
}

struct CrossProjectTask: Identifiable {
    let id: UUID
    var taskTitle: String
    var projectName: String
    var projectPath: String
    var status: String
    var agentName: String
    var createdAt: Date
}
