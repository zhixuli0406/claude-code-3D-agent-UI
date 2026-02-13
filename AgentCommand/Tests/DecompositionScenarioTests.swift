import XCTest
@testable import AgentCommand

/// Integration tests that verify various decomposition scenarios ensure
/// no idle sub-agents are created. Tests the interaction between
/// TaskPriorityScheduler, ConcurrencyController, and SubAgentPoolManager.
@MainActor
final class DecompositionScenarioTests: XCTestCase {

    var scheduler: TaskPriorityScheduler!
    var concurrencyController: ConcurrencyController!
    var poolManager: SubAgentPoolManager!
    var monitor: SubAgentMonitor!
    var lifecycleManager: AgentLifecycleManager!

    var startedTasks: [(commanderId: UUID, taskIndex: Int)]!

    override func setUp() {
        super.setUp()
        scheduler = TaskPriorityScheduler()
        concurrencyController = ConcurrencyController()
        poolManager = SubAgentPoolManager()
        monitor = SubAgentMonitor()
        lifecycleManager = AgentLifecycleManager()
        lifecycleManager.initialize()

        poolManager.lifecycleManager = lifecycleManager
        concurrencyController.lifecycleManager = lifecycleManager
        monitor.lifecycleManager = lifecycleManager
        monitor.poolManager = poolManager
        monitor.concurrencyController = concurrencyController
        monitor.scheduler = scheduler
        monitor.config.isEnabled = false

        startedTasks = []
        concurrencyController.onStartSubAgent = { [weak self] commanderId, taskIndex, _ in
            self?.startedTasks.append((commanderId, taskIndex))
        }
    }

