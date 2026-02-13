import Foundation

/// Configures automatic retry behavior for failed CLI processes
struct RetryPolicy: Codable {
    /// Maximum number of retry attempts before giving up
    var maxRetries: Int = 2

    /// Initial delay (seconds) before first retry
    var retryDelay: TimeInterval = 3.0

    /// Multiplier applied to delay for each subsequent retry
    var backoffMultiplier: Double = 2.0

    static let `default` = RetryPolicy()
    static let aggressive = RetryPolicy(maxRetries: 3, retryDelay: 1.0)
    static let none = RetryPolicy(maxRetries: 0)

    /// Compute delay for a given retry attempt (0-based)
    func delay(forAttempt attempt: Int) -> TimeInterval {
        retryDelay * pow(backoffMultiplier, Double(attempt))
    }

    /// Whether the given error message indicates a user-initiated cancellation
    static func isUserCancellation(_ error: String) -> Bool {
        let lower = error.lowercased()
        return lower.contains("cancelled") || lower.contains("canceled")
            || lower.contains("user cancel") || lower.contains("terminated by user")
    }
}
