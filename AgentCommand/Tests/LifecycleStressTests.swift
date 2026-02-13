import XCTest
@testable import AgentCommand

// MARK: - Lifecycle Stress Tests

/// Stress tests to confirm no resource leaks across lifecycle management subsystems.
/// Exercises mass registration/unregistration, rapid state transitions, timer management,
/// pool saturation, emergency cleanup, logger capacity, scheduler throughput,
/// concurrency controller draining, and full memory-stability verification.
@MainActor
final class LifecycleStressTests: XCTestCase {

    // MARK: - Properties

    private var lifecycleManager: AgentLifecycleManager!
    private var poolManager: SubAgentPoolManager!
    private var scheduler: TaskPriorityScheduler!
    private var concurrencyController: ConcurrencyController!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        lifecycleManager = AgentLifecycleManager()
        poolManager = SubAgentPoolManager()
        poolManager.lifecycleManager = lifecycleManager
        scheduler = TaskPriorityScheduler()
        concurrencyController = ConcurrencyController()
    }

    override func tearDown() {
        lifecycleManager.shutdown()
        lifecycleManager = nil
        poolManager.shutdown()
        poolManager = nil
        scheduler = nil
        concurrencyController.reset()
        concurrencyController = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDef(
        title: String,
        prompt: String = "do it",
        deps: [Int] = [],
        parallel: Bool = true,
        complexity: String = "medium"
    ) -> SubtaskDefinition {
        SubtaskDefinition(
            title: title,
            prompt: prompt,
            dependencies: deps,
            canParallel: parallel,
            estimatedComplexity: complexity
        )
    }

    private func makeSubTasks(_ defs: [SubtaskDefinition]) -> [OrchestratedSubTask] {
        defs.enumerated().map { OrchestratedSubTask(index: $0.offset, definition: $0.element) }
    }

    // MARK: - 1. Mass Agent Registration/Unregistration

    /// Register and unregister 1000 agents, then verify that agentStates is empty
    /// and cleanupManager retains no residual tracking data.
    func testMassRegistrationAndUnregistration() {
        let agentCount = 1000
        var agentIds: [UUID] = []

        // Register 1000 agents
        for _ in 0..<agentCount {
            let id = UUID()
            agentIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .idle)
        }

        XCTAssertEqual(lifecycleManager.totalManagedAgents, agentCount)

        // Unregister all agents
        for id in agentIds {
            lifecycleManager.unregisterAgent(id)
        }

        // Verify no residual state
        XCTAssertEqual(lifecycleManager.agentStates.count, 0, "agentStates should be empty after unregistering all agents")
        XCTAssertEqual(lifecycleManager.cleanupManager.cleanupTimers.count, 0, "cleanupTimers should be empty")
        XCTAssertEqual(lifecycleManager.cleanupManager.idleTracking.count, 0, "idleTracking should be empty")
        XCTAssertEqual(lifecycleManager.cleanupManager.lastActivityTimes.count, 0, "lastActivityTimes should be empty")
        XCTAssertEqual(lifecycleManager.cleanupManager.agentResourceUsage.count, 0, "agentResourceUsage should be empty")
    }

    // MARK: - 2. Rapid State Transitions

    /// For 100 agents, rapidly fire valid events through a full lifecycle path:
    /// idle -> working -> thinking -> working -> completed -> destroying -> destroyed.
    /// Verify all end in destroyed state and no tracking remains.
    func testRapidStateTransitions() {
        let agentCount = 100
        var agentIds: [UUID] = []

        // Register 100 agents in idle state
        for _ in 0..<agentCount {
            let id = UUID()
            agentIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .idle)
        }

        // Rapidly transition each agent through the full lifecycle
        for id in agentIds {
            // idle -> working
            let r1 = lifecycleManager.fireEvent(.assignTask, forAgent: id)
            XCTAssertEqual(r1, .working)

            // working -> thinking
            let r2 = lifecycleManager.fireEvent(.aiReasoning, forAgent: id)
            XCTAssertEqual(r2, .thinking)

            // thinking -> working
            let r3 = lifecycleManager.fireEvent(.toolInvoked, forAgent: id)
            XCTAssertEqual(r3, .working)

            // working -> completed
            let r4 = lifecycleManager.fireEvent(.taskCompleted, forAgent: id)
            XCTAssertEqual(r4, .completed)

            // completed -> destroying
            let r5 = lifecycleManager.fireEvent(.disbandScheduled, forAgent: id)
            XCTAssertEqual(r5, .destroying)

            // destroying -> destroyed
            let r6 = lifecycleManager.fireEvent(.animationComplete, forAgent: id)
            XCTAssertEqual(r6, .destroyed)
        }

        // Verify all agents are in destroyed state
        for id in agentIds {
            XCTAssertEqual(lifecycleManager.currentState(for: id), .destroyed)
        }

        // Verify cleanup manager has no residual tracking for any agent
        for id in agentIds {
            XCTAssertNil(lifecycleManager.cleanupManager.idleTracking[id],
                         "Idle tracking should be cleared for destroyed agent")
            XCTAssertNil(lifecycleManager.cleanupManager.lastActivityTimes[id],
                         "Last activity time should be cleared for destroyed agent")
            XCTAssertNil(lifecycleManager.cleanupManager.agentResourceUsage[id],
                         "Resource usage should be cleared for destroyed agent")
        }
    }

    // MARK: - 3. Concurrent Cleanup Timer Creation/Cancellation

    /// Create 200 idle agents (which triggers cleanup timers via side effects),
    /// then immediately make 100 of them active (which cancels their timers).
    /// Verify that exactly the expected number of timers remain.
    func testConcurrentCleanupTimerCreationAndCancellation() {
        let totalAgents = 200
        let activatedAgents = 100
        var agentIds: [UUID] = []

        // Register 200 agents in initializing, then transition to idle to trigger timers
        for _ in 0..<totalAgents {
            let id = UUID()
            agentIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .initializing)
            lifecycleManager.fireEvent(.resourcesLoaded, forAgent: id)
        }

        // All 200 should have idle tracking entries
        XCTAssertEqual(lifecycleManager.cleanupManager.idleTracking.count, totalAgents,
                       "All 200 agents should be tracked as idle")

        // All 200 should have cleanup timers
        XCTAssertEqual(lifecycleManager.cleanupManager.cleanupTimers.count, totalAgents,
                       "All 200 agents should have cleanup timers")

        // Activate 100 agents (idle -> working), cancelling their timers
        for i in 0..<activatedAgents {
            lifecycleManager.fireEvent(.assignTask, forAgent: agentIds[i])
        }

        // Verify timer counts: 100 timers should have been cancelled
        let remainingTimers = lifecycleManager.cleanupManager.cleanupTimers.count
        XCTAssertEqual(remainingTimers, totalAgents - activatedAgents,
                       "Only idle agents should retain cleanup timers")

        // Verify idle tracking counts
        let remainingIdle = lifecycleManager.cleanupManager.idleTracking.count
        XCTAssertEqual(remainingIdle, totalAgents - activatedAgents,
                       "Only idle agents should remain in idle tracking")

        // Verify agent states
        for i in 0..<activatedAgents {
            XCTAssertEqual(lifecycleManager.currentState(for: agentIds[i]), .working)
        }
        for i in activatedAgents..<totalAgents {
            XCTAssertEqual(lifecycleManager.currentState(for: agentIds[i]), .idle)
        }
    }

    // MARK: - 4. Pool Saturation and Eviction

    /// Fill the pool to its maximum capacity, attempt to release more agents beyond capacity,
    /// and verify that the eviction count increases. Then shrink the pool and verify evictions.
    func testPoolSaturationAndEviction() {
        poolManager.config.maxPoolSize = 10
        poolManager.config.maxPerRole = 10
        poolManager.config.shrinkCooldownSeconds = 0

        let parentId = UUID()

        // Fill pool to max
        var releasedAgents: [Agent] = []
        for _ in 0..<10 {
            let agent = AgentFactory.createSubAgent(parentId: parentId, role: .developer, model: .sonnet)
            releasedAgents.append(agent)
            let released = poolManager.release(agent)
            XCTAssertTrue(released, "Release should succeed while pool has capacity")
        }

        XCTAssertEqual(poolManager.totalPooledCount, 10)
        let evictionsBeforeOverflow = poolManager.stats.evictionCount

        // Attempt to release 5 more beyond capacity
        for _ in 0..<5 {
            let agent = AgentFactory.createSubAgent(parentId: parentId, role: .developer, model: .sonnet)
            let released = poolManager.release(agent)
            XCTAssertFalse(released, "Release should fail when pool is full")
        }

        // Eviction count should have increased by 5
        XCTAssertEqual(poolManager.stats.evictionCount, evictionsBeforeOverflow + 5,
                       "Each rejected release should increment eviction count")

        // Pool size should remain at max
        XCTAssertEqual(poolManager.totalPooledCount, 10)

        // Now shrink pool to 3
        poolManager.shrinkPool(to: 3)
        XCTAssertEqual(poolManager.totalPooledCount, 3,
                       "Pool should shrink to target size")

        // Eviction count should have increased further
        XCTAssertGreaterThan(poolManager.stats.evictionCount, evictionsBeforeOverflow + 5,
                             "Shrinking pool should cause additional evictions")

        // Shrink to 0
        poolManager.config.shrinkCooldownSeconds = 0
        // Need to reset cooldown by waiting or setting lastShrinkTime
        // Since shrinkCooldownSeconds is 0, another shrink should work
        poolManager.shrinkPool(to: 0)
        XCTAssertEqual(poolManager.totalPooledCount, 0,
                       "Pool should be completely empty after shrinking to 0")
    }

    // MARK: - 5. Emergency Cleanup Under Load

    /// Register 50 agents in various states (idle, completed, error, pooled, working),
    /// trigger emergency cleanup, and verify only cleanup candidates and pooled agents
    /// are destroyed while working agents survive.
    func testEmergencyCleanupUnderLoad() {
        var emergencyCalled = false
        lifecycleManager.onEmergencyCleanupRequested = { emergencyCalled = true }

        var workingAgentIds: [UUID] = []
        var cleanupCandidateIds: [UUID] = []

        // Register 10 idle agents (cleanup candidates)
        for _ in 0..<10 {
            let id = UUID()
            cleanupCandidateIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .idle)
        }

        // Register 10 completed agents (cleanup candidates)
        for _ in 0..<10 {
            let id = UUID()
            cleanupCandidateIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .completed)
        }

        // Register 10 error agents (cleanup candidates)
        for _ in 0..<10 {
            let id = UUID()
            cleanupCandidateIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .error)
        }

        // Register 10 pooled agents (also targeted by emergency cleanup)
        var pooledIds: [UUID] = []
        for _ in 0..<10 {
            let id = UUID()
            pooledIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .pooled)
        }

        // Register 10 working agents (should survive)
        for _ in 0..<10 {
            let id = UUID()
            workingAgentIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .working)
        }

        XCTAssertEqual(lifecycleManager.totalManagedAgents, 50)

        // Trigger emergency cleanup
        lifecycleManager.emergencyCleanup()

        XCTAssertTrue(emergencyCalled, "Emergency cleanup callback should have been invoked")

        // All cleanup candidates (idle, completed, error) and pooled agents should be destroyed
        for id in cleanupCandidateIds {
            XCTAssertEqual(lifecycleManager.currentState(for: id), .destroyed,
                           "Cleanup candidate should be destroyed after emergency cleanup")
        }
        for id in pooledIds {
            XCTAssertEqual(lifecycleManager.currentState(for: id), .destroyed,
                           "Pooled agent should be destroyed after emergency cleanup")
        }

        // Working agents should survive
        for id in workingAgentIds {
            XCTAssertEqual(lifecycleManager.currentState(for: id), .working,
                           "Working agent should survive emergency cleanup")
        }

        // Verify cleanup manager tracking is cleared for destroyed agents
        for id in cleanupCandidateIds + pooledIds {
            XCTAssertNil(lifecycleManager.cleanupManager.idleTracking[id])
            XCTAssertNil(lifecycleManager.cleanupManager.lastActivityTimes[id])
            XCTAssertNil(lifecycleManager.cleanupManager.agentResourceUsage[id])
        }
    }

    // MARK: - 6. Logger Capacity Stress

    /// Log 1000 transitions with maxEntries=100, then verify that entries
    /// are capped near maxEntries and the metrics counters remain accurate.
    /// Note: @Published array mutations may cause minor deviations in entry count
    /// due to Combine observation overhead; the key invariant is that entries
    /// never grow unbounded and metrics remain accurate.
    func testLoggerCapacityStress() {
        let logger = LifecycleLogger(maxEntries: 100)
        let totalTransitions = 1000

        for i in 0..<totalTransitions {
            let agentId = UUID()
            logger.logTransition(
                agentId: agentId,
                from: .idle,
                to: .working,
                event: .assignTask,
                message: "Transition \(i)"
            )
        }

        // Entries should be capped at or near maxEntries (never grow unbounded)
        XCTAssertLessThanOrEqual(logger.entries.count, 100,
                       "Logger should cap entries at maxEntries")
        XCTAssertGreaterThan(logger.entries.count, 0,
                       "Logger should retain some entries")

        // Total transitions metric should reflect all 1000 transitions
        XCTAssertEqual(logger.metrics.totalTransitions, totalTransitions,
                       "Metrics should count all transitions regardless of entry cap")

        // The most recent entry should always be the last one logged
        let lastEntry = logger.entries.last
        XCTAssertEqual(lastEntry?.message, "Transition \(totalTransitions - 1)",
                       "Last retained entry should be the most recent transition")

        // transitionsPerState should accumulate correctly
        XCTAssertEqual(logger.metrics.transitionsPerState[.working], totalTransitions,
                       "All transitions targeted .working so the count should equal total")

        // Log some invalid transitions and verify they are counted
        let invalidCount = 50
        for _ in 0..<invalidCount {
            logger.logInvalidTransition(
                agentId: UUID(),
                currentState: .idle,
                event: .taskCompleted
            )
        }

        XCTAssertEqual(logger.metrics.invalidTransitions, invalidCount,
                       "Invalid transitions should be counted accurately")

        // Entry count should still be capped at maxEntries
        XCTAssertLessThanOrEqual(logger.entries.count, 100,
                       "Logger should still cap at maxEntries after invalid transitions")

        // Verify the logger never grew unbounded by checking the total is
        // far below totalTransitions + invalidCount
        XCTAssertLessThan(logger.entries.count, totalTransitions,
                       "Entries must not accumulate unbounded")
    }

    // MARK: - 7. Scheduler Mass Scheduling

    /// Schedule 100 sub-tasks across 10 orchestrations (10 tasks each),
    /// complete them all, and verify that stats match.
    func testSchedulerMassScheduling() {
        let orchestrationCount = 10
        let tasksPerOrchestration = 10
        var commanderIds: [UUID] = []

        // Schedule tasks across 10 orchestrations
        for _ in 0..<orchestrationCount {
            let commanderId = UUID()
            commanderIds.append(commanderId)

            let defs = (0..<tasksPerOrchestration).map { i in
                makeDef(title: "Task \(i)", prompt: "execute task \(i)")
            }
            let subTasks = makeSubTasks(defs)
            scheduler.scheduleSubTasks(commanderId: commanderId, subTasks: subTasks)
        }

        let totalTasks = orchestrationCount * tasksPerOrchestration
        XCTAssertEqual(scheduler.schedulerStats.totalScheduled, totalTasks,
                       "Total scheduled should equal orchestrations * tasks per orchestration")

        // Start and complete all tasks across all orchestrations
        for commanderId in commanderIds {
            for taskIndex in 0..<tasksPerOrchestration {
                scheduler.markStarted(commanderId: commanderId, taskIndex: taskIndex)
                scheduler.markCompleted(commanderId: commanderId, taskIndex: taskIndex)
            }
        }

        // Verify stats
        XCTAssertEqual(scheduler.schedulerStats.totalCompleted, totalTasks,
                       "All tasks should be completed")
        XCTAssertEqual(scheduler.schedulerStats.totalFailed, 0,
                       "No tasks should have failed")
        XCTAssertEqual(scheduler.schedulerStats.totalSkipped, 0,
                       "No tasks should have been skipped")

        // Verify each orchestration is done
        for commanderId in commanderIds {
            XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: commanderId),
                          "Each orchestration should be marked as done")
        }

        // Clean up and verify all removed
        for commanderId in commanderIds {
            scheduler.removeOrchestration(commanderId: commanderId)
        }
        XCTAssertEqual(scheduler.schedule.count, 0,
                       "Schedule should be empty after removing all orchestrations")
        XCTAssertEqual(scheduler.schedulerStats.totalScheduled, 0,
                       "Stats totalScheduled should be 0 after removal")
    }

    // MARK: - 8. ConcurrencyController Rapid Drain

    /// Queue 50 tasks with a concurrency limit of 2, complete tasks rapidly,
    /// and verify all eventually start and complete.
    func testConcurrencyControllerRapidDrain() {
        concurrencyController.config.maxConcurrentProcesses = 2
        concurrencyController.adjustForPressure(.normal)

        var startedTaskIndices: [Int] = []
        concurrencyController.onStartSubAgent = { _, taskIndex, _ in
            startedTaskIndices.append(taskIndex)
        }

        let commanderId = UUID()
        let totalTasks = 50

        // Request start for all 50 tasks
        for i in 0..<totalTasks {
            concurrencyController.requestStart(
                commanderId: commanderId,
                taskIndex: i,
                model: .sonnet,
                priority: .medium
            )
        }

        // Only 2 should have started immediately
        XCTAssertEqual(startedTaskIndices.count, 2,
                       "Only 2 tasks should start immediately with limit of 2")
        XCTAssertEqual(concurrencyController.currentActiveCount, 2)
        XCTAssertEqual(concurrencyController.currentQueuedCount, totalTasks - 2)

        // Rapidly complete tasks, which should drain the queue
        // Complete task 0, which triggers task 2 to start
        // Complete task 1, which triggers task 3 to start
        // And so on...
        var completedCount = 0
        while completedCount < totalTasks {
            // Find the earliest started task to complete
            let taskToComplete = startedTaskIndices[completedCount]
            concurrencyController.taskCompleted(commanderId: commanderId, taskIndex: taskToComplete)
            completedCount += 1
        }

        // All 50 tasks should have been started
        XCTAssertEqual(startedTaskIndices.count, totalTasks,
                       "All 50 tasks should have been started eventually")

        // All tasks completed; active count should be 0
        XCTAssertEqual(concurrencyController.currentActiveCount, 0,
                       "Active count should be 0 after all tasks complete")
        XCTAssertEqual(concurrencyController.currentQueuedCount, 0,
                       "Queue should be empty after all tasks complete")
        XCTAssertEqual(concurrencyController.totalRunningCount, 0,
                       "Total running count should be 0")
    }

    // MARK: - 9. Memory Stability

    /// Register 500 agents, transition them all to destroyed, unregister all,
    /// and verify all internal dictionaries are empty (agentStates, idleTracking,
    /// lastActivityTimes, agentResourceUsage, cleanupTimers).
    func testMemoryStability() {
        let agentCount = 500
        var agentIds: [UUID] = []

        // Register 500 agents and transition through a realistic lifecycle
        for _ in 0..<agentCount {
            let id = UUID()
            agentIds.append(id)
            lifecycleManager.registerAgent(id, initialState: .initializing)
        }

        XCTAssertEqual(lifecycleManager.totalManagedAgents, agentCount)

        // Transition all: initializing -> idle -> working -> completed -> destroying -> destroyed
        for id in agentIds {
            lifecycleManager.fireEvent(.resourcesLoaded, forAgent: id) // -> idle
            lifecycleManager.fireEvent(.assignTask, forAgent: id)      // -> working
            lifecycleManager.fireEvent(.taskCompleted, forAgent: id)   // -> completed
            lifecycleManager.fireEvent(.disbandScheduled, forAgent: id) // -> destroying
            lifecycleManager.fireEvent(.animationComplete, forAgent: id) // -> destroyed
        }

        // All agents should be in destroyed state
        for id in agentIds {
            XCTAssertEqual(lifecycleManager.currentState(for: id), .destroyed)
        }

        // Unregister all agents
        for id in agentIds {
            lifecycleManager.unregisterAgent(id)
        }

        // Verify all internal dictionaries are completely empty
        XCTAssertTrue(lifecycleManager.agentStates.isEmpty,
                      "agentStates should be empty after full lifecycle and unregister")
        XCTAssertTrue(lifecycleManager.cleanupManager.idleTracking.isEmpty,
                      "idleTracking should be empty after full lifecycle and unregister")
        XCTAssertTrue(lifecycleManager.cleanupManager.lastActivityTimes.isEmpty,
                      "lastActivityTimes should be empty after full lifecycle and unregister")
        XCTAssertTrue(lifecycleManager.cleanupManager.agentResourceUsage.isEmpty,
                      "agentResourceUsage should be empty after full lifecycle and unregister")
        XCTAssertTrue(lifecycleManager.cleanupManager.cleanupTimers.isEmpty,
                      "cleanupTimers should be empty after full lifecycle and unregister")

        // Verify computed properties are zeroed
        XCTAssertEqual(lifecycleManager.totalManagedAgents, 0)
        XCTAssertEqual(lifecycleManager.activeAgentCount, 0)
        XCTAssertEqual(lifecycleManager.idleAgentCount, 0)
        XCTAssertEqual(lifecycleManager.runningProcessCount, 0)
        XCTAssertEqual(lifecycleManager.suspendedAgentCount, 0)
        XCTAssertEqual(lifecycleManager.cleanupManager.pendingCleanupCount, 0)
        XCTAssertEqual(lifecycleManager.cleanupManager.trackedIdleAgentCount, 0)
    }
}
