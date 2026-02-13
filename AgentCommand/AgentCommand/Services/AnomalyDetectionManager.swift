import Foundation
import Combine

// MARK: - L3: Anomaly Detection & Self-healing Manager

@MainActor
class AnomalyDetectionManager: ObservableObject {
    @Published var alerts: [AnomalyAlert] = []
    @Published var retryConfigs: [RetryConfig] = []
    @Published var errorPatterns: [ErrorPattern] = []
    @Published var stats: AnomalyStats = AnomalyStats()
    @Published var isMonitoring: Bool = false

    // Memory optimization: cap collection sizes to prevent unbounded growth
    private static let maxAlerts = 200
    private static let maxErrorPatterns = 50
    private static let maxRetryConfigs = 20

    private var monitorTimer: Timer?
    private var taskStartTimes: [UUID: Date] = [:]
    private var taskTokenCounts: [UUID: Int] = [:]

    /// Back-reference to AppState for reading live agent/task data
    weak var appState: AppState?

    deinit {
        monitorTimer?.invalidate()
    }

    func startMonitoring() {
        isMonitoring = true
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForAnomalies()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    /// Record when a task starts for duration tracking
    func trackTaskStart(_ taskId: UUID) {
        taskStartTimes[taskId] = Date()
    }

    /// Record token usage for a task
    func trackTokenUsage(_ taskId: UUID, tokens: Int) {
        taskTokenCounts[taskId, default: 0] += tokens
    }

    func checkForAnomalies() {
        guard let appState = appState else {
            updateStats()
            return
        }

        let runningTasks = appState.tasks.filter { $0.status == .inProgress }

        for task in runningTasks {
            let taskId = task.id
            let agentName = task.assignedAgentId.flatMap { agentId in
                appState.agents.first(where: { $0.id == agentId })?.name
            }

            // Check for long-running tasks (> 5 minutes)
            let startTime = taskStartTimes[taskId] ?? task.createdAt
            let duration = Date().timeIntervalSince(startTime)
            if duration > 300 && !alerts.contains(where: { $0.taskName == task.title && $0.type == .longRunning && !$0.isResolved }) {
                reportAnomaly(
                    type: .longRunning,
                    severity: duration > 600 ? .critical : .warning,
                    message: "Task '\(task.title)' running for \(Int(duration / 60)) minutes",
                    agentName: agentName,
                    taskName: task.title,
                    metrics: ["duration_min": duration / 60, "timeout_min": 10]
                )
            }

            // Check for excessive token usage (> 10000 tokens)
            if let tokens = taskTokenCounts[taskId], tokens > 10000 {
                if !alerts.contains(where: { $0.taskName == task.title && $0.type == .excessiveTokens && !$0.isResolved }) {
                    reportAnomaly(
                        type: .excessiveTokens,
                        severity: tokens > 20000 ? .critical : .warning,
                        message: "Task '\(task.title)' has consumed \(tokens) tokens",
                        agentName: agentName,
                        taskName: task.title,
                        metrics: ["tokens": Double(tokens), "threshold": 10000]
                    )
                }
            }
        }

        // Check for repeated task failures (same agent failing 3+ times)
        let failedTasks = appState.tasks.filter { $0.status == .failed }
        var failuresByAgent: [UUID: Int] = [:]
        for task in failedTasks {
            if let agentId = task.assignedAgentId {
                failuresByAgent[agentId, default: 0] += 1
            }
        }
        for (agentId, failCount) in failuresByAgent where failCount >= 3 {
            let agentName = appState.agents.first(where: { $0.id == agentId })?.name ?? "Unknown"
            if !alerts.contains(where: { $0.agentName == agentName && $0.type == .repeatedErrors && !$0.isResolved }) {
                reportAnomaly(
                    type: .repeatedErrors,
                    severity: .critical,
                    message: "Agent '\(agentName)' has \(failCount) failed tasks",
                    agentName: agentName,
                    metrics: ["error_count": Double(failCount)]
                )
            }
        }

        // Clean up tracking for completed/removed tasks
        let activeTaskIds = Set(appState.tasks.map(\.id))
        taskStartTimes = taskStartTimes.filter { activeTaskIds.contains($0.key) }
        taskTokenCounts = taskTokenCounts.filter { activeTaskIds.contains($0.key) }

        updateStats()
    }

    func reportAnomaly(type: AnomalyType, severity: AnomalySeverity, message: String, agentName: String? = nil, taskName: String? = nil, metrics: [String: Double] = [:]) {
        let alert = AnomalyAlert(
            id: UUID(),
            type: type,
            severity: severity,
            message: message,
            agentName: agentName,
            taskName: taskName,
            detectedAt: Date(),
            isResolved: false,
            metrics: metrics
        )
        alerts.insert(alert, at: 0)

        // Evict oldest alerts when exceeding cap
        if alerts.count > Self.maxAlerts {
            let excess = alerts.count - Self.maxAlerts
            // Remove resolved alerts first (from end, oldest)
            var toRemove = IndexSet()
            let resolvedIndices = alerts.enumerated()
                .filter { $0.element.isResolved }
                .map { $0.offset }
                .reversed()
            for idx in resolvedIndices {
                if toRemove.count >= excess { break }
                toRemove.insert(idx)
            }
            // If still over, remove oldest unresolved alerts
            if toRemove.count < excess {
                let unresolvedIndices = alerts.enumerated()
                    .filter { !$0.element.isResolved }
                    .map { $0.offset }
                    .reversed()
                for idx in unresolvedIndices {
                    if toRemove.count >= excess { break }
                    toRemove.insert(idx)
                }
            }
            for idx in toRemove.sorted().reversed() {
                alerts.remove(at: idx)
            }
        }

        // Track error pattern
        trackPattern(type: type, message: message)

        // Auto-resolve if possible
        if let action = suggestAutoAction(for: type, severity: severity) {
            var mutableAlert = alert
            mutableAlert.autoAction = action
            if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[index] = mutableAlert
            }
        }

        updateStats()
    }

