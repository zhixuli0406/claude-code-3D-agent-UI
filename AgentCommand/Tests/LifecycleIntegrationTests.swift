import XCTest
@testable import AgentCommand

// MARK: - Lifecycle Integration Tests

@MainActor
final class LifecycleIntegrationTests: XCTestCase {

    private var lifecycleManager: AgentLifecycleManager!
    private var persistenceManager: AgentPersistenceManager!
    private var taskQueueManager: SubAgentTaskQueueManager!
    private var tempDirectory: URL!

    // MARK: - Helpers

    /// Create a minimal VoxelAppearance for test usage
    private func makeAppearance() -> VoxelAppearance {
        VoxelAppearance(
            skinColor: "#FFCC99",
            shirtColor: "#1A237E",
            pantsColor: "#37474F",
            hairColor: "#3E2723",
            hairStyle: .short,
            accessory: nil
        )
    }

    /// Create a minimal ResumeContext for test usage
    private func makeResumeContext(
        agentId: UUID = UUID(),
        sessionId: String = "session-\(UUID().uuidString)",
        suspensionReason: SuspensionReason = .appTerminated,
        pendingInteraction: PendingInteraction? = nil
    ) -> ResumeContext {
        ResumeContext(
            agentId: agentId,
            agentName: "TestAgent",
            agentRole: .developer,
            agentModel: .sonnet,
            agentPersonality: AgentPersonality(trait: .calm),
            agentAppearance: makeAppearance(),
            sessionId: sessionId,
            workingDirectory: "/tmp/test",
            taskId: UUID(),
            taskTitle: "Test Task",
            originalPrompt: "Do something",
            suspendedAt: Date(),
            suspensionReason: suspensionReason,
            toolCallCount: 5,
            progressEstimate: 0.5,
            commanderId: nil,
            teamAgentIds: [],
            orchestrationId: nil,
            orchestrationTaskIndex: nil,
            pendingInteraction: pendingInteraction
        )
    }

    /// Create a minimal Agent for test usage
    private func makeAgent(id: UUID = UUID(), role: AgentRole = .developer) -> Agent {
        Agent(
            id: id,
            name: "TestAgent-\(role.rawValue)",
            role: role,
            status: .idle,
            selectedModel: .sonnet,
            personality: AgentPersonality(trait: .calm),
            appearance: makeAppearance(),
            position: ScenePosition(x: 0, y: 0, z: 0, rotation: 0),
            parentAgentId: nil,
            subAgentIds: [],
            assignedTaskIds: []
        )
    }

    /// Create a minimal AgentTask for test usage
    private func makeTask(
        id: UUID = UUID(),
        assignedAgentId: UUID? = nil
    ) -> AgentTask {
        AgentTask(
            id: id,
            title: "Test Task",
            description: "A task for testing",
            status: .pending,
            priority: .medium,
            assignedAgentId: assignedAgentId,
            subtasks: [],
            progress: 0.0,
            createdAt: Date(),
            estimatedDuration: 60.0,
            teamAgentIds: [],
            isRealExecution: false
        )
    }

    /// Create a SubAgentTaskQueueItem for test usage
    private func makeQueueItem(
        id: UUID = UUID(),
        commanderId: UUID,
        orchestrationTaskIndex: Int,
        dependencies: [Int] = [],
        status: SubAgentTaskQueueItem.QueueItemStatus = .pending
    ) -> SubAgentTaskQueueItem {
        SubAgentTaskQueueItem(
            id: id,
            commanderId: commanderId,
            orchestrationTaskIndex: orchestrationTaskIndex,
            title: "Queue Task \(orchestrationTaskIndex)",
            prompt: "Execute task \(orchestrationTaskIndex)",
            agentId: nil,
            dependencies: dependencies,
            status: status,
            retryCount: 0,
            enqueuedAt: Date(),
            startedAt: nil,
            suspendedAt: nil,
            completedAt: nil,
            result: nil,
            error: nil,
            sessionId: nil
        )
    }

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        lifecycleManager = AgentLifecycleManager()
        lifecycleManager.initialize()

        persistenceManager = AgentPersistenceManager()
        taskQueueManager = SubAgentTaskQueueManager()
        taskQueueManager.persistenceManager = persistenceManager

        // Create a temporary directory for persistence tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifecycleIntegrationTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        lifecycleManager.shutdown()
        lifecycleManager = nil
        persistenceManager?.stopAutoSave()
        persistenceManager = nil
        taskQueueManager = nil

        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - 1. Resume Functionality End-to-End

    func testResumeFromRequestingPermission_ProcessTerminated() {
        // Agent goes through: initializing -> idle -> working -> requestingPermission -> suspended -> working (resume)
        let agentId = UUID()
        let sessionId = "session-resume-permission"

        lifecycleManager.registerAgent(agentId, initialState: .initializing)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .initializing)

        // initializing -> idle
        let idleState = lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertEqual(idleState, .idle)

        // idle -> working
        let workingState = lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertEqual(workingState, .working)

        // working -> requestingPermission
        let permState = lifecycleManager.fireEvent(.permissionNeeded, forAgent: agentId)
        XCTAssertEqual(permState, .requestingPermission)

