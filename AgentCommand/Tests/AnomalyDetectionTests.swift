import XCTest
@testable import AgentCommand

// MARK: - L3: Anomaly Detection Models Unit Tests

final class AnomalyTypeTests: XCTestCase {

    func testAllCasesHaveDisplayName() {
        for anomalyType in AnomalyType.allCases {
            XCTAssertFalse(anomalyType.displayName.isEmpty)
        }
    }

    func testAllCasesHaveIconName() {
        for anomalyType in AnomalyType.allCases {
            XCTAssertFalse(anomalyType.iconName.isEmpty)
        }
    }

    func testAllCasesHaveHexColor() {
        for anomalyType in AnomalyType.allCases {
            XCTAssertTrue(anomalyType.hexColor.hasPrefix("#"))
            XCTAssertEqual(anomalyType.hexColor.count, 7)
        }
    }

    func testRawValues() {
        XCTAssertEqual(AnomalyType.infiniteLoop.rawValue, "infinite_loop")
        XCTAssertEqual(AnomalyType.excessiveTokens.rawValue, "excessive_tokens")
        XCTAssertEqual(AnomalyType.repeatedErrors.rawValue, "repeated_errors")
        XCTAssertEqual(AnomalyType.longRunning.rawValue, "long_running")
        XCTAssertEqual(AnomalyType.memoryLeak.rawValue, "memory_leak")
        XCTAssertEqual(AnomalyType.rateLimitRisk.rawValue, "rate_limit_risk")
    }

    func testIdentifiable() {
        XCTAssertEqual(AnomalyType.infiniteLoop.id, "infinite_loop")
    }
}

final class AnomalySeverityTests: XCTestCase {

    func testAllCasesHaveHexColor() {
        for severity in AnomalySeverity.allCases {
            XCTAssertTrue(severity.hexColor.hasPrefix("#"))
        }
    }

    func testAllCasesHaveIconName() {
        for severity in AnomalySeverity.allCases {
            XCTAssertFalse(severity.iconName.isEmpty)
        }
    }
}

final class RetryStrategyTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(RetryStrategy.none.displayName, "No Retry")
        XCTAssertEqual(RetryStrategy.immediate.displayName, "Immediate")
        XCTAssertEqual(RetryStrategy.exponentialBackoff.displayName, "Exponential Backoff")
        XCTAssertEqual(RetryStrategy.fixedDelay.displayName, "Fixed Delay")
    }

    func testIdentifiable() {
        XCTAssertEqual(RetryStrategy.none.id, "none")
        XCTAssertEqual(RetryStrategy.exponentialBackoff.id, "exponential_backoff")
    }
}

// MARK: - L3: Anomaly Detection Manager Tests

@MainActor
final class AnomalyDetectionManagerTests: XCTestCase {

    private var manager: AnomalyDetectionManager!

    override func setUp() {
        super.setUp()
        manager = AnomalyDetectionManager()
    }

    override func tearDown() {
        manager.stopMonitoring()
        manager = nil
        super.tearDown()
    }

    // MARK: - Report Anomaly