    func resolveAlert(_ alertId: UUID) {
        guard let index = alerts.firstIndex(where: { $0.id == alertId }) else { return }
        alerts[index].isResolved = true
        updateStats()
    }

    func resolveAllAlerts() {
        for i in alerts.indices {
            alerts[i].isResolved = true
        }
        updateStats()
    }

    func dismissAlert(_ alertId: UUID) {
        alerts.removeAll { $0.id == alertId }
        updateStats()
    }

    func configureRetry(strategy: RetryStrategy, maxRetries: Int, delaySeconds: TimeInterval) {
        let config = RetryConfig(
            id: UUID(),
            strategy: strategy,
            maxRetries: maxRetries,
            delaySeconds: delaySeconds,
            appliedCount: 0,
            isActive: true
        )
        retryConfigs.append(config)

        // Evict configs when exceeding cap: prefer inactive, then oldest
        while retryConfigs.count > Self.maxRetryConfigs {
            if let inactiveIdx = retryConfigs.firstIndex(where: { !$0.isActive }) {
                retryConfigs.remove(at: inactiveIdx)
            } else {
                // All active — remove the oldest (first) entry
                retryConfigs.removeFirst()
            }
        }
    }

    func setDefaultRetryConfig() {
        retryConfigs = [
            RetryConfig(id: UUID(), strategy: .exponentialBackoff, maxRetries: 3, delaySeconds: 5, appliedCount: 0, isActive: true),
            RetryConfig(id: UUID(), strategy: .fixedDelay, maxRetries: 2, delaySeconds: 10, appliedCount: 0, isActive: false),
        ]
    }

    func toggleRetryConfig(_ configId: UUID) {
        guard let index = retryConfigs.firstIndex(where: { $0.id == configId }) else { return }
        retryConfigs[index].isActive.toggle()
    }

