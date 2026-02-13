import XCTest
@testable import AgentCommand

// MARK: - AgentLifecycleStateMachine Tests

@MainActor
final class AgentLifecycleStateMachineTests: XCTestCase {

    private var fsm: AgentLifecycleStateMachine!

    override func setUp() {
        super.setUp()
        fsm = AgentLifecycleStateMachine.createDefault()
    }

    override func tearDown() {
        fsm = nil
        super.tearDown()
    }

    // MARK: - Creation Phase

    func testInitializingToIdle() {
        let result = fire(.resourcesLoaded, from: .initializing)
        XCTAssertEqual(result, .idle)
    }

    // MARK: - Idle Transitions

    func testIdleToWorking() {
        let result = fire(.assignTask, from: .idle)
        XCTAssertEqual(result, .working)
    }

    func testIdleToPooled_WithCapacity() {
        let result = fire(.poolReturn, from: .idle, poolCapacity: 12, currentPoolSize: 5)
        XCTAssertEqual(result, .pooled)
    }

    func testIdleToPooled_PoolFull_GuardRejects() {
        let result = fire(.poolReturn, from: .idle, poolCapacity: 12, currentPoolSize: 12)
        XCTAssertNil(result, "Should reject when pool is full")
    }

    func testIdleToSuspendedIdle() {
        let result = fire(.idleTimeout, from: .idle)
        XCTAssertEqual(result, .suspendedIdle)
    }

    func testIdleToDestroying() {
        let result = fire(.disbandScheduled, from: .idle)
        XCTAssertEqual(result, .destroying)
    }

    // MARK: - Working <-> Thinking

    func testWorkingToThinking() {
        let result = fire(.aiReasoning, from: .working)
        XCTAssertEqual(result, .thinking)
    }

    func testThinkingToWorking() {
        let result = fire(.toolInvoked, from: .thinking)
        XCTAssertEqual(result, .working)
    }

    // MARK: - Working -> Interaction States

    func testWorkingToRequestingPermission() {
        let result = fire(.permissionNeeded, from: .working)
        XCTAssertEqual(result, .requestingPermission)
    }

    func testWorkingToWaitingForAnswer() {
        let result = fire(.questionAsked, from: .working)
        XCTAssertEqual(result, .waitingForAnswer)
    }

    func testWorkingToReviewingPlan() {
        let result = fire(.planReady, from: .working)
        XCTAssertEqual(result, .reviewingPlan)
    }

    // MARK: - Interaction -> Resume

    func testPermissionGranted() {
        let result = fire(.permissionGranted, from: .requestingPermission)
        XCTAssertEqual(result, .working)
    }

    func testPermissionDenied() {
        let result = fire(.permissionDenied, from: .requestingPermission)
        XCTAssertEqual(result, .suspended)
    }

    func testPermissionProcessTerminated() {
        let result = fire(.processTerminated, from: .requestingPermission)
        XCTAssertEqual(result, .suspended)
    }

    func testAnswerReceived() {
        let result = fire(.answerReceived, from: .waitingForAnswer)
        XCTAssertEqual(result, .working)
    }

    func testWaitingForAnswerProcessTerminated() {
        let result = fire(.processTerminated, from: .waitingForAnswer)
        XCTAssertEqual(result, .suspended)
    }

    func testPlanApproved() {
        let result = fire(.planApproved, from: .reviewingPlan)
        XCTAssertEqual(result, .working)
    }

    func testPlanRejected() {
        let result = fire(.planRejected, from: .reviewingPlan)
        XCTAssertEqual(result, .suspended)
    }

    func testReviewingPlanProcessTerminated() {
        let result = fire(.processTerminated, from: .reviewingPlan)
        XCTAssertEqual(result, .suspended)
    }

    // MARK: - Completion

    func testWorkingToCompleted() {
        let result = fire(.taskCompleted, from: .working)
        XCTAssertEqual(result, .completed)
    }

    func testWorkingToError() {
        let result = fire(.taskFailed, from: .working)
        XCTAssertEqual(result, .error)
    }

    func testThinkingToCompleted() {
        let result = fire(.taskCompleted, from: .thinking)
        XCTAssertEqual(result, .completed)
    }

    func testThinkingToError() {
        let result = fire(.taskFailed, from: .thinking)
        XCTAssertEqual(result, .error)
    }

    // MARK: - Suspended

    func testSuspendedResumeWithSession() {
        let result = fire(.resume, from: .suspended, sessionId: "session-123")
        XCTAssertEqual(result, .working)
    }

