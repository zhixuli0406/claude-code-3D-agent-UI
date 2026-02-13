import Foundation
import Combine

/// Tracks token usage, cost, task duration, and resource usage for CLI processes (D5)
@MainActor
class PerformanceMetricsManager: ObservableObject {
    // MARK: - Session-level metrics

    @Published var sessionTotalCost: Double = 0
    @Published var sessionTotalTokens: Int = 0
    @Published var sessionTaskCount: Int = 0

    // MARK: - Per-task metrics

    @Published var taskMetrics: [UUID: TaskMetrics] = [:]

    // Memory optimization: cap completed task metrics to prevent unbounded growth
    private static let maxCompletedMetrics = 100

    // MARK: - Resource monitoring

    @Published var processResourceUsage: [UUID: ResourceSnapshot] = [:]
    private var resourceTimer: Timer?

    // MARK: - Persistence

    private static let sessionCostKey = "d5_sessionTotalCost"
    private static let sessionTokensKey = "d5_sessionTotalTokens"
    private static let sessionTaskCountKey = "d5_sessionTaskCount"
    private static let sessionStartKey = "d5_sessionStartDate"

    @Published var sessionStartDate: Date

    init() {
        sessionTotalCost = UserDefaults.standard.double(forKey: Self.sessionCostKey)
        sessionTotalTokens = UserDefaults.standard.integer(forKey: Self.sessionTokensKey)
        sessionTaskCount = UserDefaults.standard.integer(forKey: Self.sessionTaskCountKey)

        if let savedDate = UserDefaults.standard.object(forKey: Self.sessionStartKey) as? Date {
            sessionStartDate = savedDate
        } else {
            sessionStartDate = Date()
            UserDefaults.standard.set(sessionStartDate, forKey: Self.sessionStartKey)
        }

        startResourceMonitoring()
    }

    deinit {
        resourceTimer?.invalidate()
    }

    // MARK: - Task Tracking

    func taskStarted(taskId: UUID, agentId: UUID, prompt: String) {
        let metrics = TaskMetrics(
            taskId: taskId,
            agentId: agentId,
            prompt: prompt,
            startTime: Date()
        )
        taskMetrics[taskId] = metrics
        sessionTaskCount += 1
        save()
    }

    func taskCompleted(taskId: UUID, costUSD: Double?, durationMs: Int?) {
        guard var metrics = taskMetrics[taskId] else { return }
        metrics.endTime = Date()
        metrics.status = .completed

        if let cost = costUSD {
            metrics.costUSD = cost
            sessionTotalCost += cost
        }

        if let duration = durationMs {
            metrics.durationMs = duration
        } else if let start = metrics.startTime {
            metrics.durationMs = Int(Date().timeIntervalSince(start) * 1000)
        }

        taskMetrics[taskId] = metrics
        save()
        evictOldMetrics()
    }

    func taskFailed(taskId: UUID) {
        guard var metrics = taskMetrics[taskId] else { return }
        metrics.endTime = Date()
        metrics.status = .failed
        if let start = metrics.startTime {
            metrics.durationMs = Int(Date().timeIntervalSince(start) * 1000)
        }
        taskMetrics[taskId] = metrics
        save()
        evictOldMetrics()
    }

    func recordToolCall(taskId: UUID, tool: String) {
        guard var metrics = taskMetrics[taskId] else { return }
        metrics.toolCallCount += 1
        metrics.toolUsage[tool, default: 0] += 1
        // Estimate tokens per tool call (~500 tokens average)
        metrics.estimatedTokens += 500
        sessionTotalTokens += 500
        taskMetrics[taskId] = metrics
    }

    func recordAssistantText(taskId: UUID, textLength: Int) {
        guard var metrics = taskMetrics[taskId] else { return }
        // Rough estimate: ~4 chars per token for output
        let estimatedTokens = max(textLength / 4, 1)
        metrics.estimatedTokens += estimatedTokens
        sessionTotalTokens += estimatedTokens
        taskMetrics[taskId] = metrics
    }

