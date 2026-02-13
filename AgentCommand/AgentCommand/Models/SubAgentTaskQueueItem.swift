import Foundation

/// A persistable task queue item that supports interruption and resumption.
/// Used by SubAgentTaskQueueManager to manage orchestrated sub-tasks.
struct SubAgentTaskQueueItem: Codable, Identifiable {
    let id: UUID
    let commanderId: UUID
    let orchestrationTaskIndex: Int
    let title: String
    let prompt: String
    var agentId: UUID?
    let dependencies: [Int]  // Indices of tasks this depends on
    var status: QueueItemStatus
    var retryCount: Int = 0
    var enqueuedAt: Date
    var startedAt: Date?
    var suspendedAt: Date?
    var completedAt: Date?
    var result: String?
    var error: String?
    var sessionId: String?

    enum QueueItemStatus: String, Codable {
        case pending      // Not yet ready (dependencies unmet)
        case ready        // Dependencies met, waiting for execution
        case inProgress   // CLI process running
        case suspended    // Interrupted, can be resumed
        case completed    // Finished successfully
        case failed       // Failed after all retries exhausted
    }

    /// Whether this item can be retried
    var canRetry: Bool {
        status == .failed && retryCount < RetryPolicy.default.maxRetries
    }
}
