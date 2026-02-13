import XCTest
@testable import AgentCommand

// MARK: - AgentCleanupManager Tests

@MainActor
final class AgentCleanupManagerTests: XCTestCase {

    private var manager: AgentCleanupManager!
    private var logger: LifecycleLogger!

    override func setUp() {
        super.setUp()
        logger = LifecycleLogger()
        manager = AgentCleanupManager(logger: logger)
    }

    override func tearDown() {
        manager.shutdown()
        manager = nil
        logger = nil
        super.tearDown()
    }

    // MARK: - Idle Tracking

    func testAgentBecameIdle_TracksTime() {
        let agentId = UUID()
        manager.agentBecameIdle(agentId)

        XCTAssertNotNil(manager.idleTracking[agentId])
        XCTAssertNotNil(manager.lastActivityTimes[agentId])
        XCTAssertEqual(manager.trackedIdleAgentCount, 1)
    }

    func testAgentBecameActive_RemovesIdleTracking() {
        let agentId = UUID()
        manager.agentBecameIdle(agentId)
        XCTAssertEqual(manager.trackedIdleAgentCount, 1)

        manager.agentBecameActive(agentId)
        XCTAssertNil(manager.idleTracking[agentId])
        XCTAssertEqual(manager.trackedIdleAgentCount, 0)
        // lastActivityTimes should be updated, not removed
        XCTAssertNotNil(manager.lastActivityTimes[agentId])
    }

    func testAgentBecameActive_CancelsTimer() {
        let agentId = UUID()
        manager.agentBecameIdle(agentId)
        XCTAssertEqual(manager.pendingCleanupCount, 1)

        manager.agentBecameActive(agentId)
        XCTAssertEqual(manager.pendingCleanupCount, 0)
    }

    func testMultipleAgentsTracked() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        manager.agentBecameIdle(id1)
        manager.agentBecameIdle(id2)
        manager.agentBecameIdle(id3)

        XCTAssertEqual(manager.trackedIdleAgentCount, 3)
        XCTAssertEqual(manager.pendingCleanupCount, 3)

        manager.agentBecameActive(id2)
        XCTAssertEqual(manager.trackedIdleAgentCount, 2)
        XCTAssertEqual(manager.pendingCleanupCount, 2)
    }

    // MARK: - Idle Duration

    func testIdleDuration_NoTracking() {
        let duration = manager.idleDuration(for: UUID())
        XCTAssertEqual(duration, 0)
    }

    func testIdleDuration_TrackedAgent() {
        let agentId = UUID()
        manager.agentBecameIdle(agentId)
        // Duration should be very small (just created)
        let duration = manager.idleDuration(for: agentId)
        XCTAssertLessThan(duration, 1.0)
    }

    // MARK: - Activity Recording

    func testRecordActivity() {
        let agentId = UUID()
        manager.recordActivity(for: agentId)
        XCTAssertNotNil(manager.lastActivityTimes[agentId])
    }

    func testTimeSinceLastActivity_NoRecord() {
        let elapsed = manager.timeSinceLastActivity(for: UUID())
        XCTAssertEqual(elapsed, 0)
    }

    func testTimeSinceLastActivity_Recorded() {
        let agentId = UUID()
        manager.recordActivity(for: agentId)
        let elapsed = manager.timeSinceLastActivity(for: agentId)
        XCTAssertLessThan(elapsed, 1.0)
    }

    // MARK: - Resource Usage Recording

    func testRecordResourceUsage() {
        let agentId = UUID()
        manager.recordResourceUsage(for: agentId, cpuPercent: 45.0, memoryMB: 256)

        let snapshot = manager.agentResourceUsage[agentId]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.cpuPercent, 45.0)
        XCTAssertEqual(snapshot?.memoryMB, 256)
    }

    // MARK: - Team Cleanup Scheduling

    func testScheduleTeamCleanup_CreatesTimer() {
        let commanderId = UUID()
        manager.scheduleTeamCleanup(commanderId: commanderId, allCompleted: true)
        XCTAssertEqual(manager.pendingCleanupCount, 1)
    }

    func testCancelTeamCleanup() {
        let commanderId = UUID()
        manager.scheduleTeamCleanup(commanderId: commanderId, allCompleted: true)
        XCTAssertEqual(manager.pendingCleanupCount, 1)

        manager.cancelTeamCleanup(commanderId: commanderId)
        XCTAssertEqual(manager.pendingCleanupCount, 0)
    }

    func testScheduleTeamCleanup_ReplacesExistingTimer() {
        let commanderId = UUID()
        manager.scheduleTeamCleanup(commanderId: commanderId, allCompleted: true)
        manager.scheduleTeamCleanup(commanderId: commanderId, allCompleted: false)
        // Should still only have 1 timer (replaced, not accumulated)
        XCTAssertEqual(manager.pendingCleanupCount, 1)
    }

    // MARK: - Suspended Timeout

    func testScheduleSuspendedTimeout() {
        let agentId = UUID()
        manager.scheduleSuspendedTimeout(agentId)
        XCTAssertEqual(manager.pendingCleanupCount, 1)
    }

    // MARK: - Adjusted Timeout

    func testAdjustedTimeout_Normal() {
        let result = manager.adjustedTimeout(100.0)
        XCTAssertEqual(result, 100.0)
    }

    // MARK: - Remove Agent

    func testRemoveAgent_CleansUpAll() {
        let agentId = UUID()
        manager.agentBecameIdle(agentId)
        manager.recordResourceUsage(for: agentId, cpuPercent: 10, memoryMB: 100)
        XCTAssertEqual(manager.trackedIdleAgentCount, 1)

        manager.removeAgent(agentId)
        XCTAssertEqual(manager.trackedIdleAgentCount, 0)
        XCTAssertEqual(manager.pendingCleanupCount, 0)
        XCTAssertNil(manager.lastActivityTimes[agentId])
        XCTAssertNil(manager.agentResourceUsage[agentId])
    }

    // MARK: - Shutdown

    func testShutdown_ClearsAll() {
        let id1 = UUID()
        let id2 = UUID()
        manager.agentBecameIdle(id1)
        manager.agentBecameIdle(id2)
        manager.recordResourceUsage(for: id1, cpuPercent: 10, memoryMB: 100)

        manager.shutdown()

        XCTAssertEqual(manager.trackedIdleAgentCount, 0)
        XCTAssertEqual(manager.pendingCleanupCount, 0)
        XCTAssertTrue(manager.lastActivityTimes.isEmpty)
        XCTAssertTrue(manager.agentResourceUsage.isEmpty)
    }

    // MARK: - Memory Query

    func testCurrentMemoryUsageMB_ReturnsNonNegative() {
        let memoryMB = manager.currentMemoryUsageMB()
        XCTAssertGreaterThanOrEqual(memoryMB, 0)
    }

    // MARK: - Policy Changes

    func testPolicyChangeAffectsTimeouts() {
        manager.policy = .aggressive

        // Aggressive: idleAgentTimeout = 30, vs default 120
        let timeout = manager.adjustedTimeout(manager.policy.idleAgentTimeout)
        XCTAssertEqual(timeout, 30.0) // Normal pressure, no adjustment
    }

    // MARK: - Cancel All Timers

    func testCancelAllTimers() {
        manager.agentBecameIdle(UUID())
        manager.agentBecameIdle(UUID())
        manager.scheduleTeamCleanup(commanderId: UUID(), allCompleted: true)
        XCTAssertEqual(manager.pendingCleanupCount, 3)

        manager.cancelAllTimers()
        XCTAssertEqual(manager.pendingCleanupCount, 0)
    }
}
