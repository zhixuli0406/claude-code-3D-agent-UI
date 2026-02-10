import Foundation

enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var hexColor: String {
        switch self {
        case .pending: return "#9E9E9E"
        case .inProgress: return "#FF9800"
        case .completed: return "#4CAF50"
        case .failed: return "#F44336"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical

    var displayName: String { rawValue.capitalized }

    var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}
