import XCTest
@testable import AgentCommand

@MainActor
final class LifecycleHealthCheckerTests: XCTestCase {

    var healthChecker: LifecycleHealthChecker!
    var lifecycleManager: AgentLifecycleManager!
    var poolManager: SubAgentPoolManager!
    var concurrencyController: ConcurrencyController!
    var monitor: SubAgentMonitor!

    override func setUp() {
        super.setUp()
        lifecycleManager = AgentLifecycleManager()
        lifecycleManager.initialize()
        poolManager = SubAgentPoolManager()
        concurrencyController = ConcurrencyController()
        monitor = SubAgentMonitor()

        healthChecker = LifecycleHealthChecker()
        healthChecker.lifecycleManager = lifecycleManager
        healthChecker.poolManager = poolManager
        healthChecker.concurrencyController = concurrencyController
        healthChecker.monitor = monitor
    }

    override func tearDown() {
        healthChecker.shutdown()
        lifecycleManager.shutdown()
        poolManager.shutdown()
        concurrencyController.reset()
        monitor.shutdown()
        healthChecker = nil
        lifecycleManager = nil
        poolManager = nil
        concurrencyController = nil
        monitor = nil
        super.tearDown()
    }

    // MARK: - Basic Health Check

    func testHealthCheck_EmptySystem_Healthy() {
        let report = healthChecker.runHealthCheck()
        XCTAssertEqual(report.overallStatus, .healthy)
        XCTAssertFalse(report.checks.isEmpty)
    }

    func testHealthCheck_ActiveAgents_Healthy() {
        lifecycleManager.registerAgent(UUID(), initialState: .working)
        lifecycleManager.registerAgent(UUID(), initialState: .thinking)

        let report = healthChecker.runHealthCheck()
        XCTAssertEqual(report.overallStatus, .healthy)
    }

    // MARK: - Metrics Collection

    func testMetrics_ReflectsAgentCounts() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        lifecycleManager.registerAgent(a1, initialState: .working)
        lifecycleManager.registerAgent(a2, initialState: .idle)
        lifecycleManager.registerAgent(a3, initialState: .suspended)