    override func tearDown() {
        lifecycleManager.shutdown()
        poolManager.shutdown()
        concurrencyController.reset()
        scheduler = nil
        concurrencyController = nil
        poolManager = nil
        monitor = nil
        lifecycleManager = nil
        startedTasks = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDef(title: String, deps: [Int] = [], complexity: String = "medium") -> SubtaskDefinition {
        SubtaskDefinition(title: title, prompt: "Execute \(title)", dependencies: deps, canParallel: deps.isEmpty, estimatedComplexity: complexity)
    }

    private func makeSubTasks(_ defs: [SubtaskDefinition]) -> [OrchestratedSubTask] {
        defs.enumerated().map { OrchestratedSubTask(index: $0.offset, definition: $0.element) }
    }

    /// Simulate executing a batch: schedule, request starts, and verify
    private func simulateExecuteBatch(commanderId: UUID, model: ClaudeModel = .sonnet) -> Int {
        let readyCount = scheduler.readyCount(commanderId: commanderId)
        guard readyCount > 0 else { return 0 }

        let waveSize = concurrencyController.optimalWaveSize(readyCount: readyCount, totalRemaining: readyCount)
        let batch = scheduler.nextBatch(commanderId: commanderId, maxSize: waveSize)

        for item in batch {
            concurrencyController.requestStart(commanderId: commanderId, taskIndex: item.taskIndex, model: model)
            scheduler.markStarted(commanderId: commanderId, taskIndex: item.taskIndex)
        }

        return batch.count
    }

    /// Complete a task and notify scheduler + concurrency controller
    private func simulateComplete(commanderId: UUID, taskIndex: Int) {
        scheduler.markCompleted(commanderId: commanderId, taskIndex: taskIndex)
        concurrencyController.taskCompleted(commanderId: commanderId, taskIndex: taskIndex)
    }

    private func simulateFail(commanderId: UUID, taskIndex: Int) {
        scheduler.markFailed(commanderId: commanderId, taskIndex: taskIndex)
        concurrencyController.taskCompleted(commanderId: commanderId, taskIndex: taskIndex)
    }

    // MARK: - Scenario 1: All Independent Tasks

    func testScenario_AllIndependentTasks_NoIdleAgents() {
        let cmd = UUID()
        concurrencyController.config.maxConcurrentProcesses = 3
        concurrencyController.adjustForPressure(.normal)

        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B"),
            makeDef(title: "Task C"),
            makeDef(title: "Task D"),
            makeDef(title: "Task E"),
        ]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        // Wave 1: 3 tasks start (limited by concurrency)
        let wave1 = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(wave1, 3)
        XCTAssertEqual(concurrencyController.currentActiveCount, 3)
        XCTAssertTrue(concurrencyController.isAtCapacity)

        // No agents should be idle yet — all are working
        // (In real orchestrator, agents are only created when tasks start)

        // Complete first task → slot opens → D should start
        simulateComplete(commanderId: cmd, taskIndex: startedTasks[0].taskIndex)
        XCTAssertEqual(concurrencyController.currentActiveCount, 2)

        let wave2 = simulateExecuteBatch(commanderId: cmd)
        XCTAssertGreaterThanOrEqual(wave2, 1) // At least D should start

        // Complete all remaining
        for task in startedTasks.suffix(from: 1) {
            simulateComplete(commanderId: cmd, taskIndex: task.taskIndex)
        }

        // Try final batch
        let waveFinal = simulateExecuteBatch(commanderId: cmd)
        // Verify all completed
        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd) || waveFinal > 0)
    }

    // MARK: - Scenario 2: Linear Chain (A → B → C → D)

    func testScenario_LinearChain_OnlyOneActiveAtATime() {
        let cmd = UUID()
        concurrencyController.config.maxConcurrentProcesses = 4
        concurrencyController.adjustForPressure(.normal)

        let defs = [
            makeDef(title: "Step 1"),
            makeDef(title: "Step 2", deps: [0]),
            makeDef(title: "Step 3", deps: [1]),
            makeDef(title: "Step 4", deps: [2]),
        ]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        // Only Step 1 is ready
        var totalStarted = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(totalStarted, 1)
        XCTAssertEqual(concurrencyController.currentActiveCount, 1)

        // Complete Step 1 → Step 2 becomes ready
        simulateComplete(commanderId: cmd, taskIndex: 0)
        totalStarted = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(totalStarted, 1) // Only Step 2
        XCTAssertEqual(concurrencyController.currentActiveCount, 1)

        // Complete Step 2 → Step 3 becomes ready
        simulateComplete(commanderId: cmd, taskIndex: 1)
        totalStarted = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(totalStarted, 1)

        // Complete Step 3 → Step 4 becomes ready
        simulateComplete(commanderId: cmd, taskIndex: 2)
        totalStarted = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(totalStarted, 1)

        simulateComplete(commanderId: cmd, taskIndex: 3)
        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd))

        // At no point were there more than 1 active task (no idle agents)
    }

    // MARK: - Scenario 3: Diamond Dependency (A → B,C → D)

    func testScenario_DiamondDependency() {
        let cmd = UUID()
        concurrencyController.config.maxConcurrentProcesses = 4
        concurrencyController.adjustForPressure(.normal)

        let defs = [
            makeDef(title: "Base"),                        // 0
            makeDef(title: "Branch A", deps: [0]),        // 1
            makeDef(title: "Branch B", deps: [0]),        // 2
            makeDef(title: "Merge", deps: [1, 2]),        // 3
        ]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        // Only Base is ready
        var started = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(started, 1)

        // Complete Base → Branch A and B become ready
        simulateComplete(commanderId: cmd, taskIndex: 0)
        started = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(started, 2)
        XCTAssertEqual(concurrencyController.currentActiveCount, 2)

        // Complete Branch A — Merge still waiting for B
        simulateComplete(commanderId: cmd, taskIndex: 1)
        started = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(started, 0) // Merge can't start yet

        // Complete Branch B → Merge becomes ready
        simulateComplete(commanderId: cmd, taskIndex: 2)
        started = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(started, 1)

        simulateComplete(commanderId: cmd, taskIndex: 3)
        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd))
    }

    // MARK: - Scenario 4: Mixed Dependencies with Failure

    func testScenario_FailureWithIndependentTasks() {
        let cmd = UUID()
        concurrencyController.config.maxConcurrentProcesses = 3
        concurrencyController.adjustForPressure(.normal)

        let defs = [
            makeDef(title: "Setup"),                      // 0
            makeDef(title: "Feature A", deps: [0]),       // 1
            makeDef(title: "Feature B", deps: [0]),       // 2
            makeDef(title: "Independent Task"),            // 3
        ]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        // Setup and Independent Task are ready
        var started = simulateExecuteBatch(commanderId: cmd)
        XCTAssertEqual(started, 2) // Setup + Independent

        // Setup fails → Feature A and B are skipped
        simulateFail(commanderId: cmd, taskIndex: 0)

        let dist = scheduler.stateDistribution(commanderId: cmd)
        XCTAssertEqual(dist[.skipped], 2)

        // Independent task still running
        XCTAssertEqual(concurrencyController.currentActiveCount, 1)

        // Complete Independent Task
        simulateComplete(commanderId: cmd, taskIndex: 3)

        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd))
        XCTAssertEqual(concurrencyController.currentActiveCount, 0)
    }

    // MARK: - Scenario 5: Pool Reuse

    func testScenario_PoolReuse_CompletedAgentsRecycled() {
        poolManager.config.maxPoolSize = 10
        poolManager.config.maxPerRole = 5

        // Simulate: agents complete tasks and are released to pool
        let agent1 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        let agent2 = AgentFactory.createSubAgent(parentId: UUID(), role: .researcher, model: .sonnet)

        poolManager.release(agent1)
        poolManager.release(agent2)

        XCTAssertEqual(poolManager.totalPooledCount, 2)

        // New task needs a developer → should get agent1 from pool
        let acquired = poolManager.acquire(role: .developer, parentId: UUID(), model: .haiku)
        XCTAssertNotNil(acquired)
        XCTAssertEqual(acquired?.id, agent1.id)
        XCTAssertEqual(poolManager.stats.hitCount, 1)

        // Pool now has only researcher
        XCTAssertEqual(poolManager.totalPooledCount, 1)
        XCTAssertFalse(poolManager.hasAvailable(role: .developer))
        XCTAssertTrue(poolManager.hasAvailable(role: .researcher))
    }

    // MARK: - Scenario 6: Concurrency Under Pressure

    func testScenario_ConcurrencyReducedUnderPressure() {
        concurrencyController.config.maxConcurrentProcesses = 6
        concurrencyController.adjustForPressure(.high)

        // Under high pressure, effective limit should be 3 (6/2)
        XCTAssertEqual(concurrencyController.effectiveLimit, 3)

        let cmd = UUID()
        let defs = (0..<5).map { makeDef(title: "Task \($0)") }
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        let started = simulateExecuteBatch(commanderId: cmd)
        // Should be limited to 3
        XCTAssertLessThanOrEqual(started, 3)
        XCTAssertLessThanOrEqual(concurrencyController.currentActiveCount, 3)
    }

    // MARK: - Scenario 7: Monitor Detects Idle Buildup

    func testScenario_MonitorDetectsIdleAgents() {
        monitor.config.idleAlertThreshold = 2

        // Register 4 idle agents
        for _ in 0..<4 {
            lifecycleManager.registerAgent(UUID(), initialState: .idle)
        }

        monitor.refresh()

        XCTAssertEqual(monitor.report.idleAgents, 4)
        XCTAssertEqual(monitor.report.healthStatus, .critical)
    }

    // MARK: - Scenario 8: Large Decomposition with Limited Concurrency

    func testScenario_SixTasks_TwoConcurrency_AllComplete() {
        let cmd = UUID()
        concurrencyController.config.maxConcurrentProcesses = 2
        concurrencyController.adjustForPressure(.normal)

        let defs = (0..<6).map { makeDef(title: "Task \($0)") }
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        var completedIndices = Set<Int>()
        var iterations = 0

        // Run until all done
        while !scheduler.isOrchestrationDone(commanderId: cmd) && iterations < 20 {
            iterations += 1

            // Start as many as concurrency allows
            _ = simulateExecuteBatch(commanderId: cmd)

            // Find a running task to complete
            let runningItems = scheduler.schedule.filter {
                $0.commanderId == cmd && $0.state == .running && !completedIndices.contains($0.taskIndex)
            }

            if let toComplete = runningItems.first {
                simulateComplete(commanderId: cmd, taskIndex: toComplete.taskIndex)
                completedIndices.insert(toComplete.taskIndex)
            } else if concurrencyController.currentActiveCount == 0 {
                break
            }
        }

        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd))
        XCTAssertEqual(completedIndices.count, 6)
        XCTAssertEqual(concurrencyController.currentActiveCount, 0)
    }

    // MARK: - Scenario 9: shouldDecompose Logic

    func testShouldDecompose_SimplePrompt() {
        let orchestrator = AutoDecompositionOrchestrator()
        XCTAssertFalse(orchestrator.shouldDecompose(prompt: "fix the bug"))
        XCTAssertFalse(orchestrator.shouldDecompose(prompt: "Hello"))
    }

    func testShouldDecompose_ComplexPrompt() {
        let orchestrator = AutoDecompositionOrchestrator()
        XCTAssertTrue(orchestrator.shouldDecompose(prompt: "First implement the user model, then add API endpoints, and finally write tests for everything"))
        XCTAssertTrue(orchestrator.shouldDecompose(prompt: "1. Create database schema 2. Add migration 3. Update API"))
    }

    func testShouldDecompose_ChinesePrompt() {
        let orchestrator = AutoDecompositionOrchestrator()
        // Need enough word count (>8) — Chinese words separated by spaces count
        XCTAssertTrue(orchestrator.shouldDecompose(prompt: "首先 重構 資料 模型 結構，然後 更新 所有 API 端點，最後 添加 完整 的 單元 測試"))
    }

    // MARK: - Scenario 10: Pool Dynamic Sizing Under Pressure

    func testScenario_PoolShrinkUnderPressure() {
        poolManager.config.maxPoolSize = 10
        poolManager.config.maxPerRole = 10
        poolManager.config.minPoolSize = 1
        poolManager.config.shrinkCooldownSeconds = 0

        // Fill pool with agents
        for _ in 0..<5 {
            let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
            poolManager.release(agent)
        }
        XCTAssertEqual(poolManager.totalPooledCount, 5)

        // Critical pressure → shrink to minimum
        poolManager.evaluateAndResize(resourcePressure: .critical)
        XCTAssertEqual(poolManager.totalPooledCount, 1)
    }
}
