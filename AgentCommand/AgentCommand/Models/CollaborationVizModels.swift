import Foundation

// MARK: - J2: Real-time Collaboration Visualization Models

enum DataFlowDirection: String, CaseIterable {
    case agentToAgent = "agent_to_agent"
    case agentToFile = "agent_to_file"
    case fileToAgent = "file_to_agent"

    var hexColor: String {
        switch self {
        case .agentToAgent: return "#00BCD4"
        case .agentToFile: return "#FF9800"
        case .fileToAgent: return "#8BC34A"
        }
    }
}

struct AgentCollaborationPath: Identifiable {
    let id: UUID
    var sourceAgentId: UUID
    var targetAgentId: UUID
    var direction: DataFlowDirection
    var dataType: String
    var isActive: Bool = true
    var transferCount: Int = 0
    var timestamp: Date = Date()
}

struct SharedResourceAccess: Identifiable {
    let id: UUID
    var resourcePath: String
    var accessingAgentIds: [UUID]
    var hasConflict: Bool
    var lastAccessedAt: Date
    var accessType: ResourceAccessType
}

enum ResourceAccessType: String, CaseIterable {
    case read = "read"
    case write = "write"
    case readWrite = "read_write"

    var hexColor: String {
        switch self {
        case .read: return "#4CAF50"
        case .write: return "#F44336"
        case .readWrite: return "#FF9800"
        }
    }

    var iconName: String {
        switch self {
        case .read: return "eye"
        case .write: return "pencil"
        case .readWrite: return "pencil.and.outline"
        }
    }
}

struct TaskHandoff: Identifiable {
    let id: UUID
    var fromAgentId: UUID
    var toAgentId: UUID
    var taskTitle: String
    var handoffReason: String
    var timestamp: Date
    var isAnimating: Bool = false
}

struct TeamEfficiencyMetric: Identifiable {
    let id: UUID
    var dimension: String
    var value: Double // 0.0 - 1.0
    var label: String
}

struct CollaborationStats {
    var totalPaths: Int = 0
    var activeConflicts: Int = 0
    var handoffCount: Int = 0
    var avgEfficiency: Double = 0
}