    func testSuspendedResumeWithoutSession_GuardRejects() {
        let result = fire(.resume, from: .suspended, sessionId: nil)
        XCTAssertNil(result, "Should reject resume without session ID")
    }

    func testSuspendedCancel() {
        let result = fire(.cancel, from: .suspended)
        XCTAssertEqual(result, .error)
    }

    func testSuspendedTimeout() {
        let result = fire(.timeout, from: .suspended)
        XCTAssertEqual(result, .suspendedIdle)
    }

    // MARK: - SuspendedIdle

    func testSuspendedIdleAssignTask() {
        let result = fire(.assignTask, from: .suspendedIdle)
        XCTAssertEqual(result, .working)
    }

    func testSuspendedIdleCleanupTriggered() {
        let result = fire(.cleanupTriggered, from: .suspendedIdle)
        XCTAssertEqual(result, .destroying)
    }

    // MARK: - Pool

    func testPooledAssignTask() {
        let result = fire(.assignTask, from: .pooled)
        XCTAssertEqual(result, .initializing)
    }

    func testPooledEviction() {
        let result = fire(.poolEviction, from: .pooled)
        XCTAssertEqual(result, .destroying)
    }

    // MARK: - Completed/Error -> Next Phase

    func testCompletedReturnToPool_WithCapacity() {
        let result = fire(.returnToPool, from: .completed, poolCapacity: 12, currentPoolSize: 5)
        XCTAssertEqual(result, .pooled)
    }

    func testCompletedReturnToPool_PoolFull() {
        let result = fire(.returnToPool, from: .completed, poolCapacity: 12, currentPoolSize: 12)
        XCTAssertNil(result, "Should reject when pool is full")
    }

    func testCompletedDisbandScheduled() {
        let result = fire(.disbandScheduled, from: .completed)
        XCTAssertEqual(result, .destroying)
    }

    func testCompletedAssignNewTask() {
        let result = fire(.assignNewTask, from: .completed)
        XCTAssertEqual(result, .working)
    }

    func testErrorRetry() {
        let result = fire(.retry, from: .error)
        XCTAssertEqual(result, .working)
    }

    func testErrorDisbandScheduled() {
        let result = fire(.disbandScheduled, from: .error)
        XCTAssertEqual(result, .destroying)
    }

    // MARK: - Destruction

    func testDestroyingToDestroyed() {
        let result = fire(.animationComplete, from: .destroying)
        XCTAssertEqual(result, .destroyed)
    }

    // MARK: - Invalid Transitions

    func testInvalidTransitionReturnsNil() {
        // Destroyed is terminal; no events should transition from it
        for event in LifecycleEvent.allCases {
            let result = fire(event, from: .destroyed)
            XCTAssertNil(result, "Destroyed + \(event) should be nil")
        }
    }

    func testInvalidTransition_IdleCannotCompleteTask() {
        let result = fire(.taskCompleted, from: .idle)
        XCTAssertNil(result)
    }

    func testInvalidTransition_CompletedCannotThink() {
        let result = fire(.aiReasoning, from: .completed)
        XCTAssertNil(result)
    }

    // MARK: - Query Methods

    func testValidEventsFromIdle() {
        let events = fsm.validEvents(from: .idle)
        XCTAssertTrue(events.contains(.assignTask))
        XCTAssertTrue(events.contains(.poolReturn))
        XCTAssertTrue(events.contains(.idleTimeout))
        XCTAssertTrue(events.contains(.disbandScheduled))
    }

    func testValidEventsFromDestroyed() {
        let events = fsm.validEvents(from: .destroyed)
        XCTAssertTrue(events.isEmpty, "No events should be valid from destroyed state")
    }

    func testTargetState() {
        let target = fsm.targetState(from: .idle, event: .assignTask)
        XCTAssertEqual(target, .working)
    }

    func testTargetStateForInvalidTransition() {
        let target = fsm.targetState(from: .idle, event: .taskCompleted)
        XCTAssertNil(target)
    }

    func testCanFire() {
        XCTAssertTrue(fsm.canFire(event: .assignTask, from: .idle))
        XCTAssertFalse(fsm.canFire(event: .taskCompleted, from: .idle))
    }

    // MARK: - onTransition Callback

    func testOnTransitionCallbackFired() {
        var callbackFired = false
        var capturedFrom: AgentLifecycleState?
        var capturedTo: AgentLifecycleState?
        var capturedEvent: LifecycleEvent?

        fsm.onTransition = { _, from, to, event in
            callbackFired = true
            capturedFrom = from
            capturedTo = to
            capturedEvent = event
        }

        let _ = fire(.resourcesLoaded, from: .initializing)

        XCTAssertTrue(callbackFired)
        XCTAssertEqual(capturedFrom, .initializing)
        XCTAssertEqual(capturedTo, .idle)
        XCTAssertEqual(capturedEvent, .resourcesLoaded)
    }

