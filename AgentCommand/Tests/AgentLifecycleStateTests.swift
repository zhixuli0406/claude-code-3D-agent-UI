import XCTest
@testable import AgentCommand

// MARK: - AgentLifecycleState Tests

final class AgentLifecycleStateTests: XCTestCase {

    // MARK: - isTerminal

    func testIsTerminal_OnlyDestroyedIsTerminal() {
        for state in AgentLifecycleState.allCases {
            if state == .destroyed {
                XCTAssertTrue(state.isTerminal, "\(state) should be terminal")
            } else {
                XCTAssertFalse(state.isTerminal, "\(state) should not be terminal")
            }
        }
    }

    // MARK: - isActive

    func testIsActive_IncludesWorkStates() {
        let expectedActive: Set<AgentLifecycleState> = [
            .working, .thinking, .requestingPermission,
            .waitingForAnswer, .reviewingPlan
        ]
        for state in AgentLifecycleState.allCases {
            if expectedActive.contains(state) {
                XCTAssertTrue(state.isActive, "\(state) should be active")
            } else {
                XCTAssertFalse(state.isActive, "\(state) should not be active")
            }
        }
    }

    // MARK: - isAvailableForTask

    func testIsAvailableForTask() {
        let expected: Set<AgentLifecycleState> = [.idle, .pooled, .suspendedIdle]
        for state in AgentLifecycleState.allCases {
            if expected.contains(state) {
                XCTAssertTrue(state.isAvailableForTask, "\(state) should be available for task")
            } else {
                XCTAssertFalse(state.isAvailableForTask, "\(state) should not be available")
            }
        }
    }

    // MARK: - isCleanupCandidate

    func testIsCleanupCandidate() {
        let expected: Set<AgentLifecycleState> = [.completed, .error, .suspendedIdle, .idle]
        for state in AgentLifecycleState.allCases {
            if expected.contains(state) {
                XCTAssertTrue(state.isCleanupCandidate, "\(state) should be cleanup candidate")
            } else {
                XCTAssertFalse(state.isCleanupCandidate, "\(state) should not be cleanup candidate")
            }
        }
    }

    // MARK: - isSuspended

    func testIsSuspended() {
        let expected: Set<AgentLifecycleState> = [.suspended, .suspendedIdle]
        for state in AgentLifecycleState.allCases {
            if expected.contains(state) {
                XCTAssertTrue(state.isSuspended, "\(state) should be suspended")
            } else {
                XCTAssertFalse(state.isSuspended, "\(state) should not be suspended")
            }
        }
    }

    // MARK: - Display Properties

    func testAllStatesHaveDisplayName() {
        for state in AgentLifecycleState.allCases {
            XCTAssertFalse(state.displayName.isEmpty, "\(state) should have a display name")
        }
    }

    func testAllStatesHaveHexColor() {
        for state in AgentLifecycleState.allCases {
            XCTAssertTrue(state.hexColor.hasPrefix("#"), "\(state) hex color should start with #")
            XCTAssertEqual(state.hexColor.count, 7, "\(state) hex color should be 7 chars")
        }
    }

    // MARK: - Legacy Status Mapping

    func testLegacyStatusMapping() {
        XCTAssertEqual(AgentLifecycleState.initializing.legacyStatus, .idle)
        XCTAssertEqual(AgentLifecycleState.idle.legacyStatus, .idle)
        XCTAssertEqual(AgentLifecycleState.working.legacyStatus, .working)
        XCTAssertEqual(AgentLifecycleState.thinking.legacyStatus, .thinking)
        XCTAssertEqual(AgentLifecycleState.requestingPermission.legacyStatus, .requestingPermission)
        XCTAssertEqual(AgentLifecycleState.waitingForAnswer.legacyStatus, .waitingForAnswer)
        XCTAssertEqual(AgentLifecycleState.reviewingPlan.legacyStatus, .reviewingPlan)
        XCTAssertEqual(AgentLifecycleState.completed.legacyStatus, .completed)
        XCTAssertEqual(AgentLifecycleState.error.legacyStatus, .error)
        XCTAssertEqual(AgentLifecycleState.suspended.legacyStatus, .waitingForAnswer)
        XCTAssertEqual(AgentLifecycleState.suspendedIdle.legacyStatus, .idle)
        XCTAssertEqual(AgentLifecycleState.pooled.legacyStatus, .idle)
        XCTAssertEqual(AgentLifecycleState.destroying.legacyStatus, .idle)
        XCTAssertEqual(AgentLifecycleState.destroyed.legacyStatus, .idle)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        for state in AgentLifecycleState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(AgentLifecycleState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - CaseIterable

    func testAllCasesCount() {
        XCTAssertEqual(AgentLifecycleState.allCases.count, 14)
    }
}
