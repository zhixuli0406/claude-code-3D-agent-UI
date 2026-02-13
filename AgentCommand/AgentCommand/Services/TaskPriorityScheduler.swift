import Foundation
import Combine

// MARK: - Task Priority Scheduler

/// Manages task prioritization and scheduling for decomposed sub-tasks.
/// Determines execution order based on priority, dependencies, complexity, and resource availability.
/// Ensures high-priority tasks are executed first and no sub-agents sit idle waiting unnecessarily.
@MainActor
class TaskPriorityScheduler: ObservableObject {

    // MARK: - Scheduled Item

    struct ScheduledItem: Identifiable {
        let id: UUID = UUID()
        let commanderId: UUID
        let taskIndex: Int
        let title: String
        var priority: TaskPriority
        let complexity: TaskComplexity
        let dependencies: [Int]
        var state: ScheduleState = .pending
        var enqueuedAt: Date = Date()
        var startedAt: Date?
        var completedAt: Date?

        var waitTime: TimeInterval? {
            guard let started = startedAt else { return nil }
            return started.timeIntervalSince(enqueuedAt)
        }

        /// Composite score for scheduling order (higher = execute sooner)
        var schedulingScore: Double {
            var score: Double = Double(priority.sortOrder) * 100.0

            // Boost short tasks (less complexity = higher score for quick turnaround)
            switch complexity {
            case .low: score += 30
            case .medium: score += 15
            case .high: score += 0
            }

            // Penalize tasks that have been waiting too long (starvation prevention)
            let waitSeconds = Date().timeIntervalSince(enqueuedAt)
            score += min(50.0, waitSeconds / 2.0)

            // Boost tasks with no dependencies (can start immediately)
            if dependencies.isEmpty {
                score += 20
            }

            return score
        }
    }

    enum ScheduleState: String {
        case pending
        case ready       // Dependencies satisfied, waiting for slot
        case running
        case completed
        case failed
        case skipped     // Dependency failed, this task cannot run
    }

    enum TaskComplexity: String, Codable {
        case low
        case medium
        case high

        init(from string: String) {
            switch string.lowercased() {
            case "low": self = .low
            case "high": self = .high
            default: self = .medium
            }
        }