    func testOnTransitionNotFiredForInvalidTransition() {
        var callbackFired = false
        fsm.onTransition = { _, _, _, _ in callbackFired = true }

        let _ = fire(.taskCompleted, from: .idle)

        XCTAssertFalse(callbackFired)
    }

    // MARK: - Transition Count

    func testDefaultTransitionCount() {
        // The default FSM should have a significant number of registered transitions
        XCTAssertGreaterThan(fsm.transitionCount, 30)
    }

    // MARK: - Complete Lifecycle Path

    func testFullLifecyclePath_HappyPath() {
        // initializing -> idle -> working -> thinking -> working -> completed -> destroying -> destroyed
        var state: AgentLifecycleState = .initializing

        state = fire(.resourcesLoaded, from: state)!
        XCTAssertEqual(state, .idle)

        state = fire(.assignTask, from: state)!
        XCTAssertEqual(state, .working)

        state = fire(.aiReasoning, from: state)!
        XCTAssertEqual(state, .thinking)

        state = fire(.toolInvoked, from: state)!
        XCTAssertEqual(state, .working)

        state = fire(.taskCompleted, from: state)!
        XCTAssertEqual(state, .completed)

        state = fire(.disbandScheduled, from: state)!
        XCTAssertEqual(state, .destroying)

        state = fire(.animationComplete, from: state)!
        XCTAssertEqual(state, .destroyed)
    }

    func testFullLifecyclePath_SuspendAndResume() {
        var state: AgentLifecycleState = .idle

        state = fire(.assignTask, from: state)!
        XCTAssertEqual(state, .working)

        state = fire(.questionAsked, from: state)!
        XCTAssertEqual(state, .waitingForAnswer)

        state = fire(.processTerminated, from: state)!
        XCTAssertEqual(state, .suspended)

        state = fire(.resume, from: state, sessionId: "s-1")!
        XCTAssertEqual(state, .working)

        state = fire(.taskCompleted, from: state)!
        XCTAssertEqual(state, .completed)
    }

    func testFullLifecyclePath_PoolReuse() {
        var state: AgentLifecycleState = .idle

        state = fire(.assignTask, from: state)!
        state = fire(.taskCompleted, from: state)!
        XCTAssertEqual(state, .completed)

        state = fire(.returnToPool, from: state, poolCapacity: 12, currentPoolSize: 2)!
        XCTAssertEqual(state, .pooled)

        state = fire(.assignTask, from: state)!
        XCTAssertEqual(state, .initializing)
    }

    func testFullLifecyclePath_ErrorAndRetry() {
        var state: AgentLifecycleState = .working

        state = fire(.taskFailed, from: state)!
        XCTAssertEqual(state, .error)

        state = fire(.retry, from: state)!
        XCTAssertEqual(state, .working)

        state = fire(.taskCompleted, from: state)!
        XCTAssertEqual(state, .completed)
    }

    func testFullLifecyclePath_IdleTimeoutToCleanup() {
        var state: AgentLifecycleState = .idle

        state = fire(.idleTimeout, from: state)!
        XCTAssertEqual(state, .suspendedIdle)

        state = fire(.cleanupTriggered, from: state)!
        XCTAssertEqual(state, .destroying)

        state = fire(.animationComplete, from: state)!
        XCTAssertEqual(state, .destroyed)
    }

    func testFullLifecyclePath_SuspendTimeout() {
        var state: AgentLifecycleState = .working

        state = fire(.permissionNeeded, from: state)!
        state = fire(.permissionDenied, from: state)!
        XCTAssertEqual(state, .suspended)

        state = fire(.timeout, from: state)!
        XCTAssertEqual(state, .suspendedIdle)

        state = fire(.cleanupTriggered, from: state)!
        XCTAssertEqual(state, .destroying)
    }

    // MARK: - Helpers

    private func fire(
        _ event: LifecycleEvent,
        from state: AgentLifecycleState,
        sessionId: String? = nil,
        poolCapacity: Int = 12,
        currentPoolSize: Int = 0
    ) -> AgentLifecycleState? {
        let context = AgentLifecycleContext(
            agentId: UUID(),
            currentState: state,
            sessionId: sessionId,
            poolCapacity: poolCapacity,
            currentPoolSize: currentPoolSize
        )
        return fsm.fire(event: event, context: context)
    }
}
