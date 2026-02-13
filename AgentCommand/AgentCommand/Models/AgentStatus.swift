import Foundation
import AppKit

enum AgentStatus: String, Codable, CaseIterable {
    case idle
    case working
    case thinking
    case completed
    case error
    case requestingPermission
    case waitingForAnswer
    case reviewingPlan
    case suspended             // CLI process terminated; waiting for user resume

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .thinking: return "Thinking"
        case .completed: return "Completed"
        case .error: return "Error"
        case .requestingPermission: return "Requesting Permission"
        case .waitingForAnswer: return "Waiting for Answer"
        case .reviewingPlan: return "Reviewing Plan"
        case .suspended: return "Suspended"
        }
    }

    @MainActor func localizedName(_ l: LocalizationManager) -> String {
        switch self {
        case .idle: return l.localized(.statusIdle)
        case .working: return l.localized(.statusWorking)
        case .thinking: return l.localized(.statusThinking)
        case .completed: return l.localized(.statusCompleted)
        case .error: return l.localized(.statusError)
        case .requestingPermission: return l.localized(.statusRequestingPermission)
        case .waitingForAnswer: return l.localized(.statusWaitingForAnswer)
        case .reviewingPlan: return l.localized(.statusReviewingPlan)
        case .suspended: return l.localized(.statusIdle) // fallback until localization key is added
        }
    }

    var hexColor: String {
        switch self {
        case .idle: return "#888888"
        case .working: return "#4CAF50"
        case .thinking: return "#FF9800"
        case .completed: return "#2196F3"
        case .error: return "#F44336"
        case .requestingPermission: return "#FF9800"
        case .waitingForAnswer: return "#2196F3"
        case .reviewingPlan: return "#9C27B0"
        case .suspended: return "#FFC107"
        }
    }

    /// Whether the agent is waiting for user input and should not be auto-disbanded
    var isWaitingForUser: Bool {
        switch self {
        case .requestingPermission, .waitingForAnswer, .reviewingPlan, .suspended:
            return true
        default:
            return false
        }
    }
}