    func loadSampleData() {
        alerts = [
            AnomalyAlert(id: UUID(), type: .excessiveTokens, severity: .warning, message: "Task 'refactor-auth' has consumed 15,000 tokens, exceeding the 10,000 threshold", agentName: "Developer-1", taskName: "refactor-auth", detectedAt: Date().addingTimeInterval(-120), isResolved: false, metrics: ["tokens": 15000, "threshold": 10000]),
            AnomalyAlert(id: UUID(), type: .longRunning, severity: .info, message: "Task 'integration-test' running for 8 minutes, approaching timeout", agentName: "Tester-1", taskName: "integration-test", detectedAt: Date().addingTimeInterval(-300), isResolved: false, metrics: ["duration_min": 8, "timeout_min": 10]),
            AnomalyAlert(id: UUID(), type: .repeatedErrors, severity: .critical, message: "Build failure detected 3 times in the last hour", agentName: "Builder-1", taskName: "ci-build", detectedAt: Date().addingTimeInterval(-600), isResolved: true, autoAction: "Automatic retry with clean build cache", metrics: ["error_count": 3, "timespan_hr": 1]),
        ]

        errorPatterns = [
            ErrorPattern(id: UUID(), pattern: "Connection timeout", occurrenceCount: 5, firstSeen: Date().addingTimeInterval(-86400), lastSeen: Date().addingTimeInterval(-3600), suggestedFix: "Increase timeout limit or check network connectivity", category: .longRunning),
            ErrorPattern(id: UUID(), pattern: "Rate limit exceeded", occurrenceCount: 3, firstSeen: Date().addingTimeInterval(-43200), lastSeen: Date().addingTimeInterval(-7200), suggestedFix: "Implement request throttling or upgrade API plan", category: .rateLimitRisk),
        ]

        setDefaultRetryConfig()
        updateStats()
    }

    // MARK: - Private

    private func trackPattern(type: AnomalyType, message: String) {
        let shortMessage = String(message.prefix(50))
        if let index = errorPatterns.firstIndex(where: { $0.pattern == shortMessage }) {
            errorPatterns[index].occurrenceCount += 1
            errorPatterns[index].lastSeen = Date()
        } else {
            let pattern = ErrorPattern(
                id: UUID(),
                pattern: shortMessage,
                occurrenceCount: 1,
                firstSeen: Date(),
                lastSeen: Date(),
                category: type
            )
            errorPatterns.append(pattern)

            // Evict least-frequent patterns when exceeding cap
            if errorPatterns.count > Self.maxErrorPatterns {
                errorPatterns.sort { $0.occurrenceCount > $1.occurrenceCount }
                errorPatterns = Array(errorPatterns.prefix(Self.maxErrorPatterns))
            }
        }
    }

    private func suggestAutoAction(for type: AnomalyType, severity: AnomalySeverity) -> String? {
        switch type {
        case .excessiveTokens:
            return severity == .critical ? "Auto-interrupt: Token budget exceeded" : nil
        case .infiniteLoop:
            return "Auto-interrupt: Possible infinite loop detected"
        case .repeatedErrors:
            return "Retry with modified parameters"
        case .longRunning:
            return severity == .critical ? "Auto-timeout applied" : nil
        case .memoryLeak:
            return "Restart agent process"
        case .rateLimitRisk:
            return "Throttle requests to avoid rate limit"
        }
    }

    private func updateStats() {
        stats.totalAlerts = alerts.count
        stats.activeAlerts = alerts.filter { !$0.isResolved }.count
        stats.resolvedAlerts = alerts.filter { $0.isResolved }.count
        stats.autoResolvedCount = alerts.filter { $0.autoAction != nil && $0.isResolved }.count
        stats.topPatterns = Array(errorPatterns.sorted { $0.occurrenceCount > $1.occurrenceCount }.prefix(5))

        let totalRetries = retryConfigs.reduce(0) { $0 + $1.appliedCount }
        let resolvedAfterRetry = alerts.filter { $0.autoAction != nil && $0.isResolved }.count
        stats.retrySuccessRate = totalRetries == 0 ? 0 : min(1.0, Double(resolvedAfterRetry) / max(1.0, Double(totalRetries)))
    }
}