        // requestingPermission -> suspended (process terminated)
        let suspendedState = lifecycleManager.fireEvent(.processTerminated, forAgent: agentId)
        XCTAssertEqual(suspendedState, .suspended)

        // Create a ResumeContext as the app would
        let resumeContext = makeResumeContext(
            agentId: agentId,
            sessionId: sessionId,
            suspensionReason: .appTerminated,
            pendingInteraction: PendingInteraction(
                type: .permissionRequest,
                sessionId: sessionId,
                inputJSON: "{}",
                receivedAt: Date()
            )
        )
        XCTAssertEqual(resumeContext.agentId, agentId)
        XCTAssertEqual(resumeContext.sessionId, sessionId)
        XCTAssertNotNil(resumeContext.pendingInteraction)

        // suspended -> working (resume with sessionId)
        let resumedState = lifecycleManager.fireEvent(
            .resume,
            forAgent: agentId,
            sessionId: sessionId
        )
        XCTAssertEqual(resumedState, .working)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .working)
    }

    func testResumeFromWaitingForAnswer_ProcessTerminated() {
        let agentId = UUID()
        let sessionId = "session-resume-answer"

        lifecycleManager.registerAgent(agentId, initialState: .idle)

        // idle -> working -> waitingForAnswer -> suspended -> working
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.questionAsked, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .waitingForAnswer)

        lifecycleManager.fireEvent(.processTerminated, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .suspended)

        let resumeContext = makeResumeContext(
            agentId: agentId,
            sessionId: sessionId,
            suspensionReason: .userQuestion,
            pendingInteraction: PendingInteraction(
                type: .question,
                sessionId: sessionId,
                inputJSON: "{\"question\": \"What directory?\"}",
                receivedAt: Date()
            )
        )
        XCTAssertEqual(resumeContext.suspensionReason, .userQuestion)

        let resumedState = lifecycleManager.fireEvent(
            .resume,
            forAgent: agentId,
            sessionId: sessionId
        )
        XCTAssertEqual(resumedState, .working)
    }

    func testResumeFromReviewingPlan_ProcessTerminated() {
        let agentId = UUID()
        let sessionId = "session-resume-plan"

        lifecycleManager.registerAgent(agentId, initialState: .idle)

        // idle -> working -> reviewingPlan -> suspended -> working
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.planReady, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .reviewingPlan)

        lifecycleManager.fireEvent(.processTerminated, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .suspended)

        let resumedState = lifecycleManager.fireEvent(
            .resume,
            forAgent: agentId,
            sessionId: sessionId
        )
        XCTAssertEqual(resumedState, .working)
    }

    func testResumeWithoutSessionId_IsRejected() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.questionAsked, forAgent: agentId)
        lifecycleManager.fireEvent(.processTerminated, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .suspended)

        // Resume without sessionId should fail because the guard requires sessionId != nil
        let result = lifecycleManager.fireEvent(.resume, forAgent: agentId)
        XCTAssertNil(result, "Resume without sessionId should be rejected by guard condition")
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .suspended)
    }

    // MARK: - 2. Idle Cleanup Integration

    func testIdleAgentTrackedByCleanupManager() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .initializing)
        lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .idle)

        // The side effect of transitioning to .idle should call agentBecameIdle
        XCTAssertTrue(
            lifecycleManager.cleanupManager.idleTracking.keys.contains(agentId),
            "Cleanup manager should track the idle agent"
        )
        XCTAssertTrue(
            lifecycleManager.cleanupManager.lastActivityTimes.keys.contains(agentId),
            "Cleanup manager should record activity time"
        )
    }

    func testIdleToSuspendedIdleThenCleanupTriggeredToDestroying() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)

        // idle -> suspendedIdle (simulating idle timeout)
        let suspIdleState = lifecycleManager.fireEvent(.idleTimeout, forAgent: agentId)
        XCTAssertEqual(suspIdleState, .suspendedIdle)

        // suspendedIdle -> destroying (cleanup triggered)
        let destroyingState = lifecycleManager.fireEvent(.cleanupTriggered, forAgent: agentId)
        XCTAssertEqual(destroyingState, .destroying)

        // destroying -> destroyed (animation complete)
        let destroyedState = lifecycleManager.fireEvent(.animationComplete, forAgent: agentId)
        XCTAssertEqual(destroyedState, .destroyed)

        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .destroyed)
    }

    func testIdleCleanupFullCycle_WithCleanupManagerTracking() {
        let agentId = UUID()

        // Register and move to idle
        lifecycleManager.registerAgent(agentId, initialState: .initializing)
        lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)

        // Verify idle tracking started
        XCTAssertNotNil(lifecycleManager.cleanupManager.idleTracking[agentId])

        // Move to working (should remove idle tracking)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertNil(lifecycleManager.cleanupManager.idleTracking[agentId],
                     "Active agent should not be tracked as idle")

        // Complete task, which triggers agentBecameIdle again
        lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .completed)

        // Completed agents are tracked as idle by cleanup manager
        XCTAssertNotNil(lifecycleManager.cleanupManager.idleTracking[agentId])
    }

    // MARK: - 3. Persistence Round-Trip

    func testSaveAndLoadResumeContext() {
        let agentId = UUID()
        let sessionId = "persist-session-\(UUID().uuidString)"

        let original = makeResumeContext(
            agentId: agentId,
            sessionId: sessionId,
            suspensionReason: .userQuestion,
            pendingInteraction: PendingInteraction(
                type: .question,
                sessionId: sessionId,
                inputJSON: "{\"q\": \"What?\"}",
                receivedAt: Date()
            )
        )

        // Save
        persistenceManager.saveResumeContext(original)

        // Load
        let loaded = persistenceManager.loadResumeContext(agentId: agentId)
        XCTAssertNotNil(loaded, "Should load saved resume context")
        XCTAssertEqual(loaded?.agentId, agentId)
        XCTAssertEqual(loaded?.sessionId, sessionId)
        XCTAssertEqual(loaded?.agentRole, .developer)
        XCTAssertEqual(loaded?.agentModel, .sonnet)
        XCTAssertEqual(loaded?.suspensionReason, .userQuestion)
        XCTAssertEqual(loaded?.toolCallCount, 5)
        XCTAssertEqual(loaded?.progressEstimate, 0.5)
        XCTAssertNotNil(loaded?.pendingInteraction)
        XCTAssertEqual(loaded?.pendingInteraction?.type, .question)

        // Cleanup
        persistenceManager.removeResumeContext(agentId: agentId)
        XCTAssertNil(persistenceManager.loadResumeContext(agentId: agentId))
    }

    func testSaveAndLoadMultipleResumeContexts() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let ctx1 = makeResumeContext(agentId: id1, suspensionReason: .appTerminated)
        let ctx2 = makeResumeContext(agentId: id2, suspensionReason: .userPaused)
        let ctx3 = makeResumeContext(agentId: id3, suspensionReason: .processTimeout)

        persistenceManager.saveResumeContext(ctx1)
        persistenceManager.saveResumeContext(ctx2)
        persistenceManager.saveResumeContext(ctx3)

        let allPending = persistenceManager.allPendingResumes()
        // Should find at least our 3 (there might be others from previous runs)
        let ourContexts = allPending.filter { [id1, id2, id3].contains($0.agentId) }
        XCTAssertEqual(ourContexts.count, 3)

        // Clean up
        persistenceManager.removeResumeContext(agentId: id1)
        persistenceManager.removeResumeContext(agentId: id2)
        persistenceManager.removeResumeContext(agentId: id3)
    }

    func testSaveAndLoadAgentStateSnapshot() {
        let agent = makeAgent()
        let task = makeTask(assignedAgentId: agent.id)
        let resumeCtx = makeResumeContext()

        let snapshot = AgentStateSnapshot(
            savedAt: Date(),
            appVersion: "1.0.0-test",
            agents: [agent],
            tasks: [task],
            resumeContexts: [resumeCtx]
        )

        persistenceManager.saveSnapshot(snapshot)

        let loaded = persistenceManager.loadSnapshot()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.appVersion, "1.0.0-test")
        XCTAssertEqual(loaded?.agents.count, 1)
        XCTAssertEqual(loaded?.agents.first?.id, agent.id)
        XCTAssertEqual(loaded?.tasks.count, 1)
        XCTAssertEqual(loaded?.tasks.first?.title, "Test Task")
        XCTAssertEqual(loaded?.resumeContexts.count, 1)
        XCTAssertEqual(loaded?.resumeContexts.first?.agentId, resumeCtx.agentId)

        // Cleanup
        persistenceManager.removeSnapshot()
        XCTAssertNil(persistenceManager.loadSnapshot())
    }

    func testSaveAndLoadTaskQueue() {
        let commanderId = UUID()
        let item1Id = UUID()
        let item2Id = UUID()

        let item1 = makeQueueItem(
            id: item1Id,
            commanderId: commanderId,
            orchestrationTaskIndex: 0,
            dependencies: [],
            status: .pending
        )
        let item2 = makeQueueItem(
            id: item2Id,
            commanderId: commanderId,
            orchestrationTaskIndex: 1,
            dependencies: [0],
            status: .pending
        )

        persistenceManager.saveTaskQueue(commanderId: commanderId, items: [item1, item2])

        let loaded = persistenceManager.loadTaskQueue(commanderId: commanderId)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, item1Id)
        XCTAssertEqual(loaded[1].id, item2Id)
        XCTAssertEqual(loaded[1].dependencies, [0])

        // Cleanup
        persistenceManager.removeTaskQueue(commanderId: commanderId)
        XCTAssertTrue(persistenceManager.loadTaskQueue(commanderId: commanderId).isEmpty)
    }

    // MARK: - 4. SubAgentTaskQueueManager Operations

    func testEnqueueAndDequeueFlow() {
        let commanderId = UUID()

        // Enqueue two items: item0 has no deps, item1 depends on item0
        let item0 = makeQueueItem(
            commanderId: commanderId,
            orchestrationTaskIndex: 0,
            dependencies: []
        )
        let item1 = makeQueueItem(
            commanderId: commanderId,
            orchestrationTaskIndex: 1,
            dependencies: [0]
        )

        taskQueueManager.enqueue(item0)
        taskQueueManager.enqueue(item1)

        XCTAssertEqual(taskQueueManager.totalCount(commanderId: commanderId), 2)

        // Resolve ready: item0 has no deps so should become ready; item1 still pending
        taskQueueManager.resolveReady(commanderId: commanderId)

        let queue = taskQueueManager.queues[commanderId]!
        XCTAssertEqual(queue[0].status, .ready)
        XCTAssertEqual(queue[1].status, .pending, "Item1 depends on item0 which is not completed")

        // Dequeue the ready item
        let dequeued = taskQueueManager.dequeueReady(commanderId: commanderId)
        XCTAssertNotNil(dequeued)
        XCTAssertEqual(dequeued?.orchestrationTaskIndex, 0)
        XCTAssertEqual(dequeued?.status, .inProgress)
        XCTAssertNotNil(dequeued?.startedAt)
        XCTAssertTrue(taskQueueManager.hasInProgressItems(commanderId: commanderId))
    }

    func testMarkCompletedUnlocksDependents() {
        let commanderId = UUID()
        let item0Id = UUID()
        let item1Id = UUID()

        let item0 = makeQueueItem(
            id: item0Id,
            commanderId: commanderId,
            orchestrationTaskIndex: 0,
            dependencies: []
        )
        let item1 = makeQueueItem(
            id: item1Id,
            commanderId: commanderId,
            orchestrationTaskIndex: 1,
            dependencies: [0]
        )

        taskQueueManager.enqueue(item0)
        taskQueueManager.enqueue(item1)

        // Resolve and dequeue item0
        taskQueueManager.resolveReady(commanderId: commanderId)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)

        // Mark item0 completed
        taskQueueManager.markCompleted(itemId: item0Id, commanderId: commanderId, result: "Success")

        // Verify item0 is completed
        let completedItem = taskQueueManager.queues[commanderId]?.first { $0.id == item0Id }
        XCTAssertEqual(completedItem?.status, .completed)
        XCTAssertNotNil(completedItem?.completedAt)
        XCTAssertEqual(completedItem?.result, "Success")

        // Resolve again: item1 should now become ready since item0 is completed
        taskQueueManager.resolveReady(commanderId: commanderId)
        let item1Status = taskQueueManager.queues[commanderId]?.first { $0.id == item1Id }?.status
        XCTAssertEqual(item1Status, .ready, "Item1 should be ready after its dependency completes")
    }

    func testSuspendAndResumeQueueItem() {
        let commanderId = UUID()
        let itemId = UUID()

        let item = makeQueueItem(
            id: itemId,
            commanderId: commanderId,
            orchestrationTaskIndex: 0,
            dependencies: []
        )

        taskQueueManager.enqueue(item)
        taskQueueManager.resolveReady(commanderId: commanderId)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)

        // Now item is inProgress; suspend it
        taskQueueManager.suspend(itemId: itemId, commanderId: commanderId)

        let suspended = taskQueueManager.queues[commanderId]?.first { $0.id == itemId }
        XCTAssertEqual(suspended?.status, .suspended)
        XCTAssertNotNil(suspended?.suspendedAt)
        XCTAssertTrue(taskQueueManager.hasSuspendedItems(commanderId: commanderId))

        // Resume it
        taskQueueManager.resume(itemId: itemId, commanderId: commanderId)

        let resumed = taskQueueManager.queues[commanderId]?.first { $0.id == itemId }
        XCTAssertEqual(resumed?.status, .ready)
        XCTAssertNil(resumed?.suspendedAt)
        XCTAssertFalse(taskQueueManager.hasSuspendedItems(commanderId: commanderId))
    }

    func testRetryFailedQueueItem() {
        let commanderId = UUID()
        let itemId = UUID()

        let item = makeQueueItem(
            id: itemId,
            commanderId: commanderId,
            orchestrationTaskIndex: 0,
            dependencies: []
        )

        taskQueueManager.enqueue(item)
        taskQueueManager.resolveReady(commanderId: commanderId)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)

        // Mark as failed
        taskQueueManager.markFailed(itemId: itemId, commanderId: commanderId, error: "Connection timeout")

        let failed = taskQueueManager.queues[commanderId]?.first { $0.id == itemId }
        XCTAssertEqual(failed?.status, .failed)
        XCTAssertEqual(failed?.error, "Connection timeout")
        XCTAssertTrue(failed?.canRetry ?? false, "Should be retryable with retryCount 0")

        // Retry
        taskQueueManager.retry(itemId: itemId, commanderId: commanderId)

        let retried = taskQueueManager.queues[commanderId]?.first { $0.id == itemId }
        XCTAssertEqual(retried?.status, .ready)
        XCTAssertEqual(retried?.retryCount, 1)
        XCTAssertNil(retried?.error)
        XCTAssertNil(retried?.completedAt)
    }

    func testQueueFinishedDetection() {
        let commanderId = UUID()
        let item0Id = UUID()
        let item1Id = UUID()

        let item0 = makeQueueItem(id: item0Id, commanderId: commanderId, orchestrationTaskIndex: 0)
        let item1 = makeQueueItem(id: item1Id, commanderId: commanderId, orchestrationTaskIndex: 1)

        taskQueueManager.enqueue(item0)
        taskQueueManager.enqueue(item1)

        XCTAssertFalse(taskQueueManager.isQueueFinished(commanderId: commanderId))

        // Complete item0, fail item1
        taskQueueManager.resolveReady(commanderId: commanderId)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)
        taskQueueManager.markCompleted(itemId: item0Id, commanderId: commanderId, result: "done")

        taskQueueManager.resolveReady(commanderId: commanderId)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)
        taskQueueManager.markFailed(itemId: item1Id, commanderId: commanderId, error: "err")

        XCTAssertTrue(taskQueueManager.isQueueFinished(commanderId: commanderId),
                      "Queue should be finished when all items are terminal")
        XCTAssertEqual(taskQueueManager.completedCount(commanderId: commanderId), 1)
    }

    func testSuspendAllQueueItems() {
        let commanderId = UUID()

        let item0 = makeQueueItem(commanderId: commanderId, orchestrationTaskIndex: 0)
        let item1 = makeQueueItem(commanderId: commanderId, orchestrationTaskIndex: 1)

        taskQueueManager.enqueue(item0)
        taskQueueManager.enqueue(item1)
        taskQueueManager.resolveReady(commanderId: commanderId)

        // Dequeue both (both are independent, no deps)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)
        // Make item1 ready too
        taskQueueManager.resolveReady(commanderId: commanderId)
        _ = taskQueueManager.dequeueReady(commanderId: commanderId)

        // Suspend all
        taskQueueManager.suspendAll(commanderId: commanderId)

        let items = taskQueueManager.queues[commanderId]!
        for item in items {
            if item.status != .completed && item.status != .failed {
                XCTAssertEqual(item.status, .suspended,
                               "All in-progress items should be suspended")
            }
        }
    }

    // MARK: - 5. Full Lifecycle with Pool Reuse

    func testFullLifecycleWithPoolReuse() {
        let agentId = UUID()

        // Phase 1: initializing -> idle -> working -> completed
        lifecycleManager.registerAgent(agentId, initialState: .initializing)

        lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .idle)

        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .working)

        lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .completed)

        // Phase 2: completed -> pooled (return to pool)
        let pooledState = lifecycleManager.fireEvent(
            .returnToPool,
            forAgent: agentId,
            poolCapacity: 12,
            currentPoolSize: 3
        )
        XCTAssertEqual(pooledState, .pooled)
        XCTAssertTrue(lifecycleManager.agents(in: .pooled).contains(agentId))

        // Phase 3: pooled -> initializing (assign task from pool)
        let reInitState = lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertEqual(reInitState, .initializing)

        // Phase 4: back to active cycle
        lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .idle)

        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .working)

        // Verify the agent went through the full cycle
        XCTAssertEqual(lifecycleManager.runningProcessCount, 1)
    }

    func testPoolReturnRejectedWhenPoolFull() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)

        // Try to return to pool when pool is full
        let result = lifecycleManager.fireEvent(
            .returnToPool,
            forAgent: agentId,
            poolCapacity: 12,
            currentPoolSize: 12
        )
        XCTAssertNil(result, "Should not pool when pool is at capacity")
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .completed)
    }

    func testCompletedToNewTaskDirectAssignment() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .completed)

        // Direct new task assignment without pooling
        let newWorkState = lifecycleManager.fireEvent(.assignNewTask, forAgent: agentId)
        XCTAssertEqual(newWorkState, .working)
    }

    func testWorkingWithThinkingCycle() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)

        // working -> thinking -> working -> thinking -> working -> completed
        lifecycleManager.fireEvent(.aiReasoning, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .thinking)

        lifecycleManager.fireEvent(.toolInvoked, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .working)

        lifecycleManager.fireEvent(.aiReasoning, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .thinking)

        lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .completed)
    }

    // MARK: - 6. Emergency Cleanup Under Pressure

    func testEmergencyCleanupDestroysCleanupCandidatesAndPooled() {
        let activeAgentId = UUID()
        let idleAgentId = UUID()
        let completedAgentId = UUID()
        let pooledAgentId = UUID()
        let errorAgentId = UUID()
        let suspendedIdleAgentId = UUID()

        // Active agent: working (should survive)
        lifecycleManager.registerAgent(activeAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: activeAgentId)
        XCTAssertEqual(lifecycleManager.currentState(for: activeAgentId), .working)

        // Idle agent: cleanup candidate (should be destroyed)
        lifecycleManager.registerAgent(idleAgentId, initialState: .idle)

        // Completed agent: cleanup candidate (should be destroyed)
        lifecycleManager.registerAgent(completedAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: completedAgentId)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: completedAgentId)

        // Pooled agent: should be destroyed
        lifecycleManager.registerAgent(pooledAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.poolReturn, forAgent: pooledAgentId, poolCapacity: 12, currentPoolSize: 0)
        XCTAssertEqual(lifecycleManager.currentState(for: pooledAgentId), .pooled)

        // Error agent: cleanup candidate (should be destroyed)
        lifecycleManager.registerAgent(errorAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: errorAgentId)
        lifecycleManager.fireEvent(.taskFailed, forAgent: errorAgentId)
        XCTAssertEqual(lifecycleManager.currentState(for: errorAgentId), .error)

        // SuspendedIdle agent: cleanup candidate (should be destroyed)
        lifecycleManager.registerAgent(suspendedIdleAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.idleTimeout, forAgent: suspendedIdleAgentId)
        XCTAssertEqual(lifecycleManager.currentState(for: suspendedIdleAgentId), .suspendedIdle)

        // Verify pre-cleanup state
        XCTAssertEqual(lifecycleManager.totalManagedAgents, 6)

        // Emergency cleanup!
        var emergencyCallbackFired = false
        lifecycleManager.onEmergencyCleanupRequested = {
            emergencyCallbackFired = true
        }
        lifecycleManager.emergencyCleanup()

        // Active agent should survive
        XCTAssertEqual(lifecycleManager.currentState(for: activeAgentId), .working,
                       "Working agent must survive emergency cleanup")

        // All cleanup candidates and pooled agents should be destroyed
        XCTAssertEqual(lifecycleManager.currentState(for: idleAgentId), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: completedAgentId), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: pooledAgentId), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: errorAgentId), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: suspendedIdleAgentId), .destroyed)

        // Callback should have fired
        XCTAssertTrue(emergencyCallbackFired, "Emergency cleanup callback should fire")
    }

    func testEmergencyCleanupPreservesThinkingAgent() {
        let thinkingId = UUID()
        let pooledId = UUID()

        // Thinking agent (active, should survive)
        lifecycleManager.registerAgent(thinkingId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: thinkingId)
        lifecycleManager.fireEvent(.aiReasoning, forAgent: thinkingId)
        XCTAssertEqual(lifecycleManager.currentState(for: thinkingId), .thinking)

        // Pooled agent (should be destroyed)
        lifecycleManager.registerAgent(pooledId, initialState: .idle)
        lifecycleManager.fireEvent(.poolReturn, forAgent: pooledId, poolCapacity: 12, currentPoolSize: 0)

        lifecycleManager.emergencyCleanup()

        XCTAssertEqual(lifecycleManager.currentState(for: thinkingId), .thinking,
                       "Thinking agent must survive emergency cleanup")
        XCTAssertEqual(lifecycleManager.currentState(for: pooledId), .destroyed)
    }

    func testEmergencyCleanupPreservesInteractionAgents() {
        let permAgentId = UUID()
        let answerAgentId = UUID()
        let reviewAgentId = UUID()

        // requestingPermission (active, should survive)
        lifecycleManager.registerAgent(permAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: permAgentId)
        lifecycleManager.fireEvent(.permissionNeeded, forAgent: permAgentId)

        // waitingForAnswer (active, should survive)
        lifecycleManager.registerAgent(answerAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: answerAgentId)
        lifecycleManager.fireEvent(.questionAsked, forAgent: answerAgentId)

        // reviewingPlan (active, should survive)
        lifecycleManager.registerAgent(reviewAgentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: reviewAgentId)
        lifecycleManager.fireEvent(.planReady, forAgent: reviewAgentId)

        lifecycleManager.emergencyCleanup()

        XCTAssertEqual(lifecycleManager.currentState(for: permAgentId), .requestingPermission)
        XCTAssertEqual(lifecycleManager.currentState(for: answerAgentId), .waitingForAnswer)
        XCTAssertEqual(lifecycleManager.currentState(for: reviewAgentId), .reviewingPlan)
    }

    // MARK: - 7. Team Disband Flow

    func testBeginDestroyingAndCompleteDestruction() {
        let agent1 = UUID()
        let agent2 = UUID()
        let agent3 = UUID()

        lifecycleManager.registerAgent(agent1, initialState: .idle)
        lifecycleManager.registerAgent(agent2, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agent2)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: agent2)
        lifecycleManager.registerAgent(agent3, initialState: .idle)
        lifecycleManager.fireEvent(.poolReturn, forAgent: agent3, poolCapacity: 12, currentPoolSize: 0)

        // Verify initial states
        XCTAssertEqual(lifecycleManager.currentState(for: agent1), .idle)
        XCTAssertEqual(lifecycleManager.currentState(for: agent2), .completed)
        XCTAssertEqual(lifecycleManager.currentState(for: agent3), .pooled)

        // Begin destroying all three
        let agentIds: Set<UUID> = [agent1, agent2, agent3]
        lifecycleManager.beginDestroyingAgents(agentIds)

        XCTAssertEqual(lifecycleManager.currentState(for: agent1), .destroying)
        XCTAssertEqual(lifecycleManager.currentState(for: agent2), .destroying)
        XCTAssertEqual(lifecycleManager.currentState(for: agent3), .destroying)

        // Complete destruction (simulating animation complete)
        lifecycleManager.completeDestruction(for: agentIds)

        XCTAssertEqual(lifecycleManager.currentState(for: agent1), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: agent2), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: agent3), .destroyed)
    }

    func testBeginDestroyingSkipsAlreadyDestroyedAgents() {
        let agent1 = UUID()
        let agent2 = UUID()

        lifecycleManager.registerAgent(agent1, initialState: .idle)

        // Manually set agent2 to destroyed (via emergency cleanup scenario)
        lifecycleManager.registerAgent(agent2, initialState: .idle)
        lifecycleManager.fireEvent(.idleTimeout, forAgent: agent2)
        lifecycleManager.fireEvent(.cleanupTriggered, forAgent: agent2)
        lifecycleManager.fireEvent(.animationComplete, forAgent: agent2)
        XCTAssertEqual(lifecycleManager.currentState(for: agent2), .destroyed)

        // Begin destroying both
        lifecycleManager.beginDestroyingAgents([agent1, agent2])

        XCTAssertEqual(lifecycleManager.currentState(for: agent1), .destroying,
                       "Non-destroyed agent should transition to destroying")
        XCTAssertEqual(lifecycleManager.currentState(for: agent2), .destroyed,
                       "Already destroyed agent should remain destroyed")
    }

    func testCompleteDestructionOnlyAffectsDestroyingAgents() {
        let destroyingAgent = UUID()
        let idleAgent = UUID()

        lifecycleManager.registerAgent(destroyingAgent, initialState: .idle)
        lifecycleManager.registerAgent(idleAgent, initialState: .idle)

        lifecycleManager.beginDestroyingAgents([destroyingAgent])
        XCTAssertEqual(lifecycleManager.currentState(for: destroyingAgent), .destroying)

        // Try to complete destruction for both
        lifecycleManager.completeDestruction(for: [destroyingAgent, idleAgent])

        XCTAssertEqual(lifecycleManager.currentState(for: destroyingAgent), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: idleAgent), .idle,
                       "Idle agent should not be affected by completeDestruction")
    }

    func testTeamDisbandViaLifecycleEvents() {
        let commander = UUID()
        let sub1 = UUID()
        let sub2 = UUID()

        lifecycleManager.registerAgent(commander, initialState: .idle)
        lifecycleManager.registerAgent(sub1, initialState: .idle)
        lifecycleManager.registerAgent(sub2, initialState: .idle)

        // Simulate team work completion
        lifecycleManager.fireEvent(.assignTask, forAgent: commander)
        lifecycleManager.fireEvent(.assignTask, forAgent: sub1)
        lifecycleManager.fireEvent(.assignTask, forAgent: sub2)

        lifecycleManager.fireEvent(.taskCompleted, forAgent: sub1)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: sub2)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: commander)

        // Trigger disband via event for each agent
        let res1 = lifecycleManager.fireEvent(.disbandScheduled, forAgent: commander)
        let res2 = lifecycleManager.fireEvent(.disbandScheduled, forAgent: sub1)
        let res3 = lifecycleManager.fireEvent(.disbandScheduled, forAgent: sub2)

        XCTAssertEqual(res1, .destroying)
        XCTAssertEqual(res2, .destroying)
        XCTAssertEqual(res3, .destroying)

        // Animation complete
        lifecycleManager.fireEvent(.animationComplete, forAgent: commander)
        lifecycleManager.fireEvent(.animationComplete, forAgent: sub1)
        lifecycleManager.fireEvent(.animationComplete, forAgent: sub2)

        XCTAssertEqual(lifecycleManager.currentState(for: commander), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: sub1), .destroyed)
        XCTAssertEqual(lifecycleManager.currentState(for: sub2), .destroyed)
    }

    func testTeamDisbandCallbackFires() {
        var callbackCommanderId: UUID?

        lifecycleManager.onTeamDisbandRequested = { commanderId in
            callbackCommanderId = commanderId
        }

        let commanderId = UUID()
        lifecycleManager.initiateTeamDisband(commanderId: commanderId)

        XCTAssertEqual(callbackCommanderId, commanderId,
                       "Team disband callback should fire with the commander's ID")
    }

    // MARK: - Additional Integration: State Change Callbacks

    func testOnStateChangedCallbackFires() {
        var transitions: [(UUID, AgentLifecycleState, AgentLifecycleState, LifecycleEvent)] = []

        lifecycleManager.onStateChanged = { agentId, from, to, event in
            transitions.append((agentId, from, to, event))
        }

        let agentId = UUID()
        lifecycleManager.registerAgent(agentId, initialState: .initializing)
        lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)

        XCTAssertEqual(transitions.count, 2)
        XCTAssertEqual(transitions[0].1, .initializing) // from
        XCTAssertEqual(transitions[0].2, .idle)          // to
        XCTAssertEqual(transitions[0].3, .resourcesLoaded)
        XCTAssertEqual(transitions[1].1, .idle)
        XCTAssertEqual(transitions[1].2, .working)
        XCTAssertEqual(transitions[1].3, .assignTask)
    }

    // MARK: - Additional Integration: Logger Metrics

    func testLoggerRecordsTransitionMetrics() {
        let logger = lifecycleManager.logger
        logger.clear()

        let agentId = UUID()
        lifecycleManager.registerAgent(agentId, initialState: .initializing)
        lifecycleManager.fireEvent(.resourcesLoaded, forAgent: agentId)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)

        // Register counts as a transition too via logTransition
        XCTAssertGreaterThanOrEqual(logger.metrics.totalTransitions, 3)
        XCTAssertEqual(logger.metrics.invalidTransitions, 0)
    }

    func testLoggerRecordsInvalidTransitions() {
        let logger = lifecycleManager.logger
        logger.clear()

        let agentId = UUID()
        lifecycleManager.registerAgent(agentId, initialState: .initializing)

        // Try invalid event
        let result = lifecycleManager.fireEvent(.taskCompleted, forAgent: agentId)
        XCTAssertNil(result, "taskCompleted is invalid from .initializing")
        XCTAssertGreaterThanOrEqual(logger.metrics.invalidTransitions, 1)
    }

    // MARK: - Additional Integration: Queried Agent Collections

    func testAgentsInStateQuery() {
        let idle1 = UUID()
        let idle2 = UUID()
        let working1 = UUID()

        lifecycleManager.registerAgent(idle1, initialState: .idle)
        lifecycleManager.registerAgent(idle2, initialState: .idle)
        lifecycleManager.registerAgent(working1, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: working1)

        let idleAgents = lifecycleManager.agents(in: .idle)
        XCTAssertTrue(idleAgents.contains(idle1))
        XCTAssertTrue(idleAgents.contains(idle2))
        XCTAssertFalse(idleAgents.contains(working1))

        let workingAgents = lifecycleManager.agents(in: .working)
        XCTAssertTrue(workingAgents.contains(working1))
    }

    func testAvailableAgentsQuery() {
        let idleAgent = UUID()
        let pooledAgent = UUID()
        let workingAgent = UUID()
        let suspIdleAgent = UUID()

        lifecycleManager.registerAgent(idleAgent, initialState: .idle)

        lifecycleManager.registerAgent(pooledAgent, initialState: .idle)
        lifecycleManager.fireEvent(.poolReturn, forAgent: pooledAgent, poolCapacity: 12, currentPoolSize: 0)

        lifecycleManager.registerAgent(workingAgent, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: workingAgent)

        lifecycleManager.registerAgent(suspIdleAgent, initialState: .idle)
        lifecycleManager.fireEvent(.idleTimeout, forAgent: suspIdleAgent)

        let available = lifecycleManager.availableAgents()
        XCTAssertTrue(available.contains(idleAgent))
        XCTAssertTrue(available.contains(pooledAgent))
        XCTAssertTrue(available.contains(suspIdleAgent))
        XCTAssertFalse(available.contains(workingAgent))
    }

    func testCleanupCandidatesQuery() {
        let idleAgent = UUID()
        let completedAgent = UUID()
        let errorAgent = UUID()
        let suspIdleAgent = UUID()
        let workingAgent = UUID()

        lifecycleManager.registerAgent(idleAgent, initialState: .idle)

        lifecycleManager.registerAgent(completedAgent, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: completedAgent)
        lifecycleManager.fireEvent(.taskCompleted, forAgent: completedAgent)

        lifecycleManager.registerAgent(errorAgent, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: errorAgent)
        lifecycleManager.fireEvent(.taskFailed, forAgent: errorAgent)

        lifecycleManager.registerAgent(suspIdleAgent, initialState: .idle)
        lifecycleManager.fireEvent(.idleTimeout, forAgent: suspIdleAgent)

        lifecycleManager.registerAgent(workingAgent, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: workingAgent)

        let candidates = lifecycleManager.cleanupCandidates()
        XCTAssertTrue(candidates.contains(idleAgent))
        XCTAssertTrue(candidates.contains(completedAgent))
        XCTAssertTrue(candidates.contains(errorAgent))
        XCTAssertTrue(candidates.contains(suspIdleAgent))
        XCTAssertFalse(candidates.contains(workingAgent))
    }

    // MARK: - Error -> Retry Flow

    func testErrorAgentRetryToWorking() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.taskFailed, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .error)

        let retryState = lifecycleManager.fireEvent(.retry, forAgent: agentId)
        XCTAssertEqual(retryState, .working)
    }

    // MARK: - Suspended -> Cancel Flow

    func testSuspendedAgentCancelToError() {
        let agentId = UUID()

        lifecycleManager.registerAgent(agentId, initialState: .idle)
        lifecycleManager.fireEvent(.assignTask, forAgent: agentId)
        lifecycleManager.fireEvent(.permissionNeeded, forAgent: agentId)
        lifecycleManager.fireEvent(.processTerminated, forAgent: agentId)
        XCTAssertEqual(lifecycleManager.currentState(for: agentId), .suspended)

        let cancelState = lifecycleManager.fireEvent(.cancel, forAgent: agentId)
        XCTAssertEqual(cancelState, .error)
    }

    // MARK: - Evict Oldest Pooled Agents

    func testEvictOldestPooledAgents() {
        let pooled1 = UUID()
        let pooled2 = UUID()
        let pooled3 = UUID()

        for id in [pooled1, pooled2, pooled3] {
            lifecycleManager.registerAgent(id, initialState: .idle)
            lifecycleManager.fireEvent(.poolReturn, forAgent: id, poolCapacity: 12, currentPoolSize: 0)
            XCTAssertEqual(lifecycleManager.currentState(for: id), .pooled)
        }

        // Evict 2 pooled agents
        lifecycleManager.evictOldestPooledAgents(count: 2)

        let pooledAgents = lifecycleManager.agents(in: .pooled)
        let destroyingAgents = lifecycleManager.agents(in: .destroying)

        // 2 should have been evicted (moved to destroying)
        XCTAssertEqual(destroyingAgents.count, 2)
        XCTAssertEqual(pooledAgents.count, 1)
    }
}