        var estimatedDurationMultiplier: Double {
            switch self {
            case .low: return 0.5
            case .medium: return 1.0
            case .high: return 2.0
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var schedule: [ScheduledItem] = []
    @Published private(set) var schedulerStats: SchedulerStats = SchedulerStats()

    struct SchedulerStats: Equatable {
        var totalScheduled: Int = 0
        var totalCompleted: Int = 0
        var totalFailed: Int = 0
        var totalSkipped: Int = 0
        var avgWaitTime: TimeInterval = 0
        var maxWaitTime: TimeInterval = 0
        var priorityDistribution: [String: Int] = [:]
    }

    // MARK: - Schedule Management

    /// Add sub-tasks from a decomposition to the schedule
    func scheduleSubTasks(commanderId: UUID, subTasks: [OrchestratedSubTask]) {
        let items = subTasks.map { subTask -> ScheduledItem in
            let priority = inferPriority(from: subTask)
            let complexity = TaskComplexity(from: subTask.estimatedComplexity)

            return ScheduledItem(
                commanderId: commanderId,
                taskIndex: subTask.index,
                title: subTask.title,
                priority: priority,
                complexity: complexity,
                dependencies: subTask.dependencies
            )
        }

        schedule.append(contentsOf: items)
        updateReadyStates(commanderId: commanderId)
        updateStats()
    }

    /// Get the next batch of tasks to execute, respecting dependencies and priorities
    func nextBatch(commanderId: UUID, maxSize: Int) -> [ScheduledItem] {
        let ready = schedule.filter { $0.commanderId == commanderId && $0.state == .ready }
        let sorted = ready.sorted { $0.schedulingScore > $1.schedulingScore }
        return Array(sorted.prefix(maxSize))
    }

    /// Mark a task as started
    func markStarted(commanderId: UUID, taskIndex: Int) {
        guard let idx = schedule.firstIndex(where: {
            $0.commanderId == commanderId && $0.taskIndex == taskIndex
        }) else { return }
        schedule[idx].state = .running
        schedule[idx].startedAt = Date()
        updateStats()
    }

    /// Mark a task as completed and update dependent tasks
    func markCompleted(commanderId: UUID, taskIndex: Int) {
        guard let idx = schedule.firstIndex(where: {
            $0.commanderId == commanderId && $0.taskIndex == taskIndex
        }) else { return }
        schedule[idx].state = .completed
        schedule[idx].completedAt = Date()
        updateReadyStates(commanderId: commanderId)
        updateStats()
    }

    /// Mark a task as failed and skip dependent tasks
    func markFailed(commanderId: UUID, taskIndex: Int) {
        guard let idx = schedule.firstIndex(where: {
            $0.commanderId == commanderId && $0.taskIndex == taskIndex
        }) else { return }
        schedule[idx].state = .failed
        schedule[idx].completedAt = Date()

        // Skip tasks that depend on this failed task
        skipDependents(commanderId: commanderId, failedIndex: taskIndex)
        updateReadyStates(commanderId: commanderId)
        updateStats()
    }

    /// Adjust priority of a specific task
    func adjustPriority(commanderId: UUID, taskIndex: Int, newPriority: TaskPriority) {
        guard let idx = schedule.firstIndex(where: {
            $0.commanderId == commanderId && $0.taskIndex == taskIndex
        }) else { return }
        schedule[idx].priority = newPriority
        updateStats()
    }

    /// Remove all scheduled items for a given orchestration
    func removeOrchestration(commanderId: UUID) {
        schedule.removeAll { $0.commanderId == commanderId }
        updateStats()
    }

    /// Check if all tasks for a commander are done (completed, failed, or skipped)
    func isOrchestrationDone(commanderId: UUID) -> Bool {
        let tasks = schedule.filter { $0.commanderId == commanderId }
        return !tasks.isEmpty && tasks.allSatisfy {
            $0.state == .completed || $0.state == .failed || $0.state == .skipped
        }
    }

    /// Returns ready task count for a given orchestration
    func readyCount(commanderId: UUID) -> Int {
        schedule.filter { $0.commanderId == commanderId && $0.state == .ready }.count
    }

    /// Returns the count of tasks in various states for a given orchestration
    func stateDistribution(commanderId: UUID) -> [ScheduleState: Int] {
        let tasks = schedule.filter { $0.commanderId == commanderId }
        return Dictionary(grouping: tasks, by: \.state).mapValues(\.count)
    }

    // MARK: - Priority Inference

    /// Infer task priority from the sub-task definition based on keywords and complexity
    private func inferPriority(from subTask: OrchestratedSubTask) -> TaskPriority {
        let title = subTask.title.lowercased()
        let prompt = subTask.prompt.lowercased()
        let combined = title + " " + prompt

        // Critical: security, hotfix, crash, data loss
        let criticalKeywords = ["security", "hotfix", "crash", "data loss", "vulnerability", "critical"]
        if criticalKeywords.contains(where: { combined.contains($0) }) {
            return .critical
        }

        // High: fix, bug, test, core functionality
        let highKeywords = ["fix", "bug", "test", "core", "essential", "important", "urgent"]
        if highKeywords.contains(where: { combined.contains($0) }) {
            return .high
        }

        // Low: documentation, style, formatting, comments
        let lowKeywords = ["documentation", "docs", "comment", "style", "format", "cleanup", "readme"]
        if lowKeywords.contains(where: { combined.contains($0) }) {
            return .low
        }

        // Default: medium
        return .medium
    }

    // MARK: - Private Helpers

    /// Update ready states for all pending tasks in an orchestration
    private func updateReadyStates(commanderId: UUID) {
        for i in 0..<schedule.count {
            guard schedule[i].commanderId == commanderId,
                  schedule[i].state == .pending else { continue }

            let depsCompleted = schedule[i].dependencies.allSatisfy { depIdx in
                schedule.contains { item in
                    item.commanderId == commanderId &&
                    item.taskIndex == depIdx &&
                    item.state == .completed
                }
            }

            // Also check if any dependency has failed/skipped (then skip this too)
            let depFailed = schedule[i].dependencies.contains { depIdx in
                schedule.contains { item in
                    item.commanderId == commanderId &&
                    item.taskIndex == depIdx &&
                    (item.state == .failed || item.state == .skipped)
                }
            }

            if depFailed {
                schedule[i].state = .skipped
            } else if depsCompleted {
                schedule[i].state = .ready
            }
        }
    }

    /// Mark all tasks that depend on a failed task as skipped (cascade)
    private func skipDependents(commanderId: UUID, failedIndex: Int) {
        for i in 0..<schedule.count {
            guard schedule[i].commanderId == commanderId,
                  schedule[i].state == .pending || schedule[i].state == .ready else { continue }

            if schedule[i].dependencies.contains(failedIndex) {
                schedule[i].state = .skipped
                // Recursively skip dependents of this skipped task
                skipDependents(commanderId: commanderId, failedIndex: schedule[i].taskIndex)
            }
        }
    }

    private func updateStats() {
        let all = schedule
        schedulerStats.totalScheduled = all.count
        schedulerStats.totalCompleted = all.filter { $0.state == .completed }.count
        schedulerStats.totalFailed = all.filter { $0.state == .failed }.count
        schedulerStats.totalSkipped = all.filter { $0.state == .skipped }.count

        let completedWithWait = all.compactMap { $0.waitTime }
        schedulerStats.avgWaitTime = completedWithWait.isEmpty ? 0 :
            completedWithWait.reduce(0, +) / Double(completedWithWait.count)
        schedulerStats.maxWaitTime = completedWithWait.max() ?? 0

        schedulerStats.priorityDistribution = Dictionary(
            grouping: all, by: { $0.priority.rawValue }
        ).mapValues(\.count)
    }
}
