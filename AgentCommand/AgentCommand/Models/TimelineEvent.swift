import Foundation

struct TimelineEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let kind: TimelineEventKind
    let taskId: UUID?
    let agentId: UUID?
    let title: String
    let detail: String?
    let cliEntryId: UUID?
}

enum TimelineEventKind: String, CaseIterable, Codable {
    case taskCreated
    case taskStarted
    case taskCompleted
    case taskFailed
    case taskCancelled
    case agentStatusChange
    case toolInvocation
    case permissionRequest
    case userQuestion
    case planReview

    var icon: String {
        switch self {
        case .taskCreated: return "plus.circle"
        case .taskStarted: return "play.circle"
        case .taskCompleted: return "checkmark.circle"
        case .taskFailed: return "xmark.circle"
        case .taskCancelled: return "stop.circle"
        case .agentStatusChange: return "person.circle"
        case .toolInvocation: return "wrench"
        case .permissionRequest: return "lock.shield"
        case .userQuestion: return "questionmark.circle"
        case .planReview: return "doc.text"
        }
    }

    var hexColor: String {
        switch self {
        case .taskCreated: return "#9E9E9E"
        case .taskStarted: return "#FF9800"
        case .taskCompleted: return "#4CAF50"
        case .taskFailed: return "#F44336"
        case .taskCancelled: return "#F44336"
        case .agentStatusChange: return "#2196F3"
        case .toolInvocation: return "#00BCD4"
        case .permissionRequest: return "#FF9800"
        case .userQuestion: return "#2196F3"
        case .planReview: return "#9C27B0"
        }
    }

    var displayName: String {
        switch self {
        case .taskCreated: return "Created"
        case .taskStarted: return "Started"
        case .taskCompleted: return "Completed"
        case .taskFailed: return "Failed"
        case .taskCancelled: return "Cancelled"
        case .agentStatusChange: return "Status"
        case .toolInvocation: return "Tool"
        case .permissionRequest: return "Permission"
        case .userQuestion: return "Question"
        case .planReview: return "Plan"
        }
    }
}

struct TimelineFilter {
    var agentIds: Set<UUID> = []
    var eventKinds: Set<TimelineEventKind> = []
}
