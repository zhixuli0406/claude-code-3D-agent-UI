import Foundation
import Combine

/// Provides periodic health checks and monitoring metrics for the lifecycle management system.
/// Detects resource leaks, stuck agents, orphaned timers, and inconsistent state.
@MainActor
class LifecycleHealthChecker: ObservableObject {

    // MARK: - Health Report

    struct HealthReport: Equatable {
        let timestamp: Date
        let overallStatus: HealthStatus
        let checks: [CheckResult]
        let metrics: SystemMetrics

        enum HealthStatus: String, Equatable {
            case healthy
            case warning
            case degraded
            case critical
        }

        struct CheckResult: Equatable {
            let name: String
            let passed: Bool
            let message: String
            let severity: Severity

            enum Severity: Int, Equatable {
                case info = 0
                case warning = 1
                case error = 2
                case critical = 3
            }
        }

        struct SystemMetrics: Equatable {
            var totalAgents: Int = 0
            var activeAgents: Int = 0
            var idleAgents: Int = 0
            var pooledAgents: Int = 0
            var suspendedAgents: Int = 0
            var destroyedAgents: Int = 0
            var pendingTimers: Int = 0
            var trackedIdleCount: Int = 0
            var logEntryCount: Int = 0
            var totalTransitions: Int = 0
            var invalidTransitions: Int = 0
            var emergencyCleanups: Int = 0
            var memoryUsageMB: Int = 0
            var poolHitRate: Double = 0
            var poolUtilization: Double = 0
            var currentConcurrency: Int = 0
            var effectiveConcurrencyLimit: Int = 0
            var resourcePressure: String = "Normal"
            var uptimeSeconds: TimeInterval = 0
        }
    }

    // MARK: - Published State

    @Published private(set) var lastReport: HealthReport?
    @Published private(set) var consecutiveFailures: Int = 0

    // MARK: - Dependencies

    weak var lifecycleManager: AgentLifecycleManager?
    weak var poolManager: SubAgentPoolManager?
    weak var concurrencyController: ConcurrencyController?
    weak var monitor: SubAgentMonitor?

    // MARK: - Configuration

    var checkInterval: TimeInterval = 30.0
    var maxConsecutiveFailuresBeforeAlert: Int = 3

    // MARK: - Private State

    private var checkTimer: Timer?
    private let startTime = Date()

    // MARK: - Lifecycle

