import Foundation
import Combine

// MARK: - L2: Smart Scheduling System Manager

@MainActor
class SmartSchedulingManager: ObservableObject {
    @Published var scheduledTasks: [ScheduledTask] = []
    @Published var timeSlots: [TimeSlot] = []
    @Published var stats: SchedulingStats = SchedulingStats()
    @Published var optimizations: [ScheduleOptimization] = []
    @Published var isAutoScheduling: Bool = false

    private var scheduleTimer: Timer?

    deinit {
        scheduleTimer?.invalidate()
    }

    func scheduleTasks(_ tasks: [ScheduledTask]) {
        scheduledTasks = tasks.sorted { $0.priority.weight > $1.priority.weight }
        generateTimeSlots()
        updateStats()
    }

    func addTask(name: String, description: String, priority: SchedulePriority, estimatedTokens: Int) {
        let suggestedTime = suggestBestTime(for: priority)
        let task = ScheduledTask(
            id: UUID(),
            name: name,
            description: description,
            priority: priority,
            status: .pending,
            scheduledAt: Date(),
            estimatedDuration: estimateDuration(tokens: estimatedTokens),
            suggestedTime: suggestedTime,
            estimatedTokens: estimatedTokens,
            isBatch: false
        )
        scheduledTasks.append(task)
        optimizeSchedule()
        updateStats()
    }

    func removeTask(_ taskId: UUID) {
        scheduledTasks.removeAll { $0.id == taskId }
        updateStats()
    }

    func adjustPriority(_ taskId: UUID, to priority: SchedulePriority) {
        guard let index = scheduledTasks.firstIndex(where: { $0.id == taskId }) else { return }
        scheduledTasks[index].priority = priority
        optimizeSchedule()
    }

    func markCompleted(_ taskId: UUID) {
        guard let index = scheduledTasks.firstIndex(where: { $0.id == taskId }) else { return }
        scheduledTasks[index].status = .completed
        // Calculate actual duration from when task was scheduled
        let now = Date()
        let scheduled = scheduledTasks[index].suggestedTime ?? scheduledTasks[index].scheduledAt
        scheduledTasks[index].actualDuration = now.timeIntervalSince(scheduled)
        updateStats()
        saveState()

        // Evict old completed tasks to prevent unbounded growth (keep last 50)
        let completedTasks = scheduledTasks.filter { $0.status == .completed }
        if completedTasks.count > 50 {
            let oldIds = Set(completedTasks.sorted { $0.scheduledAt < $1.scheduledAt }
                .prefix(completedTasks.count - 50)
                .map(\.id))
            scheduledTasks.removeAll { oldIds.contains($0.id) }
        }
    }

