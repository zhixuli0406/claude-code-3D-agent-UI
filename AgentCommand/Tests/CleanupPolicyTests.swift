import XCTest
@testable import AgentCommand

// MARK: - CleanupPolicy Tests

final class CleanupPolicyTests: XCTestCase {

    func testDefaultPolicy() {
        let policy = CleanupPolicy.default
        XCTAssertEqual(policy.completedTeamDelay, 15.0)
        XCTAssertEqual(policy.failedTeamDelay, 10.0)
        XCTAssertEqual(policy.idleAgentTimeout, 120.0)
        XCTAssertEqual(policy.suspendedIdleTimeout, 300.0)
        XCTAssertEqual(policy.maxConcurrentAgents, 24)
        XCTAssertEqual(policy.maxConcurrentProcesses, 8)
        XCTAssertEqual(policy.memoryWarningThresholdMB, 2048)
        XCTAssertEqual(policy.memoryCriticalThresholdMB, 3072)
        XCTAssertEqual(policy.processHangTimeoutSeconds, 300)
        XCTAssertTrue(policy.enableAutoPoolReturn)
        XCTAssertTrue(policy.enableResourceMonitoring)
    }

    func testAggressivePolicy() {
        let policy = CleanupPolicy.aggressive
        XCTAssertEqual(policy.completedTeamDelay, 5.0)
        XCTAssertEqual(policy.failedTeamDelay, 3.0)
        XCTAssertEqual(policy.idleAgentTimeout, 30.0)
        XCTAssertEqual(policy.maxConcurrentAgents, 12)
    }

    func testAggressiveIsShorterThanDefault() {
        let def = CleanupPolicy.default
        let agg = CleanupPolicy.aggressive
        XCTAssertLessThan(agg.completedTeamDelay, def.completedTeamDelay)
        XCTAssertLessThan(agg.failedTeamDelay, def.failedTeamDelay)
        XCTAssertLessThan(agg.idleAgentTimeout, def.idleAgentTimeout)
    }

    func testCodableRoundTrip() throws {
        let original = CleanupPolicy(
            completedTeamDelay: 20.0,
            failedTeamDelay: 5.0,
            idleAgentTimeout: 60.0,
            maxConcurrentAgents: 16
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CleanupPolicy.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEquatable() {
        let a = CleanupPolicy.default
        let b = CleanupPolicy.default
        XCTAssertEqual(a, b)

        var c = CleanupPolicy.default
        c.completedTeamDelay = 999
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - ResourcePressure Tests

final class ResourcePressureTests: XCTestCase {

    func testOrdering() {
        XCTAssertLessThan(ResourcePressure.normal, .elevated)
        XCTAssertLessThan(ResourcePressure.elevated, .high)
        XCTAssertLessThan(ResourcePressure.high, .critical)
    }

    func testAllCasesHaveDisplayName() {
        for pressure in ResourcePressure.allCases {
            XCTAssertFalse(pressure.displayName.isEmpty)
        }
    }

    func testAllCasesHaveHexColor() {
        for pressure in ResourcePressure.allCases {
            XCTAssertTrue(pressure.hexColor.hasPrefix("#"))
        }
    }

    func testCodableRoundTrip() throws {
        for pressure in ResourcePressure.allCases {
            let data = try JSONEncoder().encode(pressure)
            let decoded = try JSONDecoder().decode(ResourcePressure.self, from: data)
            XCTAssertEqual(decoded, pressure)
        }
    }

    func testAllCasesCount() {
        XCTAssertEqual(ResourcePressure.allCases.count, 4)
    }
}
