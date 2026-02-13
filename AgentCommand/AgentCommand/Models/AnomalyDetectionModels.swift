import Foundation

// MARK: - L3: Anomaly Detection & Self-healing Models

enum AnomalyType: String, CaseIterable, Identifiable {
    case infiniteLoop = "infinite_loop"
    case excessiveTokens = "excessive_tokens"
    case repeatedErrors = "repeated_errors"
    case longRunning = "long_running"
    case memoryLeak = "memory_leak"
    case rateLimitRisk = "rate_limit_risk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .infiniteLoop: return "Infinite Loop"
        case .excessiveTokens: return "Excessive Tokens"
        case .repeatedErrors: return "Repeated Errors"
        case .longRunning: return "Long Running"
        case .memoryLeak: return "Memory Leak"
        case .rateLimitRisk: return "Rate Limit Risk"
        }
    }

    var iconName: String {
        switch self {
        case .infiniteLoop: return "arrow.triangle.2.circlepath"
        case .excessiveTokens: return "dollarsign.circle"
        case .repeatedErrors: return "exclamationmark.triangle"
        case .longRunning: return "clock.badge.exclamationmark"
        case .memoryLeak: return "memorychip"
        case .rateLimitRisk: return "gauge.with.needle.fill"
        }
    }

    var hexColor: String {
        switch self {
        case .infiniteLoop: return "#F44336"
        case .excessiveTokens: return "#FF9800"
        case .repeatedErrors: return "#E91E63"
        case .longRunning: return "#FF5722"
        case .memoryLeak: return "#9C27B0"
        case .rateLimitRisk: return "#FF9800"
        }
    }
}

enum AnomalySeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"

    var hexColor: String {
        switch self {
        case .info: return "#2196F3"
        case .warning: return "#FF9800"
        case .critical: return "#F44336"
        }
    }

    var iconName: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

enum RetryStrategy: String, CaseIterable, Identifiable {
    case none = "none"
    case immediate = "immediate"
    case exponentialBackoff = "exponential_backoff"
    case fixedDelay = "fixed_delay"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Retry"
        case .immediate: return "Immediate"
        case .exponentialBackoff: return "Exponential Backoff"
        case .fixedDelay: return "Fixed Delay"
        }
    }
}

struct AnomalyAlert: Identifiable {
    let id: UUID
    var type: AnomalyType
    var severity: AnomalySeverity
    var message: String
    var agentName: String?
    var taskName: String?
    var detectedAt: Date
    var isResolved: Bool
    var autoAction: String?
    var metrics: [String: Double]
}

struct RetryConfig: Identifiable {
    let id: UUID
    var strategy: RetryStrategy
    var maxRetries: Int
    var delaySeconds: TimeInterval
    var appliedCount: Int
    var lastRetryAt: Date?
    var isActive: Bool
}

struct ErrorPattern: Identifiable {
    let id: UUID
    var pattern: String
    var occurrenceCount: Int
    var firstSeen: Date
    var lastSeen: Date
    var suggestedFix: String?
    var category: AnomalyType
}

struct AnomalyStats {
    var totalAlerts: Int = 0
    var activeAlerts: Int = 0
    var resolvedAlerts: Int = 0
    var autoResolvedCount: Int = 0
    var avgResolutionTime: TimeInterval = 0
    var topPatterns: [ErrorPattern] = []
    var retrySuccessRate: Double = 0
}
