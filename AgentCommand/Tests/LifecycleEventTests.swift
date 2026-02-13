import XCTest
@testable import AgentCommand

// MARK: - LifecycleEvent Tests

final class LifecycleEventTests: XCTestCase {

    func testAllEventsHaveDisplayName() {
        for event in LifecycleEvent.allCases {
            XCTAssertFalse(event.displayName.isEmpty, "\(event) should have a display name")
        }
    }

    func testEventCount() {
        XCTAssertEqual(LifecycleEvent.allCases.count, 28)
    }

    func testRawValueRoundTrip() {
        for event in LifecycleEvent.allCases {
            let raw = event.rawValue
            XCTAssertEqual(LifecycleEvent(rawValue: raw), event)
        }
    }
}

// MARK: - AgentLifecycleContext Tests

final class AgentLifecycleContextTests: XCTestCase {

    func testDefaultInit() {
        let id = UUID()
        let context = AgentLifecycleContext(agentId: id, currentState: .idle)

        XCTAssertEqual(context.agentId, id)
        XCTAssertEqual(context.currentState, .idle)
        XCTAssertNil(context.sessionId)
        XCTAssertNil(context.taskId)
        XCTAssertEqual(context.poolCapacity, 12)
        XCTAssertEqual(context.currentPoolSize, 0)
        XCTAssertEqual(context.idleDuration, 0)
    }

    func testFullInit() {
        let id = UUID()
        let taskId = UUID()
        let context = AgentLifecycleContext(
            agentId: id,
            currentState: .working,
            sessionId: "session-123",
            taskId: taskId,
            poolCapacity: 24,
            currentPoolSize: 6,
            idleDuration: 45.0
        )

        XCTAssertEqual(context.agentId, id)
        XCTAssertEqual(context.currentState, .working)
        XCTAssertEqual(context.sessionId, "session-123")
        XCTAssertEqual(context.taskId, taskId)
        XCTAssertEqual(context.poolCapacity, 24)
        XCTAssertEqual(context.currentPoolSize, 6)
        XCTAssertEqual(context.idleDuration, 45.0)
    }
}