        let metrics = healthChecker.collectMetrics()
        XCTAssertEqual(metrics.totalAgents, 3)
        XCTAssertEqual(metrics.activeAgents, 1)
        XCTAssertEqual(metrics.idleAgents, 1)
        XCTAssertEqual(metrics.suspendedAgents, 1)
    }

    func testMetrics_IncludesMemoryUsage() {
        let metrics = healthChecker.collectMetrics()
        XCTAssertGreaterThanOrEqual(metrics.memoryUsageMB, 0)
    }

    func testMetrics_IncludesUptime() {
        let metrics = healthChecker.collectMetrics()
        XCTAssertGreaterThanOrEqual(metrics.uptimeSeconds, 0)
    }

    func testMetrics_PoolStats() {
        poolManager.config.maxPerRole = 5
        poolManager.config.maxPoolSize = 10

        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        poolManager.release(agent)
        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)
        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet) // miss

        let metrics = healthChecker.collectMetrics()
        XCTAssertEqual(metrics.poolHitRate, 0.5)
    }

    func testMetrics_ConcurrencyStats() {
        concurrencyController.onStartSubAgent = { _, _, _ in }
        let cmd = UUID()
        concurrencyController.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)

        let metrics = healthChecker.collectMetrics()
        XCTAssertEqual(metrics.currentConcurrency, 1)
        XCTAssertEqual(metrics.effectiveConcurrencyLimit, 6)
    }

    // MARK: - Resource Leak Detection

    func testResourceLeaks_ManyDestroyedAgents_Warning() {
        // Register 15 destroyed agents
        for _ in 0..<15 {
            lifecycleManager.registerAgent(UUID(), initialState: .destroyed)
        }

        let report = healthChecker.runHealthCheck()
        let leakCheck = report.checks.first { $0.name == "Resource Leaks" }
        XCTAssertNotNil(leakCheck)
        XCTAssertFalse(leakCheck!.passed)
    }

    func testResourceLeaks_FewDestroyedAgents_Passes() {
        for _ in 0..<3 {
            lifecycleManager.registerAgent(UUID(), initialState: .destroyed)
        }

        let report = healthChecker.runHealthCheck()
        let leakCheck = report.checks.first { $0.name == "Resource Leaks" }
        XCTAssertNotNil(leakCheck)
        XCTAssertTrue(leakCheck!.passed)
    }

    // MARK: - Orphaned Tracking

    func testOrphanedTracking_Clean_Passes() {
        let agentId = UUID()
        lifecycleManager.registerAgent(agentId, initialState: .idle)

        let report = healthChecker.runHealthCheck()
        let orphanCheck = report.checks.first { $0.name == "Orphaned Tracking" }
        XCTAssertNotNil(orphanCheck)
        XCTAssertTrue(orphanCheck!.passed)
    }

    // MARK: - Timer Consistency

    func testTimerConsistency_NormalOperation_Passes() {
        let a1 = UUID()
        lifecycleManager.registerAgent(a1, initialState: .idle)

        let report = healthChecker.runHealthCheck()
        let timerCheck = report.checks.first { $0.name == "Timer Consistency" }
        XCTAssertNotNil(timerCheck)
        XCTAssertTrue(timerCheck!.passed)
    }

    // MARK: - Pool Health

    func testPoolHealth_LowEviction_Passes() {
        let report = healthChecker.runHealthCheck()
        let poolCheck = report.checks.first { $0.name == "Pool Health" }
        XCTAssertNotNil(poolCheck)
        XCTAssertTrue(poolCheck!.passed)
    }

    // MARK: - Concurrency Health

    func testConcurrencyHealth_NoQueue_Passes() {
        let report = healthChecker.runHealthCheck()
        let concCheck = report.checks.first { $0.name == "Concurrency Health" }
        XCTAssertNotNil(concCheck)
        XCTAssertTrue(concCheck!.passed)
    }

    // MARK: - Logger Health

    func testLoggerHealth_LowInvalidRate_Passes() {
        let agentId = UUID()
        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)

        let report = healthChecker.runHealthCheck()
        let logCheck = report.checks.first { $0.name == "Logger Health" }
        XCTAssertNotNil(logCheck)
        XCTAssertTrue(logCheck!.passed)
    }

    // MARK: - Consecutive Failures

    func testConsecutiveFailures_ResetOnHealthy() {
        healthChecker.runHealthCheck()
        XCTAssertEqual(healthChecker.consecutiveFailures, 0)
    }

    // MARK: - Overall Status Determination

    func testOverallStatus_AllPassed_Healthy() {
        let report = healthChecker.runHealthCheck()
        XCTAssertEqual(report.overallStatus, .healthy)
    }

    // MARK: - Report Contains All Checks

    func testReportContainsAllChecks() {
        let report = healthChecker.runHealthCheck()
        let checkNames = Set(report.checks.map(\.name))

        XCTAssertTrue(checkNames.contains("Orphaned Tracking"))
        XCTAssertTrue(checkNames.contains("Stuck Agents"))
        XCTAssertTrue(checkNames.contains("Timer Consistency"))
        XCTAssertTrue(checkNames.contains("Memory Usage"))
        XCTAssertTrue(checkNames.contains("Pool Health"))
        XCTAssertTrue(checkNames.contains("Concurrency Health"))
        XCTAssertTrue(checkNames.contains("Logger Health"))
        XCTAssertTrue(checkNames.contains("Resource Leaks"))
    }

    // MARK: - No Dependencies (nil managers)

    func testHealthCheck_NoDependencies_Healthy() {
        let standalone = LifecycleHealthChecker()
        let report = standalone.runHealthCheck()
        XCTAssertEqual(report.overallStatus, .healthy)
    }

    // MARK: - Shutdown

    func testShutdown() {
        healthChecker.startChecking()
        healthChecker.shutdown()
        // No crash, timer stopped
        XCTAssertNotNil(healthChecker)
    }
}
