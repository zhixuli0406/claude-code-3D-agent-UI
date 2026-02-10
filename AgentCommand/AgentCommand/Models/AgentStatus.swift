import Foundation
import AppKit

enum AgentStatus: String, Codable, CaseIterable {
    case idle
    case working
    case thinking
    case completed
    case error

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .thinking: return "Thinking"
        case .completed: return "Completed"
        case .error: return "Error"
        }
    }

    var hexColor: String {
        switch self {
        case .idle: return "#888888"
        case .working: return "#4CAF50"
        case .thinking: return "#FF9800"
        case .completed: return "#2196F3"
        case .error: return "#F44336"
        }
    }
}
