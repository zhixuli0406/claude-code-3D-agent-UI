import Foundation
import Combine

// MARK: - SubAgent Monitor & Reporter

/// Provides real-time monitoring, statistics, and reporting for sub-agent activity.
/// Tracks active/idle/pooled agents, detects idle agent buildup, and emits alerts
/// when sub-agents are sitting idle without tasks.
@MainActor
class SubAgentMonitor: ObservableObject {

    // MARK: - Published State

    @Published private(set) var report: SubAgentReport = SubAgentReport()
    @Published private(set) var alerts: [MonitorAlert] = []
    @Published private(set) var snapshots: [SubAgentSnapshot] = []

    // MARK: - Configuration

    struct MonitorConfig {
        /// How often to take snapshots (seconds)
        var snapshotInterval: TimeInterval = 10.0
        /// Maximum number of snapshots to keep in history
        var maxSnapshots: Int = 360  // 1 hour at 10s intervals
        /// Alert if idle agent count exceeds this threshold
        var idleAlertThreshold: Int = 3
        /// Alert if an agent has been idle for longer than this (seconds)
        var idleDurationAlertThreshold: TimeInterval = 60.0
        /// Whether monitoring is enabled
        var isEnabled: Bool = true
    }

    var config: MonitorConfig = MonitorConfig()

    // MARK: - Dependencies

    weak var lifecycleManager: AgentLifecycleManager?
    weak var poolManager: SubAgentPoolManager?
    weak var concurrencyController: ConcurrencyController?
    weak var scheduler: TaskPriorityScheduler?

    // MARK: - Private State

    private var monitorTimer: Timer?

    // MARK: - Report Model

    struct SubAgentReport: Equatable {
        // Current counts
        var totalAgents: Int = 0
        var activeAgents: Int = 0
        var idleAgents: Int = 0
        var workingAgents: Int = 0
        var thinkingAgents: Int = 0
        var waitingAgents: Int = 0
        var completedAgents: Int = 0
        var errorAgents: Int = 0
        var suspendedAgents: Int = 0
        var pooledAgents: Int = 0
        var destroyingAgents: Int = 0

        // Pool stats
        var poolHitRate: Double = 0
        var poolUtilization: Double = 0
        var poolCapacity: Int = 0

        // Concurrency stats
        var currentConcurrency: Int = 0
        var effectiveConcurrencyLimit: Int = 0
        var queuedTaskCount: Int = 0

        // Scheduler stats
        var scheduledTaskCount: Int = 0
        var completedTaskCount: Int = 0
        var avgTaskWaitTime: TimeInterval = 0

        // Health indicators
        var idleRatio: Double = 0
        var utilizationRate: Double = 0
        var healthStatus: HealthStatus = .healthy

        // Resource pressure
        var resourcePressure: String = "Normal"

        /// Formatted summary string
        var summary: String {
            """
            Agents: \(totalAgents) total | \(activeAgents) active | \(idleAgents) idle | \(pooledAgents) pooled
            Concurrency: \(currentConcurrency)/\(effectiveConcurrencyLimit) | Queued: \(queuedTaskCount)
            Pool: \(poolHitRate.formatted(.percent)) hit rate | \(poolUtilization.formatted(.percent)) util
            Health: \(healthStatus.rawValue) | Pressure: \(resourcePressure)
            """
        }
    }

    enum HealthStatus: String, Equatable {
        case healthy = "Healthy"
        case warning = "Warning"
        case degraded = "Degraded"
        case critical = "Critical"
    }

    // MARK: - Snapshot

    struct SubAgentSnapshot: Identifiable, Equatable {
        let id: UUID = UUID()
        let timestamp: Date
        let activeCount: Int
        let idleCount: Int
        let pooledCount: Int
        let queuedCount: Int
        let concurrency: Int
    }

    // MARK: - Alert

    struct MonitorAlert: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let severity: AlertSeverity
        let message: String
        let agentIds: [UUID]