    func startChecking() {
        stopChecking()
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.runHealthCheck()
            }
        }
        // Run initial check
        runHealthCheck()
    }

    func stopChecking() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Run Health Check

    @discardableResult
    func runHealthCheck() -> HealthReport {
        var checks: [HealthReport.CheckResult] = []

        checks.append(checkOrphanedTracking())
        checks.append(checkStuckAgents())
        checks.append(checkTimerConsistency())
        checks.append(checkMemoryUsage())
        checks.append(checkPoolHealth())
        checks.append(checkConcurrencyHealth())
        checks.append(checkLoggerHealth())
        checks.append(checkResourceLeaks())

        let metrics = collectMetrics()
        let overallStatus = determineOverallStatus(checks: checks)

        let report = HealthReport(
            timestamp: Date(),
            overallStatus: overallStatus,
            checks: checks,
            metrics: metrics
        )

        lastReport = report

        if overallStatus == .critical || overallStatus == .degraded {
            consecutiveFailures += 1
        } else {
            consecutiveFailures = 0
        }

        #if DEBUG
        if overallStatus != .healthy {
            let failedChecks = checks.filter { !$0.passed }
            print("[HealthCheck] Status: \(overallStatus.rawValue) — \(failedChecks.count) issue(s)")
            for check in failedChecks {
                print("  [\(check.severity)] \(check.name): \(check.message)")
            }
        }
        #endif

        return report
    }

    // MARK: - Individual Checks

    /// Check for orphaned tracking entries (agents tracked in cleanup but not in lifecycle)
    private func checkOrphanedTracking() -> HealthReport.CheckResult {
        guard let lm = lifecycleManager else {
            return .init(name: "Orphaned Tracking", passed: true, message: "No lifecycle manager", severity: .info)
        }

        let registeredIds = Set(lm.agentStates.keys)
        let trackedIdle = Set(lm.cleanupManager.idleTracking.keys)
        let trackedActivity = Set(lm.cleanupManager.lastActivityTimes.keys)
        let trackedResource = Set(lm.cleanupManager.agentResourceUsage.keys)

        let orphanedIdle = trackedIdle.subtracting(registeredIds)
        let orphanedActivity = trackedActivity.subtracting(registeredIds)
        let orphanedResource = trackedResource.subtracting(registeredIds)

        let totalOrphaned = orphanedIdle.count + orphanedActivity.count + orphanedResource.count

        if totalOrphaned > 0 {
            return .init(
                name: "Orphaned Tracking",
                passed: false,
                message: "\(totalOrphaned) orphaned tracking entries (idle: \(orphanedIdle.count), activity: \(orphanedActivity.count), resource: \(orphanedResource.count))",
                severity: .warning
            )
        }
        return .init(name: "Orphaned Tracking", passed: true, message: "No orphaned entries", severity: .info)
    }

    /// Check for agents stuck in non-terminal states for too long
    private func checkStuckAgents() -> HealthReport.CheckResult {
        guard let lm = lifecycleManager else {
            return .init(name: "Stuck Agents", passed: true, message: "No lifecycle manager", severity: .info)
        }

        let stuckThreshold: TimeInterval = 600 // 10 minutes
        var stuckCount = 0

        for (agentId, state) in lm.agentStates {
            guard state == .destroying else { continue }
            let idleDuration = lm.cleanupManager.timeSinceLastActivity(for: agentId)
            if idleDuration > stuckThreshold {
                stuckCount += 1
            }
        }

        if stuckCount > 0 {
            return .init(
                name: "Stuck Agents",
                passed: false,
                message: "\(stuckCount) agent(s) stuck in destroying state for >10min",
                severity: .error
            )
        }
        return .init(name: "Stuck Agents", passed: true, message: "No stuck agents", severity: .info)
    }

    /// Check that cleanup timer count matches expectations
    private func checkTimerConsistency() -> HealthReport.CheckResult {
        guard let lm = lifecycleManager else {
            return .init(name: "Timer Consistency", passed: true, message: "No lifecycle manager", severity: .info)
        }

        let timerCount = lm.cleanupManager.pendingCleanupCount
        let idleCount = lm.cleanupManager.trackedIdleAgentCount
        let suspendedCount = lm.suspendedAgentCount

        // Timers should roughly correspond to idle + suspended agents
        // Allow some tolerance for race conditions
        let expectedMax = idleCount + suspendedCount + 10
        if timerCount > expectedMax {
            return .init(
                name: "Timer Consistency",
                passed: false,
                message: "Timers (\(timerCount)) exceed expected max (\(expectedMax))",
                severity: .warning
            )
        }
        return .init(name: "Timer Consistency", passed: true, message: "\(timerCount) timers active", severity: .info)
    }

    /// Check memory usage
    private func checkMemoryUsage() -> HealthReport.CheckResult {
        guard let lm = lifecycleManager else {
            return .init(name: "Memory Usage", passed: true, message: "No lifecycle manager", severity: .info)
        }

        let memMB = lm.cleanupManager.currentMemoryUsageMB()
        let policy = lm.cleanupManager.policy

        if memMB > policy.memoryCriticalThresholdMB {
            return .init(
                name: "Memory Usage",
                passed: false,
                message: "\(memMB)MB exceeds critical threshold (\(policy.memoryCriticalThresholdMB)MB)",
                severity: .critical
            )
        }
        if memMB > policy.memoryWarningThresholdMB {
            return .init(
                name: "Memory Usage",
                passed: false,
                message: "\(memMB)MB exceeds warning threshold (\(policy.memoryWarningThresholdMB)MB)",
                severity: .warning
            )
        }
        return .init(name: "Memory Usage", passed: true, message: "\(memMB)MB", severity: .info)
    }

    /// Check pool health
    private func checkPoolHealth() -> HealthReport.CheckResult {
        guard let pm = poolManager else {
            return .init(name: "Pool Health", passed: true, message: "No pool manager", severity: .info)
        }

        let hitRate = pm.stats.hitRate
        let evictionCount = pm.stats.evictionCount

        if evictionCount > 50 && hitRate < 0.1 {
            return .init(
                name: "Pool Health",
                passed: false,
                message: "High eviction (\(evictionCount)) with low hit rate (\(String(format: "%.1f%%", hitRate * 100)))",
                severity: .warning
            )
        }
        return .init(name: "Pool Health", passed: true, message: "Hit rate: \(String(format: "%.1f%%", hitRate * 100))", severity: .info)
    }

    /// Check concurrency health
    private func checkConcurrencyHealth() -> HealthReport.CheckResult {
        guard let cc = concurrencyController else {
            return .init(name: "Concurrency Health", passed: true, message: "No concurrency controller", severity: .info)
        }

        let queuedCount = cc.currentQueuedCount
        if queuedCount > 20 {
            return .init(
                name: "Concurrency Health",
                passed: false,
                message: "\(queuedCount) tasks queued (potential bottleneck)",
                severity: .warning
            )
        }
        return .init(
            name: "Concurrency Health",
            passed: true,
            message: "\(cc.currentActiveCount)/\(cc.effectiveLimit) active, \(queuedCount) queued",
            severity: .info
        )
    }

    /// Check logger health (entry count within bounds)
    private func checkLoggerHealth() -> HealthReport.CheckResult {
        guard let lm = lifecycleManager else {
            return .init(name: "Logger Health", passed: true, message: "No lifecycle manager", severity: .info)
        }

        let invalidRate: Double
        if lm.logger.metrics.totalTransitions > 0 {
            invalidRate = Double(lm.logger.metrics.invalidTransitions) / Double(lm.logger.metrics.totalTransitions)
        } else {
            invalidRate = 0
        }

        if invalidRate > 0.1 && lm.logger.metrics.totalTransitions > 10 {
            return .init(
                name: "Logger Health",
                passed: false,
                message: "High invalid transition rate: \(String(format: "%.1f%%", invalidRate * 100))",
                severity: .warning
            )
        }
        return .init(
            name: "Logger Health",
            passed: true,
            message: "\(lm.logger.entries.count) entries, \(lm.logger.metrics.totalTransitions) transitions",
            severity: .info
        )
    }

    /// Check for potential resource leaks (destroyed agents still tracked)
    private func checkResourceLeaks() -> HealthReport.CheckResult {
        guard let lm = lifecycleManager else {
            return .init(name: "Resource Leaks", passed: true, message: "No lifecycle manager", severity: .info)
        }

        let destroyedCount = lm.agentStates.values.filter { $0 == .destroyed }.count

        // Destroyed agents should be unregistered promptly
        if destroyedCount > 10 {
            return .init(
                name: "Resource Leaks",
                passed: false,
                message: "\(destroyedCount) destroyed agents still in state tracking",
                severity: .warning
            )
        }
        return .init(name: "Resource Leaks", passed: true, message: "\(destroyedCount) destroyed in tracking", severity: .info)
    }

    // MARK: - Metrics Collection

    func collectMetrics() -> HealthReport.SystemMetrics {
        var m = HealthReport.SystemMetrics()

        if let lm = lifecycleManager {
            m.totalAgents = lm.totalManagedAgents
            m.activeAgents = lm.activeAgentCount
            m.idleAgents = lm.idleAgentCount
            m.suspendedAgents = lm.suspendedAgentCount
            m.destroyedAgents = lm.agentStates.values.filter { $0 == .destroyed }.count
            m.pooledAgents = lm.agents(in: .pooled).count
            m.pendingTimers = lm.cleanupManager.pendingCleanupCount
            m.trackedIdleCount = lm.cleanupManager.trackedIdleAgentCount
            m.logEntryCount = lm.logger.entries.count
            m.totalTransitions = lm.logger.metrics.totalTransitions
            m.invalidTransitions = lm.logger.metrics.invalidTransitions
            m.emergencyCleanups = lm.logger.metrics.emergencyCleanups
            m.memoryUsageMB = lm.cleanupManager.currentMemoryUsageMB()
            m.resourcePressure = lm.cleanupManager.resourcePressure.displayName
        }

        if let pm = poolManager {
            m.poolHitRate = pm.stats.hitRate
            m.poolUtilization = pm.stats.utilizationRate
        }

        if let cc = concurrencyController {
            m.currentConcurrency = cc.currentActiveCount
            m.effectiveConcurrencyLimit = cc.effectiveLimit
        }

        m.uptimeSeconds = Date().timeIntervalSince(startTime)

        return m
    }

    // MARK: - Overall Status

    private func determineOverallStatus(checks: [HealthReport.CheckResult]) -> HealthReport.HealthStatus {
        let maxSeverity = checks.filter { !$0.passed }.map(\.severity.rawValue).max() ?? 0

        switch maxSeverity {
        case 3: return .critical
        case 2: return .degraded
        case 1: return .warning
        default: return .healthy
        }
    }

    // MARK: - Cleanup

    func shutdown() {
        stopChecking()
    }
}
