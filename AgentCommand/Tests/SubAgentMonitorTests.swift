import XCTest
@testable import AgentCommand

@MainActor
final class SubAgentMonitorTests: XCTestCase {

    var monitor: SubAgentMonitor!
    var lifecycleManager: AgentLifecycleManager!
    var poolManager: SubAgentPoolManager!
    var concurrencyController: ConcurrencyController!
    var scheduler: TaskPriorityScheduler!

    override func setUp() {
        super.setUp()
        lifecycleManager = AgentLifecycleManager()
        lifecycleManager.initialize()
        poolManager = SubAgentPoolManager()
        concurrencyController = ConcurrencyController()
        scheduler = TaskPriorityScheduler()

        monitor = SubAgentMonitor()
        monitor.lifecycleManager = lifecycleManager
        monitor.poolManager = poolManager
        monitor.concurrencyController = concurrencyController
        monitor.scheduler = scheduler
        monitor.config.isEnabled = false // don't start timer in tests
    }

    override func tearDown() {
        monitor.shutdown()
        lifecycleManager.shutdown()
        poolManager.shutdown()
        concurrencyController.reset()
        monitor = nil
        lifecycleManager = nil
        poolManager = nil
        concurrencyController = nil
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(monitor.report.totalAgents, 0)
        XCTAssertTrue(monitor.alerts.isEmpty)
        XCTAssertTrue(monitor.snapshots.isEmpty)
    }

    // MARK: - Report Generation

    func testRefresh_EmptySystem() {
        monitor.refresh()

        XCTAssertEqual(monitor.report.totalAgents, 0)
        XCTAssertEqual(monitor.report.activeAgents, 0)
        XCTAssertEqual(monitor.report.idleAgents, 0)
        XCTAssertEqual(monitor.report.healthStatus, .healthy)
    }

    func testRefresh_WithAgents() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()

        lifecycleManager.registerAgent(a1, initialState: .working)
        lifecycleManager.registerAgent(a2, initialState: .idle)
        lifecycleManager.registerAgent(a3, initialState: .completed)

        monitor.refresh()

        XCTAssertEqual(monitor.report.totalAgents, 3)
        XCTAssertEqual(monitor.report.activeAgents, 1)
        XCTAssertEqual(monitor.report.idleAgents, 1)
        XCTAssertEqual(monitor.report.completedAgents, 1)
        XCTAssertEqual(monitor.report.workingAgents, 1)
    }

    func testRefresh_PoolStats() {
        poolManager.config.maxPerRole = 5
        poolManager.config.maxPoolSize = 10

        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        poolManager.release(agent)
        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)
        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet) // miss

        monitor.refresh()

        XCTAssertEqual(monitor.report.poolHitRate, 0.5)
    }

    func testRefresh_ConcurrencyStats() {
        concurrencyController.onStartSubAgent = { _, _, _ in }

        let cmd = UUID()
        concurrencyController.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        concurrencyController.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet)

        monitor.refresh()

        XCTAssertEqual(monitor.report.currentConcurrency, 2)
        XCTAssertEqual(monitor.report.effectiveConcurrencyLimit, 6)
    }

    // MARK: - Health Status

    func testHealthStatus_Healthy() {
        let a1 = UUID()
        lifecycleManager.registerAgent(a1, initialState: .working)

        monitor.refresh()
        XCTAssertEqual(monitor.report.healthStatus, .healthy)
    }

    func testHealthStatus_Warning_HighIdleRatio() {
        // 4 agents, 3 idle, 1 working → idle ratio ~0.75
        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        lifecycleManager.registerAgent(UUID(), initialState: .working)

        monitor.refresh()
        // idle ratio = 3/4 = 0.75 > 0.4
        XCTAssertNotEqual(monitor.report.healthStatus, .healthy)
    }

    func testHealthStatus_Critical_ManyIdleNoWork() {
        monitor.config.idleAlertThreshold = 2

        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)

        // No queued tasks, all idle
        monitor.refresh()
        XCTAssertEqual(monitor.report.healthStatus, .critical)
    }

    // MARK: - Snapshots

    func testSnapshots() {
        lifecycleManager.registerAgent(UUID(), initialState: .working)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)

        monitor.startMonitoring()

        // Manual collection (since timer-based collection won't fire in sync test)
        monitor.refresh()

        // Snapshots only collected by collectSnapshot (called by timer or startMonitoring)
        // Let's test manual approach
        monitor.config.isEnabled = true
        monitor.stopMonitoring()

        XCTAssertEqual(monitor.snapshots.count, 0) // refresh doesn't add snapshots

        // startMonitoring does initial snapshot
        monitor.startMonitoring()
        XCTAssertEqual(monitor.snapshots.count, 1)
        XCTAssertEqual(monitor.snapshots[0].activeCount, 1)
        XCTAssertEqual(monitor.snapshots[0].idleCount, 1)

        monitor.stopMonitoring()
    }

    func testSnapshots_MaxLimit() {
        monitor.config.maxSnapshots = 3
        monitor.config.isEnabled = true

        for _ in 0..<5 {
            monitor.startMonitoring() // each call adds a snapshot
            monitor.stopMonitoring()
        }

        XCTAssertLessThanOrEqual(monitor.snapshots.count, 3)
    }

    // MARK: - Trend Analysis

    func testAverageIdleCount() {
        XCTAssertEqual(monitor.averageIdleCount(), 0) // no snapshots
    }

    func testIsIdleTrendingUp() {
        XCTAssertFalse(monitor.isIdleTrendingUp()) // not enough data
    }

    // MARK: - Report Summary

    func testReportSummary() {
        lifecycleManager.registerAgent(UUID(), initialState: .working)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)

        monitor.refresh()

        let summary = monitor.report.summary
        XCTAssertTrue(summary.contains("Agents:"))
        XCTAssertTrue(summary.contains("Concurrency:"))
        XCTAssertTrue(summary.contains("Health:"))
    }

    // MARK: - Cleanup

    func testClearAlerts() {
        monitor.clearAlerts()
        XCTAssertTrue(monitor.alerts.isEmpty)
    }

    func testClearSnapshots() {
        monitor.config.isEnabled = true
        monitor.startMonitoring()
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.snapshots.isEmpty)

        monitor.clearSnapshots()
        XCTAssertTrue(monitor.snapshots.isEmpty)
    }

    func testShutdown() {
        monitor.config.isEnabled = true
        monitor.startMonitoring()
        monitor.shutdown()
        XCTAssertTrue(monitor.alerts.isEmpty)
        XCTAssertTrue(monitor.snapshots.isEmpty)
    }

    // MARK: - Resource Pressure Display

    func testResourcePressureInReport() {
        lifecycleManager.registerAgent(UUID(), initialState: .idle)
        monitor.refresh()
        XCTAssertEqual(monitor.report.resourcePressure, "Normal")
    }

    // MARK: - Utilization Rate

    func testUtilizationRate() {
        lifecycleManager.registerAgent(UUID(), initialState: .working)
        lifecycleManager.registerAgent(UUID(), initialState: .working)
        lifecycleManager.registerAgent(UUID(), initialState: .idle)

        monitor.refresh()

        // 2 active out of 3 non-terminal = ~0.67
        XCTAssertGreaterThan(monitor.report.utilizationRate, 0.6)
        XCTAssertLessThan(monitor.report.utilizationRate, 0.7)
    }
}
