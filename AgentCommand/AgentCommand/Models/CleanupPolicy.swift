import Foundation

/// Configuration for the adaptive cleanup strategy
struct CleanupPolicy: Codable, Equatable {
    // Tier 1: Time-based thresholds
    var completedTeamDelay: TimeInterval = 15.0
    var failedTeamDelay: TimeInterval = 10.0
    var idleAgentTimeout: TimeInterval = 120.0
    var suspendedIdleTimeout: TimeInterval = 300.0

    // Tier 2: Resource thresholds
    var maxConcurrentAgents: Int = 24
    var maxConcurrentProcesses: Int = 8
    var memoryWarningThresholdMB: Int = 2048

    // Tier 3: Emergency thresholds
    var memoryCriticalThresholdMB: Int = 3072
    var processHangTimeoutSeconds: TimeInterval = 300

    // Behavior flags
    var enableAutoPoolReturn: Bool = true
    var enableResourceMonitoring: Bool = true

    static let `default` = CleanupPolicy()

    static let aggressive = CleanupPolicy(
        completedTeamDelay: 5.0,
        failedTeamDelay: 3.0,
        idleAgentTimeout: 30.0,
        maxConcurrentAgents: 12
    )
}

/// Represents the current resource pressure level
enum ResourcePressure: String, Codable, CaseIterable, Comparable {
    case normal     // < 50% capacity
    case elevated   // 50-75% capacity
    case high       // 75-100% capacity
    case critical   // > 100% capacity or memory critical

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var hexColor: String {
        switch self {
        case .normal: return "#4CAF50"
        case .elevated: return "#FF9800"
        case .high: return "#FF5722"
        case .critical: return "#F44336"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .normal: return 0
        case .elevated: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    static func < (lhs: ResourcePressure, rhs: ResourcePressure) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