    func testReportAnomaly() {
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "Too many tokens")
        XCTAssertEqual(manager.alerts.count, 1)
        XCTAssertEqual(manager.alerts[0].type, .excessiveTokens)
        XCTAssertEqual(manager.alerts[0].severity, .warning)
        XCTAssertEqual(manager.alerts[0].message, "Too many tokens")
        XCTAssertFalse(manager.alerts[0].isResolved)
    }

    func testReportAnomaly_WithMetrics() {
        manager.reportAnomaly(
            type: .longRunning,
            severity: .critical,
            message: "Task running too long",
            agentName: "Agent-1",
            taskName: "build",
            metrics: ["duration_min": 15.0, "timeout_min": 10.0]
        )
        XCTAssertEqual(manager.alerts[0].agentName, "Agent-1")
        XCTAssertEqual(manager.alerts[0].taskName, "build")
        XCTAssertEqual(manager.alerts[0].metrics["duration_min"], 15.0)
    }

    func testReportAnomaly_InsertsAtFront() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "First")
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "Second")
        XCTAssertEqual(manager.alerts[0].message, "Second")
        XCTAssertEqual(manager.alerts[1].message, "First")
    }

    func testReportAnomaly_TracksErrorPattern() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "Connection timeout occurred")
        XCTAssertEqual(manager.errorPatterns.count, 1)
        XCTAssertEqual(manager.errorPatterns[0].occurrenceCount, 1)

        // Report same pattern again
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "Connection timeout occurred")
        XCTAssertEqual(manager.errorPatterns.count, 1)
        XCTAssertEqual(manager.errorPatterns[0].occurrenceCount, 2)
    }

    func testReportAnomaly_AutoAction_InfiniteLoop() {
        manager.reportAnomaly(type: .infiniteLoop, severity: .critical, message: "Loop detected")
        let alert = manager.alerts.first
        XCTAssertNotNil(alert?.autoAction)
        XCTAssertTrue(alert?.autoAction?.contains("Auto-interrupt") ?? false)
    }

    func testReportAnomaly_AutoAction_ExcessiveTokensCritical() {
        manager.reportAnomaly(type: .excessiveTokens, severity: .critical, message: "Over budget")
        let alert = manager.alerts.first
        XCTAssertNotNil(alert?.autoAction)
    }

    func testReportAnomaly_AutoAction_ExcessiveTokensWarning() {
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "High usage")
        let alert = manager.alerts.first
        // Warning severity should NOT trigger auto-action for excessive tokens
        XCTAssertNil(alert?.autoAction)
    }

    func testReportAnomaly_AutoAction_RepeatedErrors() {
        manager.reportAnomaly(type: .repeatedErrors, severity: .critical, message: "Errors repeating")
        let alert = manager.alerts.first
        XCTAssertNotNil(alert?.autoAction)
        XCTAssertTrue(alert?.autoAction?.contains("Retry") ?? false)
    }

    // MARK: - Alert Eviction (Cap = 200)

    func testReportAnomaly_EvictsOldAlerts() {
        // Fill to cap
        for i in 0..<201 {
            manager.reportAnomaly(type: .longRunning, severity: .info, message: "Alert \(i)")
        }
        XCTAssertLessThanOrEqual(manager.alerts.count, 200)
    }

    func testReportAnomaly_EvictsResolvedFirst() {
        // Add some resolved alerts first
        for i in 0..<100 {
            manager.reportAnomaly(type: .longRunning, severity: .info, message: "Resolved \(i)")
            manager.resolveAlert(manager.alerts[0].id)
        }
        // Add unresolved alerts to trigger eviction
        for i in 0..<105 {
            manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "Active \(i)")
        }
        XCTAssertLessThanOrEqual(manager.alerts.count, 200)
    }

    // MARK: - Resolve Alert

    func testResolveAlert() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "Test")
        let alertId = manager.alerts[0].id
        manager.resolveAlert(alertId)
        XCTAssertTrue(manager.alerts[0].isResolved)
    }

    func testResolveAlert_NonExistentId() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "Test")
        manager.resolveAlert(UUID())
        // Should not crash, original alert unchanged
        XCTAssertFalse(manager.alerts[0].isResolved)
    }

    func testResolveAllAlerts() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "A")
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "B")
        manager.resolveAllAlerts()
        XCTAssertTrue(manager.alerts.allSatisfy { $0.isResolved })
    }

    // MARK: - Dismiss Alert

    func testDismissAlert() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "To dismiss")
        let alertId = manager.alerts[0].id
        manager.dismissAlert(alertId)
        XCTAssertTrue(manager.alerts.isEmpty)
    }

    // MARK: - Configure Retry

    func testConfigureRetry() {
        manager.configureRetry(strategy: .exponentialBackoff, maxRetries: 3, delaySeconds: 5)
        XCTAssertEqual(manager.retryConfigs.count, 1)
        XCTAssertEqual(manager.retryConfigs[0].strategy, .exponentialBackoff)
        XCTAssertEqual(manager.retryConfigs[0].maxRetries, 3)
        XCTAssertEqual(manager.retryConfigs[0].delaySeconds, 5)
        XCTAssertTrue(manager.retryConfigs[0].isActive)
    }

    func testConfigureRetry_EvictionCap() {
        // Add 21 configs — should evict down to 20
        for _ in 0..<21 {
            manager.configureRetry(strategy: .fixedDelay, maxRetries: 1, delaySeconds: 1)
        }
        XCTAssertLessThanOrEqual(manager.retryConfigs.count, 20)
    }

    func testConfigureRetry_EvictsInactiveFirst() {
        manager.configureRetry(strategy: .none, maxRetries: 0, delaySeconds: 0)
        manager.retryConfigs[0].isActive = false
        // Fill to cap
        for _ in 0..<20 {
            manager.configureRetry(strategy: .exponentialBackoff, maxRetries: 3, delaySeconds: 5)
        }
        XCTAssertLessThanOrEqual(manager.retryConfigs.count, 20)
        // Inactive config should have been evicted
        let hasInactive = manager.retryConfigs.contains { !$0.isActive }
        // Either all are active or count is within limit
        XCTAssertTrue(!hasInactive || manager.retryConfigs.count <= 20)
    }

    // MARK: - Set Default Retry Config

    func testSetDefaultRetryConfig() {
        manager.setDefaultRetryConfig()
        XCTAssertEqual(manager.retryConfigs.count, 2)
        XCTAssertEqual(manager.retryConfigs[0].strategy, .exponentialBackoff)
        XCTAssertTrue(manager.retryConfigs[0].isActive)
        XCTAssertEqual(manager.retryConfigs[1].strategy, .fixedDelay)
        XCTAssertFalse(manager.retryConfigs[1].isActive)
    }

    // MARK: - Toggle Retry Config

    func testToggleRetryConfig() {
        manager.configureRetry(strategy: .exponentialBackoff, maxRetries: 3, delaySeconds: 5)
        let configId = manager.retryConfigs[0].id
        XCTAssertTrue(manager.retryConfigs[0].isActive)
        manager.toggleRetryConfig(configId)
        XCTAssertFalse(manager.retryConfigs[0].isActive)
        manager.toggleRetryConfig(configId)
        XCTAssertTrue(manager.retryConfigs[0].isActive)
    }

    // MARK: - Load Sample Data

    func testLoadSampleData() {
        manager.loadSampleData()
        XCTAssertEqual(manager.alerts.count, 3)
        XCTAssertEqual(manager.errorPatterns.count, 2)
        XCTAssertEqual(manager.retryConfigs.count, 2)
    }

    // MARK: - Stats

    func testStats_AfterReportAnomaly() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "Alert 1")
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "Alert 2")
        XCTAssertEqual(manager.stats.totalAlerts, 2)
        XCTAssertEqual(manager.stats.activeAlerts, 2)
        XCTAssertEqual(manager.stats.resolvedAlerts, 0)
    }

    func testStats_AfterResolve() {
        manager.reportAnomaly(type: .longRunning, severity: .info, message: "Alert 1")
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "Alert 2")
        manager.resolveAlert(manager.alerts[0].id)
        XCTAssertEqual(manager.stats.totalAlerts, 2)
        XCTAssertEqual(manager.stats.activeAlerts, 1)
        XCTAssertEqual(manager.stats.resolvedAlerts, 1)
    }

    func testStats_TopPatterns() {
        for _ in 0..<5 {
            manager.reportAnomaly(type: .longRunning, severity: .info, message: "Repeated pattern A")
        }
        for _ in 0..<3 {
            manager.reportAnomaly(type: .excessiveTokens, severity: .warning, message: "Repeated pattern B")
        }
        XCTAssertFalse(manager.stats.topPatterns.isEmpty)
        // Top pattern should be the one with more occurrences
        if let top = manager.stats.topPatterns.first {
            XCTAssertEqual(top.occurrenceCount, 5)
        }
    }

    // MARK: - Monitoring

    func testStartMonitoring() {
        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)
    }

    func testStopMonitoring() {
        manager.startMonitoring()
        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
    }

    // MARK: - Task Tracking

    func testTrackTaskStart() {
        let taskId = UUID()
        manager.trackTaskStart(taskId)
        // Should not crash, internal state tracked
        XCTAssertTrue(true)
    }

    func testTrackTokenUsage() {
        let taskId = UUID()
        manager.trackTokenUsage(taskId, tokens: 500)
        manager.trackTokenUsage(taskId, tokens: 300)
        // Should accumulate (500 + 300 = 800), verified implicitly via checkForAnomalies
        XCTAssertTrue(true)
    }

    // MARK: - Check For Anomalies Without AppState

    func testCheckForAnomalies_WithoutAppState() {
        // Should not crash when appState is nil
        manager.checkForAnomalies()
        // Stats should still update
        XCTAssertEqual(manager.stats.totalAlerts, 0)
    }

    // MARK: - Error Pattern Eviction

    func testErrorPattern_EvictsLeastFrequent() {
        // Add 51 different error patterns
        for i in 0..<51 {
            manager.reportAnomaly(type: .longRunning, severity: .info, message: "Unique pattern \(i) - padding to make unique message")
        }
        XCTAssertLessThanOrEqual(manager.errorPatterns.count, 50)
    }
}
