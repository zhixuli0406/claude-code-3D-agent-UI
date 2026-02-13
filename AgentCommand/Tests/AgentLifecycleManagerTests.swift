import XCTest
@testable import AgentCommand

// MARK: - AgentLifecycleManager Tests

@MainActor
final class AgentLifecycleManagerTests: XCTestCase {

    private var manager: AgentLifecycleManager!

    override func setUp() {
        super.setUp()
        manager = AgentLifecycleManager()
    }

    override func tearDown() {
        manager.shutdown()
        manager = nil
        super.tearDown()
    }

    // MARK: - Registration

    func testRegisterAgent() {
        let agentId = UUID()
        manager.registerAgent(agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .initializing)
        XCTAssertEqual(manager.totalManagedAgents, 1)
    }

    func testRegisterAgent_CustomInitialState() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)
        XCTAssertEqual(manager.currentState(for: agentId), .idle)
    }

    func testUnregisterAgent() {
        let agentId = UUID()
        manager.registerAgent(agentId)
        manager.unregisterAgent(agentId)
        XCTAssertNil(manager.currentState(for: agentId))
        XCTAssertEqual(manager.totalManagedAgents, 0)
    }

    // MARK: - State Transitions

    func testFireEvent_ValidTransition() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .initializing)

        let result = manager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertEqual(result, .idle)
        XCTAssertEqual(manager.currentState(for: agentId), .idle)
    }

    func testFireEvent_InvalidTransition() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)

        let result = manager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertNil(result)
        XCTAssertEqual(manager.currentState(for: agentId), .idle)
    }

    func testFireEvent_UnregisteredAgent() {
        let result = manager.fireEvent(.assignTask, forAgent: UUID())
        XCTAssertNil(result)
    }

    func testFireEvent_WithSessionId() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .suspended)

        let result = manager.fireEvent(.resume, forAgent: agentId, sessionId: "session-1")
        XCTAssertEqual(result, .working)
    }

    func testFireEvent_SuspendedResumeWithoutSession_Rejected() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .suspended)

        let result = manager.fireEvent(.resume, forAgent: agentId)
        XCTAssertNil(result)
        XCTAssertEqual(manager.currentState(for: agentId), .suspended)
    }

    // MARK: - State Change Callback

    func testOnStateChangedCallback() {
        var capturedFrom: AgentLifecycleState?
        var capturedTo: AgentLifecycleState?
        var capturedEvent: LifecycleEvent?

        manager.onStateChanged = { _, from, to, event in
            capturedFrom = from
            capturedTo = to
            capturedEvent = event
        }

        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)
        manager.fireEvent(.assignTask, forAgent: agentId)

        XCTAssertEqual(capturedFrom, .idle)
        XCTAssertEqual(capturedTo, .working)
        XCTAssertEqual(capturedEvent, .assignTask)
    }

    func testOnStateChangedNotCalledForInvalidTransition() {
        var callbackCount = 0
        manager.onStateChanged = { _, _, _, _ in callbackCount += 1 }

        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)
        manager.fireEvent(.taskCompleted, forAgent: agentId)

        XCTAssertEqual(callbackCount, 0)
    }

    // MARK: - Computed Properties

    func testActiveAgentCount() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .working)
        manager.registerAgent(a2, initialState: .thinking)
        manager.registerAgent(a3, initialState: .idle)

        XCTAssertEqual(manager.activeAgentCount, 2)
    }

    func testRunningProcessCount() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .working)
        manager.registerAgent(a2, initialState: .thinking)
        manager.registerAgent(a3, initialState: .requestingPermission)

        XCTAssertEqual(manager.runningProcessCount, 2)
    }

    func testIdleAgentCount() {
        let a1 = UUID()
        let a2 = UUID()
        manager.registerAgent(a1, initialState: .idle)
        manager.registerAgent(a2, initialState: .idle)

        XCTAssertEqual(manager.idleAgentCount, 2)
    }

    func testSuspendedAgentCount() {
        let a1 = UUID()
        let a2 = UUID()
        manager.registerAgent(a1, initialState: .suspended)
        manager.registerAgent(a2, initialState: .suspendedIdle)

        XCTAssertEqual(manager.suspendedAgentCount, 2)
    }

    // MARK: - canFireEvent

    func testCanFireEvent() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)

        XCTAssertTrue(manager.canFireEvent(.assignTask, forAgent: agentId))
        XCTAssertFalse(manager.canFireEvent(.taskCompleted, forAgent: agentId))
    }

    func testCanFireEvent_UnregisteredAgent() {
        XCTAssertFalse(manager.canFireEvent(.assignTask, forAgent: UUID()))
    }

    // MARK: - Query Methods

    func testAgentsInState() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .working)
        manager.registerAgent(a2, initialState: .idle)
        manager.registerAgent(a3, initialState: .working)

        let working = manager.agents(in: .working)
        XCTAssertEqual(working.count, 2)
        XCTAssertTrue(working.contains(a1))
        XCTAssertTrue(working.contains(a3))
    }

    func testCleanupCandidates() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .completed)
        manager.registerAgent(a2, initialState: .error)
        manager.registerAgent(a3, initialState: .working)

        let candidates = manager.cleanupCandidates()
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains(a1))
        XCTAssertTrue(candidates.contains(a2))
        XCTAssertFalse(candidates.contains(a3))
    }

    func testAvailableAgents() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .idle)
        manager.registerAgent(a2, initialState: .pooled)
        manager.registerAgent(a3, initialState: .working)

        let available = manager.availableAgents()
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.contains(a1))
        XCTAssertTrue(available.contains(a2))
    }

    // MARK: - Batch Operations

    func testBeginDestroyingAgents() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .completed)
        manager.registerAgent(a2, initialState: .idle)
        manager.registerAgent(a3, initialState: .destroyed) // Already destroyed

        manager.beginDestroyingAgents(Set([a1, a2, a3]))

        XCTAssertEqual(manager.currentState(for: a1), .destroying)
        XCTAssertEqual(manager.currentState(for: a2), .destroying)
        XCTAssertEqual(manager.currentState(for: a3), .destroyed) // Unchanged
    }

    func testCompleteDestruction() {
        let a1 = UUID()
        let a2 = UUID()
        manager.registerAgent(a1, initialState: .destroying)
        manager.registerAgent(a2, initialState: .working) // Not in destroying

        manager.completeDestruction(for: Set([a1, a2]))

        XCTAssertEqual(manager.currentState(for: a1), .destroyed)
        XCTAssertEqual(manager.currentState(for: a2), .working) // Unchanged
    }

    // MARK: - Emergency Cleanup

    func testEmergencyCleanup() {
        var emergencyCalled = false
        manager.onEmergencyCleanupRequested = { emergencyCalled = true }

        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .completed)
        manager.registerAgent(a2, initialState: .pooled)
        manager.registerAgent(a3, initialState: .working)

        manager.emergencyCleanup()

        XCTAssertEqual(manager.currentState(for: a1), .destroyed)
        XCTAssertEqual(manager.currentState(for: a2), .destroyed)
        XCTAssertEqual(manager.currentState(for: a3), .working) // Active, not cleaned
        XCTAssertTrue(emergencyCalled)
    }

    // MARK: - Evict Pooled Agents

    func testEvictOldestPooledAgents() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()
        manager.registerAgent(a1, initialState: .pooled)
        manager.registerAgent(a2, initialState: .pooled)
        manager.registerAgent(a3, initialState: .idle)

        manager.evictOldestPooledAgents(count: 1)

        // One pooled agent should be moved to destroying
        let pooledCount = manager.agents(in: .pooled).count
        let destroyingCount = manager.agents(in: .destroying).count
        XCTAssertEqual(pooledCount, 1)
        XCTAssertEqual(destroyingCount, 1)
    }

    // MARK: - Team Disband Callback

    func testTeamDisbandCallback() {
        var capturedCommanderId: UUID?
        manager.onTeamDisbandRequested = { id in capturedCommanderId = id }

        let commanderId = UUID()
        manager.initiateTeamDisband(commanderId: commanderId)

        XCTAssertEqual(capturedCommanderId, commanderId)
    }

    // MARK: - Side Effects Integration

    func testTransitionToIdle_TriggersIdleTracking() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .initializing)
        manager.fireEvent(.resourcesLoaded, forAgent: agentId)

        XCTAssertNotNil(manager.cleanupManager.idleTracking[agentId])
    }

    func testTransitionToWorking_ClearsIdleTracking() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .initializing)

        // Transition to idle (triggers idle tracking via side effects)
        manager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertNotNil(manager.cleanupManager.idleTracking[agentId])

        // Transition to working (clears idle tracking)
        manager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertNil(manager.cleanupManager.idleTracking[agentId])
    }

    func testTransitionToCompleted_SetsIdleTracking() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .working)
        manager.fireEvent(.taskCompleted, forAgent: agentId)

        XCTAssertNotNil(manager.cleanupManager.idleTracking[agentId])
    }

    func testTransitionToDestroyed_CleansUpTracking() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .destroying)
        manager.fireEvent(.animationComplete, forAgent: agentId)

        XCTAssertNil(manager.cleanupManager.idleTracking[agentId])
        XCTAssertNil(manager.cleanupManager.lastActivityTimes[agentId])
    }

    // MARK: - Logging

    func testTransitionsAreLogged() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)
        manager.fireEvent(.assignTask, forAgent: agentId)

        // Registration log + transition log
        let entries = manager.logger.entries(for: agentId)
        XCTAssertGreaterThanOrEqual(entries.count, 2)
    }

    func testInvalidTransitionsAreLogged() {
        let agentId = UUID()
        manager.registerAgent(agentId, initialState: .idle)
        manager.fireEvent(.taskCompleted, forAgent: agentId) // Invalid

        let allEntries = manager.logger.entries
        let invalidEntries = allEntries.filter { $0.message?.contains("INVALID") == true }
        XCTAssertFalse(invalidEntries.isEmpty)
    }

    // MARK: - Full Lifecycle Integration

    func testFullLifecycle_CreateWorkComplete() {
        let agentId = UUID()

        // Create
        manager.registerAgent(agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .initializing)

        // Initialize
        manager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .idle)

        // Start work
        manager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .working)
        XCTAssertEqual(manager.activeAgentCount, 1)

        // Think
        manager.fireEvent(.aiReasoning, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .thinking)

        // Back to work
        manager.fireEvent(.toolInvoked, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .working)

        // Complete
        manager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .completed)
        XCTAssertEqual(manager.activeAgentCount, 0)

        // Destroy
        manager.fireEvent(.disbandScheduled, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .destroying)

        manager.fireEvent(.animationComplete, forAgent: agentId)
        XCTAssertEqual(manager.currentState(for: agentId), .destroyed)
    }

    func testFullLifecycle_MultipleAgents() {
        let a1 = UUID()
        let a2 = UUID()
        let a3 = UUID()

        manager.registerAgent(a1, initialState: .idle)
        manager.registerAgent(a2, initialState: .idle)
        manager.registerAgent(a3, initialState: .idle)

        XCTAssertEqual(manager.totalManagedAgents, 3)

        // a1 works and completes
        manager.fireEvent(.assignTask, forAgent: a1)
        manager.fireEvent(.taskCompleted, forAgent: a1)

        // a2 works and fails
        manager.fireEvent(.assignTask, forAgent: a2)
        manager.fireEvent(.taskFailed, forAgent: a2)

        // a3 stays idle
        XCTAssertEqual(manager.currentState(for: a1), .completed)
        XCTAssertEqual(manager.currentState(for: a2), .error)
        XCTAssertEqual(manager.currentState(for: a3), .idle)

        XCTAssertEqual(manager.cleanupCandidates().count, 3) // completed, error, idle
    }
}