        enum AlertSeverity: String {
            case info
            case warning
            case critical
        }
    }

    // MARK: - Monitoring Lifecycle

    func startMonitoring() {
        guard config.isEnabled else { return }
        stopMonitoring()

        monitorTimer = Timer.scheduledTimer(withTimeInterval: config.snapshotInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.collectSnapshot()
            }
        }

        // Initial snapshot
        collectSnapshot()
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - Manual Refresh

    func refresh() {
        updateReport()
    }

    // MARK: - Snapshot Collection

    private func collectSnapshot() {
        updateReport()

        let snapshot = SubAgentSnapshot(
            timestamp: Date(),
            activeCount: report.activeAgents,
            idleCount: report.idleAgents,
            pooledCount: report.pooledAgents,
            queuedCount: report.queuedTaskCount,
            concurrency: report.currentConcurrency
        )

        snapshots.append(snapshot)
        if snapshots.count > config.maxSnapshots {
            snapshots.removeFirst(snapshots.count - config.maxSnapshots)
        }

        checkForAlerts()
    }

    // MARK: - Report Generation

    private func updateReport() {
        guard let lm = lifecycleManager else { return }

        let states = lm.agentStates

        var r = SubAgentReport()
        r.totalAgents = states.count

        // Single-pass state counting instead of 11 separate filter passes
        var nonTerminalCount = 0
        for state in states.values {
            switch state {
            case .working:
                r.workingAgents += 1
                r.activeAgents += 1
                nonTerminalCount += 1
            case .thinking:
                r.thinkingAgents += 1
                r.activeAgents += 1
                nonTerminalCount += 1
            case .requestingPermission, .waitingForAnswer, .reviewingPlan:
                r.waitingAgents += 1
                r.activeAgents += 1
                nonTerminalCount += 1
            case .idle:
                r.idleAgents += 1
                nonTerminalCount += 1
            case .completed:
                r.completedAgents += 1
                nonTerminalCount += 1
            case .error:
                r.errorAgents += 1
                nonTerminalCount += 1
            case .suspended, .suspendedIdle:
                r.suspendedAgents += 1
                nonTerminalCount += 1
            case .pooled:
                r.pooledAgents += 1
                nonTerminalCount += 1
            case .destroying:
                r.destroyingAgents += 1
            case .destroyed:
                break
            case .initializing:
                nonTerminalCount += 1
            }
        }

        // Pool stats
        if let pm = poolManager {
            r.poolHitRate = pm.stats.hitRate
            r.poolUtilization = pm.stats.utilizationRate
            r.poolCapacity = pm.config.maxPoolSize
        }

        // Concurrency stats
        if let cc = concurrencyController {
            r.currentConcurrency = cc.currentActiveCount
            r.effectiveConcurrencyLimit = cc.effectiveLimit
            r.queuedTaskCount = cc.currentQueuedCount
        }

        // Scheduler stats
        if let sched = scheduler {
            r.scheduledTaskCount = sched.schedulerStats.totalScheduled
            r.completedTaskCount = sched.schedulerStats.totalCompleted
            r.avgTaskWaitTime = sched.schedulerStats.avgWaitTime
        }

        // Health calculations
        r.idleRatio = nonTerminalCount > 0 ?
            Double(r.idleAgents + r.completedAgents + r.errorAgents) / Double(nonTerminalCount) : 0
        r.utilizationRate = nonTerminalCount > 0 ?
            Double(r.activeAgents) / Double(nonTerminalCount) : 0

        // Resource pressure from cleanup manager
        r.resourcePressure = lm.cleanupManager.resourcePressure.displayName

        // Determine health status
        r.healthStatus = determineHealth(report: r)

        report = r
    }

    private func determineHealth(report: SubAgentReport) -> HealthStatus {
        // Critical: too many idle agents with no work queued
        if report.idleAgents > config.idleAlertThreshold && report.queuedTaskCount == 0 && report.idleAgents > report.activeAgents {
            return .critical
        }
        // Degraded: high idle ratio
        if report.idleRatio > 0.7 && report.totalAgents > 2 {
            return .degraded
        }
        // Warning: some idle agents
        if report.idleRatio > 0.4 && report.totalAgents > 3 {
            return .warning
        }
        return .healthy
    }

    // MARK: - Alert Detection

    private func checkForAlerts() {
        guard let lm = lifecycleManager else { return }

        // Check for excessive idle agents
        let idleAgentIds = lm.agents(in: .idle)
        if idleAgentIds.count > config.idleAlertThreshold {
            let alert = MonitorAlert(
                timestamp: Date(),
                severity: .warning,
                message: "\(idleAgentIds.count) agents are idle with no tasks assigned",
                agentIds: idleAgentIds
            )
            addAlert(alert)
        }

        // Check for long-idle agents
        let longIdle = idleAgentIds.filter { agentId in
            lm.cleanupManager.idleDuration(for: agentId) > config.idleDurationAlertThreshold
        }
        if !longIdle.isEmpty {
            let alert = MonitorAlert(
                timestamp: Date(),
                severity: .critical,
                message: "\(longIdle.count) agents have been idle for over \(Int(config.idleDurationAlertThreshold))s",
                agentIds: longIdle
            )
            addAlert(alert)
        }

        // Check for agents stuck in completed state without cleanup
        let completedAgentIds = lm.agents(in: .completed)
        if completedAgentIds.count > 4 {
            let alert = MonitorAlert(
                timestamp: Date(),
                severity: .warning,
                message: "\(completedAgentIds.count) completed agents awaiting cleanup",
                agentIds: completedAgentIds
            )
            addAlert(alert)
        }
    }

    private func addAlert(_ alert: MonitorAlert) {
        // Deduplicate: don't add if same message in last 30 seconds
        let recent = alerts.filter {
            $0.message == alert.message &&
            Date().timeIntervalSince($0.timestamp) < 30
        }
        guard recent.isEmpty else { return }

        alerts.insert(alert, at: 0)
        // Keep only last 50 alerts
        if alerts.count > 50 {
            alerts = Array(alerts.prefix(50))
        }
    }

    // MARK: - Trend Analysis

    /// Returns the average idle count over the last N snapshots
    func averageIdleCount(over count: Int = 6) -> Double {
        let recent = snapshots.suffix(count)
        guard !recent.isEmpty else { return 0 }
        return Double(recent.map(\.idleCount).reduce(0, +)) / Double(recent.count)
    }

    /// Returns true if idle count is trending upward
    func isIdleTrendingUp(window: Int = 6) -> Bool {
        let recent = Array(snapshots.suffix(window))
        guard recent.count >= 3 else { return false }
        let firstHalf = recent.prefix(recent.count / 2)
        let secondHalf = recent.suffix(recent.count / 2)
        let firstAvg = Double(firstHalf.map(\.idleCount).reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.map(\.idleCount).reduce(0, +)) / Double(secondHalf.count)
        return secondAvg > firstAvg + 0.5
    }

    // MARK: - Cleanup

    func clearAlerts() {
        alerts.removeAll()
    }

    func clearSnapshots() {
        snapshots.removeAll()
    }

    func shutdown() {
        stopMonitoring()
        alerts.removeAll()
        snapshots.removeAll()
    }
}