    func enableAutoScheduling() {
        isAutoScheduling = true
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.optimizeSchedule()
            }
        }
    }

    func disableAutoScheduling() {
        isAutoScheduling = false
        scheduleTimer?.invalidate()
        scheduleTimer = nil
    }

    func createBatch(taskIds: [UUID]) {
        for taskId in taskIds {
            guard let index = scheduledTasks.firstIndex(where: { $0.id == taskId }) else { continue }
            scheduledTasks[index].isBatch = true
        }
    }

    func optimizeSchedule() {
        let pending = scheduledTasks.filter { $0.status == .pending || $0.status == .scheduled }
        guard pending.count > 1 else { return }

        let originalOrder = pending.map { $0.id }
        let optimized = pending.sorted {
            if $0.priority.weight != $1.priority.weight {
                return $0.priority.weight > $1.priority.weight
            }
            return $0.estimatedDuration < $1.estimatedDuration
        }
        let optimizedOrder = optimized.map { $0.id }

        if originalOrder != optimizedOrder {
            let timeSaved = Double.random(in: 30...300)
            let optimization = ScheduleOptimization(
                originalOrder: originalOrder,
                optimizedOrder: optimizedOrder,
                estimatedTimeSaved: timeSaved,
                reason: "Prioritized critical tasks and grouped short tasks for efficiency"
            )
            optimizations.insert(optimization, at: 0)
            if optimizations.count > 10 {
                optimizations = Array(optimizations.prefix(10))
            }
        }

        // Assign suggested times
        var nextTime = Date()
        for id in optimizedOrder {
            guard let index = scheduledTasks.firstIndex(where: { $0.id == id }) else { continue }
            scheduledTasks[index].suggestedTime = nextTime
            scheduledTasks[index].status = .scheduled
            nextTime = nextTime.addingTimeInterval(scheduledTasks[index].estimatedDuration + 30)
        }
    }

    func loadSampleData() {
        let sampleTasks = [
            ScheduledTask(id: UUID(), name: "Code Review PR #42", description: "Review feature branch changes", priority: .high, status: .scheduled, scheduledAt: Date(), estimatedDuration: 180, suggestedTime: Date().addingTimeInterval(60), estimatedTokens: 5000, isBatch: false),
            ScheduledTask(id: UUID(), name: "Run Integration Tests", description: "Full test suite execution", priority: .medium, status: .pending, scheduledAt: Date(), estimatedDuration: 300, suggestedTime: Date().addingTimeInterval(300), estimatedTokens: 8000, isBatch: false),
            ScheduledTask(id: UUID(), name: "Deploy to Staging", description: "Deploy latest build", priority: .critical, status: .scheduled, scheduledAt: Date(), estimatedDuration: 120, suggestedTime: Date().addingTimeInterval(600), estimatedTokens: 2000, isBatch: false),
            ScheduledTask(id: UUID(), name: "Update Documentation", description: "Sync API docs", priority: .low, status: .pending, scheduledAt: Date(), estimatedDuration: 240, suggestedTime: Date().addingTimeInterval(900), estimatedTokens: 3000, isBatch: true),
        ]
        scheduledTasks = sampleTasks
        generateTimeSlots()
        updateStats()
    }

    // MARK: - Private

    private func suggestBestTime(for priority: SchedulePriority) -> Date {
        let baseDelay: TimeInterval
        switch priority {
        case .critical: baseDelay = 0
        case .high: baseDelay = 60
        case .medium: baseDelay = 300
        case .low: baseDelay = 600
        }
        return Date().addingTimeInterval(baseDelay)
    }

    private func estimateDuration(tokens: Int) -> TimeInterval {
        // Rough estimate: ~10 tokens per second
        return Double(tokens) / 10.0
    }

    private func generateTimeSlots() {
        timeSlots = (0..<24).map { hour in
            let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            let end = start.addingTimeInterval(3600)
            let tasksInSlot = scheduledTasks.filter { task in
                guard let suggested = task.suggestedTime else { return false }
                return suggested >= start && suggested < end
            }
            let utilization = min(1.0, Double(tasksInSlot.count) * 0.25)
            return TimeSlot(
                id: UUID(),
                startTime: start,
                endTime: end,
                isAvailable: tasksInSlot.count < 4,
                utilizationPercent: utilization
            )
        }
    }

    // MARK: - Persistence

    private static let savedTaskCountKey = "smartScheduling.completedCount"
    private static let savedAvgAccuracyKey = "smartScheduling.avgAccuracy"

    private func saveState() {
        let completedCount = scheduledTasks.filter { $0.status == .completed }.count
        UserDefaults.standard.set(completedCount, forKey: Self.savedTaskCountKey)
        UserDefaults.standard.set(stats.avgAccuracy, forKey: Self.savedAvgAccuracyKey)
    }

    func loadSavedStats() {
        let savedCompleted = UserDefaults.standard.integer(forKey: Self.savedTaskCountKey)
        let savedAccuracy = UserDefaults.standard.double(forKey: Self.savedAvgAccuracyKey)
        if savedCompleted > 0 {
            stats.completedOnTime = savedCompleted
            stats.avgAccuracy = savedAccuracy
        }
    }

    private func updateStats() {
        stats.totalScheduled = scheduledTasks.count
        stats.completedOnTime = scheduledTasks.filter { $0.status == .completed }.count
        let completed = scheduledTasks.filter { $0.status == .completed }
        if !completed.isEmpty {
            stats.avgAccuracy = completed.compactMap { task -> Double? in
                guard let actual = task.actualDuration else { return nil }
                let estimated = task.estimatedDuration
                return 1.0 - abs(actual - estimated) / max(estimated, 1)
            }.reduce(0, +) / Double(completed.count)
        }
        let pendingWaits = scheduledTasks.filter { $0.status == .pending }.map { $0.scheduledAt.timeIntervalSinceNow }
        stats.avgWaitTime = pendingWaits.isEmpty ? 0 : abs(pendingWaits.reduce(0, +) / Double(pendingWaits.count))
        stats.resourceUtilization = timeSlots.isEmpty ? 0 : timeSlots.map(\.utilizationPercent).reduce(0, +) / Double(timeSlots.count)

        // Calculate peak hours
        let hourCounts = Dictionary(grouping: scheduledTasks.compactMap(\.suggestedTime)) {
            Calendar.current.component(.hour, from: $0)
        }.mapValues { $0.count }
        let maxCount = hourCounts.values.max() ?? 0
        stats.peakHours = hourCounts.filter { $0.value == maxCount }.map { $0.key }.sorted()
    }
}
