import Foundation

/// Manages a persistable task queue that supports interruption and resumption.
/// Integrates with AutoDecompositionOrchestrator for wave-based execution.
@MainActor
class SubAgentTaskQueueManager: ObservableObject {

    /// All queue items, keyed by commanderId
    @Published var queues: [UUID: [SubAgentTaskQueueItem]] = [:]

    weak var persistenceManager: AgentPersistenceManager?

    // MARK: - Queue Operations

    /// Add a task item to the queue for a given commander
    func enqueue(_ item: SubAgentTaskQueueItem) {
        queues[item.commanderId, default: []].append(item)
        persistQueue(commanderId: item.commanderId)
    }

    /// Resolve dependencies and mark items as ready if their dependencies are all completed
    func resolveReady(commanderId: UUID) {
        guard var items = queues[commanderId] else { return }

        for i in 0..<items.count {
            guard items[i].status == .pending else { continue }

            let depsCompleted = items[i].dependencies.allSatisfy { depIdx in
                depIdx >= 0 && depIdx < items.count &&
                items[depIdx].status == .completed
            }

            if depsCompleted {
                items[i].status = .ready
            }
        }

        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    /// Dequeue the next ready item for execution
    func dequeueReady(commanderId: UUID) -> SubAgentTaskQueueItem? {
        guard var items = queues[commanderId] else { return nil }

        guard let idx = items.firstIndex(where: { $0.status == .ready }) else {
            return nil
        }

        items[idx].status = .inProgress
        items[idx].startedAt = Date()
        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
        return items[idx]
    }

    /// Get all ready items for a commander (for parallel wave execution)
    func allReadyItems(commanderId: UUID) -> [SubAgentTaskQueueItem] {
        queues[commanderId]?.filter { $0.status == .ready } ?? []
    }

    /// Mark an item as completed
    func markCompleted(itemId: UUID, commanderId: UUID, result: String?) {
        guard var items = queues[commanderId],
              let idx = items.firstIndex(where: { $0.id == itemId }) else { return }

        items[idx].status = .completed
        items[idx].completedAt = Date()
        items[idx].result = result
        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    /// Mark an item as failed
    func markFailed(itemId: UUID, commanderId: UUID, error: String) {
        guard var items = queues[commanderId],
              let idx = items.firstIndex(where: { $0.id == itemId }) else { return }

        items[idx].status = .failed
        items[idx].error = error
        items[idx].completedAt = Date()
        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    /// Suspend an in-progress item (e.g., for user interaction or app quit)
    func suspend(itemId: UUID, commanderId: UUID) {
        guard var items = queues[commanderId],
              let idx = items.firstIndex(where: { $0.id == itemId }) else { return }

        items[idx].status = .suspended
        items[idx].suspendedAt = Date()
        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    /// Resume a suspended item back to ready state
    func resume(itemId: UUID, commanderId: UUID) {
        guard var items = queues[commanderId],
              let idx = items.firstIndex(where: { $0.id == itemId }) else { return }

        items[idx].status = .ready
        items[idx].suspendedAt = nil
        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    /// Retry a failed item
    func retry(itemId: UUID, commanderId: UUID) {
        guard var items = queues[commanderId],
              let idx = items.firstIndex(where: { $0.id == itemId }) else { return }

        guard items[idx].canRetry else { return }

        items[idx].status = .ready
        items[idx].retryCount += 1
        items[idx].error = nil
        items[idx].completedAt = nil
        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    // MARK: - Queue Queries

    /// Whether all items in a queue are terminal (completed or failed)
    func isQueueFinished(commanderId: UUID) -> Bool {
        guard let items = queues[commanderId], !items.isEmpty else { return true }
        return items.allSatisfy { $0.status == .completed || $0.status == .failed }
    }

    /// Whether any items are still in progress
    func hasInProgressItems(commanderId: UUID) -> Bool {
        queues[commanderId]?.contains { $0.status == .inProgress } ?? false
    }

    /// Whether any items are suspended
    func hasSuspendedItems(commanderId: UUID) -> Bool {
        queues[commanderId]?.contains { $0.status == .suspended } ?? false
    }

    /// Count of completed items
    func completedCount(commanderId: UUID) -> Int {
        queues[commanderId]?.filter { $0.status == .completed }.count ?? 0
    }

    /// Total item count
    func totalCount(commanderId: UUID) -> Int {
        queues[commanderId]?.count ?? 0
    }

    /// Find queue item by orchestration task index
    func item(commanderId: UUID, taskIndex: Int) -> SubAgentTaskQueueItem? {
        queues[commanderId]?.first { $0.orchestrationTaskIndex == taskIndex }
    }

    // MARK: - Queue Lifecycle

    /// Remove a queue entirely (after orchestration completes)
    func removeQueue(commanderId: UUID) {
        queues.removeValue(forKey: commanderId)
        persistenceManager?.removeTaskQueue(commanderId: commanderId)
    }

    /// Suspend all in-progress items for a commander (e.g., on app quit)
    func suspendAll(commanderId: UUID) {
        guard var items = queues[commanderId] else { return }

        for i in 0..<items.count where items[i].status == .inProgress {
            items[i].status = .suspended
            items[i].suspendedAt = Date()
        }

        queues[commanderId] = items
        persistQueue(commanderId: commanderId)
    }

    /// Suspend all in-progress items across all queues
    func suspendAllQueues() {
        for commanderId in queues.keys {
            suspendAll(commanderId: commanderId)
        }
    }

    /// Load persisted queues from disk
    func loadPersistedQueues() {
        guard let persisted = persistenceManager?.allTaskQueues() else { return }
        for (commanderId, items) in persisted {
            // Only restore queues that have non-terminal items
            let hasActiveItems = items.contains {
                $0.status != .completed && $0.status != .failed
            }
            if hasActiveItems {
                queues[commanderId] = items
                print("[TaskQueue] Restored queue for commander \(commanderId) (\(items.count) items)")
            }
        }
    }

    // MARK: - Persistence

    private func persistQueue(commanderId: UUID) {
        guard let items = queues[commanderId] else { return }
        persistenceManager?.saveTaskQueue(commanderId: commanderId, items: items)
    }
}
