import XCTest
@testable import AgentCommand

// MARK: - LifecycleLogger Tests

@MainActor
final class LifecycleLoggerTests: XCTestCase {

    private var logger: LifecycleLogger!

    override func setUp() {
        super.setUp()
        logger = LifecycleLogger(maxEntries: 100)
    }

    override func tearDown() {
        logger = nil
        super.tearDown()
    }

    // MARK: - Log Transition

    func testLogTransition() {
        let agentId = UUID()
        logger.logTransition(
            agentId: agentId,
            agentName: "TestBot",
            from: .idle,
            to: .working,
            event: .assignTask
        )

        XCTAssertEqual(logger.entries.count, 1)

        let entry = logger.entries[0]
        XCTAssertEqual(entry.agentId, agentId)
        XCTAssertEqual(entry.agentName, "TestBot")
        XCTAssertEqual(entry.fromState, .idle)
        XCTAssertEqual(entry.toState, .working)
        XCTAssertEqual(entry.event, .assignTask)
        XCTAssertNil(entry.message)
    }

    func testLogTransition_WithMessage() {
        let agentId = UUID()
        logger.logTransition(
            agentId: agentId,
            from: .working,
            to: .completed,
            event: .taskCompleted,
            message: "Exit code 0"
        )

        XCTAssertEqual(logger.entries[0].message, "Exit code 0")
    }

    func testLogTransition_UpdatesMetrics() {
        let agentId = UUID()
        logger.logTransition(agentId: agentId, from: .idle, to: .working, event: .assignTask)
        logger.logTransition(agentId: agentId, from: .working, to: .completed, event: .taskCompleted)

        XCTAssertEqual(logger.metrics.totalTransitions, 2)
        XCTAssertEqual(logger.metrics.transitionsPerState[.working], 1)
        XCTAssertEqual(logger.metrics.transitionsPerState[.completed], 1)
    }

    // MARK: - Log Invalid Transition

    func testLogInvalidTransition() {
        let agentId = UUID()
        logger.logInvalidTransition(
            agentId: agentId,
            agentName: "BadBot",
            currentState: .idle,
            event: .taskCompleted,
            reason: "Not in working state"
        )

        XCTAssertEqual(logger.entries.count, 1)
        XCTAssertEqual(logger.metrics.invalidTransitions, 1)

        let entry = logger.entries[0]
        XCTAssertEqual(entry.fromState, .idle)
        XCTAssertEqual(entry.toState, .idle) // Stays the same
        XCTAssertTrue(entry.message?.contains("INVALID") ?? false)
    }

    // MARK: - Emergency Cleanup Logging

    func testLogEmergencyCleanup() {
        logger.logEmergencyCleanup(agentCount: 5, reason: "Critical memory")
        XCTAssertEqual(logger.metrics.emergencyCleanups, 1)
    }

    // MARK: - Query

    func testEntriesForAgent() {
        let agent1 = UUID()
        let agent2 = UUID()

        logger.logTransition(agentId: agent1, from: .idle, to: .working, event: .assignTask)
        logger.logTransition(agentId: agent2, from: .idle, to: .working, event: .assignTask)
        logger.logTransition(agentId: agent1, from: .working, to: .completed, event: .taskCompleted)

        let agent1Entries = logger.entries(for: agent1)
        XCTAssertEqual(agent1Entries.count, 2)

        let agent2Entries = logger.entries(for: agent2)
        XCTAssertEqual(agent2Entries.count, 1)
    }

    func testRecentEntries() {
        for i in 0..<10 {
            logger.logTransition(
                agentId: UUID(),
                from: .idle,
                to: .working,
                event: .assignTask,
                message: "Entry \(i)"
            )
        }

        let recent = logger.recentEntries(count: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent[0].message, "Entry 7")
        XCTAssertEqual(recent[2].message, "Entry 9")
    }

    func testRecentEntries_LessThanRequested() {
        logger.logTransition(agentId: UUID(), from: .idle, to: .working, event: .assignTask)
        let recent = logger.recentEntries(count: 50)
        XCTAssertEqual(recent.count, 1)
    }

    // MARK: - Max Entries Limit

    func testMaxEntriesEviction() {
        let smallLogger = LifecycleLogger(maxEntries: 5)

        for i in 0..<10 {
            smallLogger.logTransition(
                agentId: UUID(),
                from: .idle,
                to: .working,
                event: .assignTask,
                message: "Entry \(i)"
            )
        }

        // Batch eviction removes overflow + 20% extra to amortize cost
        XCTAssertLessThanOrEqual(smallLogger.entries.count, 5)
        XCTAssertGreaterThan(smallLogger.entries.count, 0)
        // Most recent entry should always be the last one logged
        XCTAssertEqual(smallLogger.entries.last?.message, "Entry 9")
    }

    // MARK: - Clear

    func testClear() {
        logger.logTransition(agentId: UUID(), from: .idle, to: .working, event: .assignTask)
        logger.logInvalidTransition(agentId: UUID(), currentState: .idle, event: .taskCompleted)
        logger.logEmergencyCleanup(agentCount: 1, reason: "test")

        logger.clear()

        XCTAssertTrue(logger.entries.isEmpty)
        XCTAssertEqual(logger.metrics.totalTransitions, 0)
        XCTAssertEqual(logger.metrics.invalidTransitions, 0)
        XCTAssertEqual(logger.metrics.emergencyCleanups, 0)
    }

    // MARK: - LogEntry Properties

    func testLogEntry_HasUniqueId() {
        logger.logTransition(agentId: UUID(), from: .idle, to: .working, event: .assignTask)
        logger.logTransition(agentId: UUID(), from: .idle, to: .working, event: .assignTask)

        XCTAssertNotEqual(logger.entries[0].id, logger.entries[1].id)
    }

    func testLogEntry_HasTimestamp() {
        let before = Date()
        logger.logTransition(agentId: UUID(), from: .idle, to: .working, event: .assignTask)
        let after = Date()

        let timestamp = logger.entries[0].timestamp
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, after)
    }

    // MARK: - LogEntry Codable

    func testLogEntryCodable() throws {
        let entry = LifecycleLogger.LogEntry(
            agentId: UUID(),
            agentName: "CodableBot",
            fromState: .working,
            toState: .completed,
            event: .taskCompleted,
            message: "Success"
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(LifecycleLogger.LogEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.agentId, entry.agentId)
        XCTAssertEqual(decoded.agentName, entry.agentName)
        XCTAssertEqual(decoded.fromState, entry.fromState)
        XCTAssertEqual(decoded.toState, entry.toState)
        XCTAssertEqual(decoded.event, entry.event)
        XCTAssertEqual(decoded.message, entry.message)
    }
}