    func recordCost(taskId: UUID, costUSD: Double) {
        guard var metrics = taskMetrics[taskId] else { return }
        metrics.costUSD = costUSD
        sessionTotalCost += costUSD
        taskMetrics[taskId] = metrics
        save()
    }

    // MARK: - Resource Monitoring

    func registerProcess(taskId: UUID, pid: Int32) {
        processResourceUsage[taskId] = ResourceSnapshot(pid: pid)
    }

    func unregisterProcess(taskId: UUID) {
        processResourceUsage.removeValue(forKey: taskId)
    }

    private func startResourceMonitoring() {
        resourceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateResourceUsage()
            }
        }
    }

    private func updateResourceUsage() {
        for (taskId, var snapshot) in processResourceUsage {
            let pid = snapshot.pid
            // Use ps to get CPU and memory for the process
            let pipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-p", "\(pid)", "-o", "pcpu=,rss="]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    let parts = output.split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count >= 2 {
                        snapshot.cpuPercent = Double(parts[0]) ?? 0
                        // RSS is in KB from ps
                        snapshot.memoryKB = Int(parts[1]) ?? 0
                        snapshot.lastUpdated = Date()
                        processResourceUsage[taskId] = snapshot
                    }
                }
            } catch {
                // Process may have ended
                processResourceUsage.removeValue(forKey: taskId)
            }
        }
    }

    // MARK: - Memory Management

    /// Evict oldest completed/failed metrics when exceeding the cap
    private func evictOldMetrics() {
        let finished = taskMetrics.filter { $0.value.status != .running }
        guard finished.count > Self.maxCompletedMetrics else { return }

        // Sort finished by endTime ascending, remove oldest
        let sorted = finished.sorted { ($0.value.endTime ?? .distantPast) < ($1.value.endTime ?? .distantPast) }
        let removeCount = finished.count - Self.maxCompletedMetrics
        for entry in sorted.prefix(removeCount) {
            taskMetrics.removeValue(forKey: entry.key)
        }
    }

    // MARK: - Computed Properties

    var activeTaskCount: Int {
        taskMetrics.values.filter { $0.status == .running }.count
    }

    var completedTaskMetrics: [TaskMetrics] {
        taskMetrics.values
            .filter { $0.status == .completed }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    var averageTaskDurationMs: Int {
        let completed = taskMetrics.values.filter { $0.status == .completed && $0.durationMs > 0 }
        guard !completed.isEmpty else { return 0 }
        let total = completed.reduce(0) { $0 + $1.durationMs }
        return total / completed.count
    }

    var totalResourceCPU: Double {
        processResourceUsage.values.reduce(0) { $0 + $1.cpuPercent }
    }

    var totalResourceMemoryMB: Double {
        Double(processResourceUsage.values.reduce(0) { $0 + $1.memoryKB }) / 1024.0
    }

    // MARK: - Session Reset

    func resetSession() {
        sessionTotalCost = 0
        sessionTotalTokens = 0
        sessionTaskCount = 0
        taskMetrics.removeAll()
        sessionStartDate = Date()
        save()
        UserDefaults.standard.set(sessionStartDate, forKey: Self.sessionStartKey)
    }

    // MARK: - Persistence

    private func save() {
        UserDefaults.standard.set(sessionTotalCost, forKey: Self.sessionCostKey)
        UserDefaults.standard.set(sessionTotalTokens, forKey: Self.sessionTokensKey)
        UserDefaults.standard.set(sessionTaskCount, forKey: Self.sessionTaskCountKey)
    }
}

// MARK: - Data Models

struct TaskMetrics {
    let taskId: UUID
    let agentId: UUID
    let prompt: String
    var startTime: Date?
    var endTime: Date?
    var status: TaskMetricStatus = .running
    var costUSD: Double = 0
    var durationMs: Int = 0
    var estimatedTokens: Int = 0
    var toolCallCount: Int = 0
    var toolUsage: [String: Int] = [:]
}

enum TaskMetricStatus {
    case running
    case completed
    case failed
}

struct ResourceSnapshot {
    let pid: Int32
    var cpuPercent: Double = 0
    var memoryKB: Int = 0
    var lastUpdated: Date = Date()
}
