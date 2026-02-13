import Foundation
import Combine

// MARK: - Smart Concurrency Controller

/// Controls the number of simultaneously active sub-agents to prevent idle agent buildup.
/// Uses a demand-driven approach: sub-agents are only created/started when they can immediately work.
/// Integrates with lifecycle management and resource pressure to dynamically adjust concurrency limits.
@MainActor
class ConcurrencyController: ObservableObject {

    // MARK: - Configuration

    struct ConcurrencyConfig: Codable, Equatable {
        /// Maximum number of CLI processes that can run simultaneously
        var maxConcurrentProcesses: Int = 6
        /// Maximum sub-agents that can be in active (working/thinking) state
        var maxActiveSubAgents: Int = 8
        /// Minimum concurrent processes (never go below this even under pressure)
        var minConcurrentProcesses: Int = 1
        /// How many tasks to look ahead when deciding wave size
        var lookAheadDepth: Int = 3
        /// Whether to enable adaptive throttling based on system load
        var enableAdaptiveThrottling: Bool = true

        static let `default` = ConcurrencyConfig()

        static let conservative = ConcurrencyConfig(
            maxConcurrentProcesses: 3,
            maxActiveSubAgents: 4,
            minConcurrentProcesses: 1,
            lookAheadDepth: 2
        )
    }

    // MARK: - Published State

    @Published var config: ConcurrencyConfig = .default
    @Published private(set) var currentActiveCount: Int = 0
    @Published private(set) var currentQueuedCount: Int = 0
    @Published private(set) var effectiveLimit: Int = 6

    // MARK: - Dependencies

    weak var lifecycleManager: AgentLifecycleManager?
    weak var cleanupManager: AgentCleanupManager?

    // MARK: - Internal State

    /// Pending task starts, waiting for a concurrency slot
    private var pendingStarts: [(commanderId: UUID, taskIndex: Int, model: ClaudeModel, priority: TaskPriority)] = []
    /// Callback to actually start a sub-agent CLI process
    var onStartSubAgent: ((UUID, Int, ClaudeModel) -> Void)?
    /// Currently running task indices per orchestration
    private var runningTasks: [UUID: Set<Int>] = [:]

    // MARK: - Concurrency Decisions

    /// Calculates how many tasks from a wave can start right now
    func availableSlots() -> Int {
        return max(0, effectiveLimit - currentActiveCount)
    }

    /// Request to start a sub-agent task. Returns true if started immediately, false if queued.
    @discardableResult
    func requestStart(commanderId: UUID, taskIndex: Int, model: ClaudeModel, priority: TaskPriority = .medium) -> Bool {
        if availableSlots() > 0 {
            startTask(commanderId: commanderId, taskIndex: taskIndex, model: model)
            return true
        } else {
            enqueue(commanderId: commanderId, taskIndex: taskIndex, model: model, priority: priority)
            return false
        }
    }

    /// Notify the controller that a sub-agent task has completed or failed
    func taskCompleted(commanderId: UUID, taskIndex: Int) {
        runningTasks[commanderId]?.remove(taskIndex)
        if runningTasks[commanderId]?.isEmpty == true {
            runningTasks.removeValue(forKey: commanderId)
        }
        currentActiveCount = max(0, currentActiveCount - 1)
        drainQueue()
    }

    /// Notify the controller that a sub-agent has been cancelled
    func taskCancelled(commanderId: UUID, taskIndex: Int) {
        taskCompleted(commanderId: commanderId, taskIndex: taskIndex)
    }

    // MARK: - Adaptive Throttling

    /// Adjust effective concurrency limit based on resource pressure
    func adjustForPressure(_ pressure: ResourcePressure) {
        guard config.enableAdaptiveThrottling else {
            effectiveLimit = config.maxConcurrentProcesses
            return
        }

        switch pressure {
        case .normal:
            effectiveLimit = config.maxConcurrentProcesses
        case .elevated:
            effectiveLimit = max(config.minConcurrentProcesses, config.maxConcurrentProcesses * 3 / 4)
        case .high:
            effectiveLimit = max(config.minConcurrentProcesses, config.maxConcurrentProcesses / 2)
        case .critical:
            effectiveLimit = config.minConcurrentProcesses
        }

        // If we're now under the limit, drain queued tasks
        drainQueue()
    }

    /// Calculate optimal wave size for a set of ready tasks
    func optimalWaveSize(readyCount: Int, totalRemaining: Int) -> Int {
        let slots = availableSlots()
        guard slots > 0 else { return 0 }

        // Don't start more tasks than available slots
        var waveSize = min(readyCount, slots)

        // If there are subsequent waves, leave some headroom for faster turnover
        if totalRemaining > readyCount && config.lookAheadDepth > 1 {
            let headroom = max(1, slots / config.lookAheadDepth)
            waveSize = min(waveSize, slots - headroom + 1)
        }

        return max(1, waveSize)
    }

    // MARK: - Query

    /// Returns the number of running tasks for a specific orchestration
    func runningCount(for commanderId: UUID) -> Int {
        runningTasks[commanderId]?.count ?? 0
    }

    var totalRunningCount: Int {
        runningTasks.values.reduce(0) { $0 + $1.count }
    }

    var isAtCapacity: Bool {
        currentActiveCount >= effectiveLimit
    }

    // MARK: - Reset

    func reset() {
        pendingStarts.removeAll()
        runningTasks.removeAll()
        currentActiveCount = 0
        currentQueuedCount = 0
    }

    // MARK: - Private

    private func startTask(commanderId: UUID, taskIndex: Int, model: ClaudeModel) {
        runningTasks[commanderId, default: []].insert(taskIndex)
        currentActiveCount += 1
        onStartSubAgent?(commanderId, taskIndex, model)
    }

    private func enqueue(commanderId: UUID, taskIndex: Int, model: ClaudeModel, priority: TaskPriority) {
        pendingStarts.append((commanderId, taskIndex, model, priority))
        // Sort queue by priority (critical first)
        pendingStarts.sort { $0.priority.sortOrder > $1.priority.sortOrder }
        currentQueuedCount = pendingStarts.count
    }

    private func drainQueue() {
        while availableSlots() > 0 && !pendingStarts.isEmpty {
            let next = pendingStarts.removeFirst()
            startTask(commanderId: next.commanderId, taskIndex: next.taskIndex, model: next.model)
        }
        currentQueuedCount = pendingStarts.count
    }
}

