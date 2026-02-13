import XCTest
@testable import AgentCommand

@MainActor
final class TaskPrioritySchedulerTests: XCTestCase {

    var scheduler: TaskPriorityScheduler!

    override func setUp() {
        super.setUp()
        scheduler = TaskPriorityScheduler()
    }

    override func tearDown() {
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeDef(title: String, prompt: String = "do it", deps: [Int] = [], parallel: Bool = true, complexity: String = "medium") -> SubtaskDefinition {
        return SubtaskDefinition(title: title, prompt: prompt, dependencies: deps, canParallel: parallel, estimatedComplexity: complexity)
    }

    private func makeSubTasks(_ defs: [SubtaskDefinition]) -> [OrchestratedSubTask] {
        defs.enumerated().map { OrchestratedSubTask(index: $0.offset, definition: $0.element) }
    }

    // MARK: - Schedule SubTasks

    func testScheduleSubTasks_AllIndependentAreReady() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B"),
            makeDef(title: "Task C"),
        ]
        let subTasks = makeSubTasks(defs)

        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        XCTAssertEqual(scheduler.schedule.count, 3)
        // All should be ready since no dependencies
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 3)
    }

    func testScheduleSubTasks_WithDependencies() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B", deps: [0]),
            makeDef(title: "Task C", deps: [0, 1]),
        ]
        let subTasks = makeSubTasks(defs)

        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        // Only Task A should be ready
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 1)

        let batch = scheduler.nextBatch(commanderId: cmd, maxSize: 10)
        XCTAssertEqual(batch.count, 1)
        XCTAssertEqual(batch[0].title, "Task A")
    }

    // MARK: - Completion Unlocks Dependents

    func testMarkCompleted_UnlocksDependents() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B", deps: [0]),
            makeDef(title: "Task C", deps: [0]),
        ]
        let subTasks = makeSubTasks(defs)
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        // Only A is ready
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 1)

        // Mark A as started then completed
        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markCompleted(commanderId: cmd, taskIndex: 0)

        // Now B and C should be ready
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 2)
    }

    func testMarkCompleted_ChainsMultipleLevels() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B", deps: [0]),
            makeDef(title: "Task C", deps: [1]),
        ]
        let subTasks = makeSubTasks(defs)
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        // A ready
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 1)

        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markCompleted(commanderId: cmd, taskIndex: 0)

        // B ready, C still pending
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 1)

        scheduler.markStarted(commanderId: cmd, taskIndex: 1)
        scheduler.markCompleted(commanderId: cmd, taskIndex: 1)

        // C now ready
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 1)
        let batch = scheduler.nextBatch(commanderId: cmd, maxSize: 10)
        XCTAssertEqual(batch[0].title, "Task C")
    }

    // MARK: - Failure Cascading

    func testMarkFailed_SkipsDependents() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B", deps: [0]),
            makeDef(title: "Task C", deps: [1]),
        ]
        let subTasks = makeSubTasks(defs)
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markFailed(commanderId: cmd, taskIndex: 0)

        // B and C should be skipped
        let distribution = scheduler.stateDistribution(commanderId: cmd)
        XCTAssertEqual(distribution[.failed], 1)
        XCTAssertEqual(distribution[.skipped], 2)
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 0)
    }

    func testMarkFailed_IndependentTasksStillReady() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Task A"),
            makeDef(title: "Task B"),
            makeDef(title: "Task C", deps: [0]),
        ]
        let subTasks = makeSubTasks(defs)
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markFailed(commanderId: cmd, taskIndex: 0)

        // B is still ready (independent), C is skipped
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd), 1)
        let batch = scheduler.nextBatch(commanderId: cmd, maxSize: 10)
        XCTAssertEqual(batch[0].title, "Task B")
    }

    // MARK: - Priority Ordering

    func testNextBatch_PriorityOrdering() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "Docs update", prompt: "update documentation"),
            makeDef(title: "Fix security bug", prompt: "fix security vulnerability"),
            makeDef(title: "Add feature", prompt: "implement new feature"),
        ]
        let subTasks = makeSubTasks(defs)
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        let batch = scheduler.nextBatch(commanderId: cmd, maxSize: 3)
        // Security (critical) should be first, docs (low) should be last
        XCTAssertEqual(batch[0].title, "Fix security bug")
        XCTAssertEqual(batch.last?.title, "Docs update")
    }

    // MARK: - Adjust Priority

    func testAdjustPriority() {
        let cmd = UUID()
        let defs = [makeDef(title: "Task A")]
        let subTasks = makeSubTasks(defs)
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: subTasks)

        scheduler.adjustPriority(commanderId: cmd, taskIndex: 0, newPriority: .critical)

        let batch = scheduler.nextBatch(commanderId: cmd, maxSize: 1)
        XCTAssertEqual(batch[0].priority, .critical)
    }

    // MARK: - isOrchestrationDone

    func testIsOrchestrationDone_AllCompleted() {
        let cmd = UUID()
        let defs = [makeDef(title: "A"), makeDef(title: "B")]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        XCTAssertFalse(scheduler.isOrchestrationDone(commanderId: cmd))

        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markCompleted(commanderId: cmd, taskIndex: 0)
        XCTAssertFalse(scheduler.isOrchestrationDone(commanderId: cmd))

        scheduler.markStarted(commanderId: cmd, taskIndex: 1)
        scheduler.markCompleted(commanderId: cmd, taskIndex: 1)
        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd))
    }

    func testIsOrchestrationDone_MixOfCompletedAndFailed() {
        let cmd = UUID()
        let defs = [makeDef(title: "A"), makeDef(title: "B", deps: [0])]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markFailed(commanderId: cmd, taskIndex: 0)
        // B gets skipped

        XCTAssertTrue(scheduler.isOrchestrationDone(commanderId: cmd))
    }

    // MARK: - Remove Orchestration

    func testRemoveOrchestration() {
        let cmd = UUID()
        let defs = [makeDef(title: "A"), makeDef(title: "B")]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))
        XCTAssertEqual(scheduler.schedule.count, 2)

        scheduler.removeOrchestration(commanderId: cmd)
        XCTAssertEqual(scheduler.schedule.count, 0)
    }

    // MARK: - Stats

    func testStats() {
        let cmd = UUID()
        let defs = [makeDef(title: "A"), makeDef(title: "B"), makeDef(title: "C", deps: [0])]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        XCTAssertEqual(scheduler.schedulerStats.totalScheduled, 3)

        scheduler.markStarted(commanderId: cmd, taskIndex: 0)
        scheduler.markCompleted(commanderId: cmd, taskIndex: 0)

        scheduler.markStarted(commanderId: cmd, taskIndex: 1)
        scheduler.markFailed(commanderId: cmd, taskIndex: 1)

        XCTAssertEqual(scheduler.schedulerStats.totalCompleted, 1)
        XCTAssertEqual(scheduler.schedulerStats.totalFailed, 1)
    }

    // MARK: - Complexity Inference

    func testTaskComplexity() {
        XCTAssertEqual(TaskPriorityScheduler.TaskComplexity(from: "low"), .low)
        XCTAssertEqual(TaskPriorityScheduler.TaskComplexity(from: "high"), .high)
        XCTAssertEqual(TaskPriorityScheduler.TaskComplexity(from: "medium"), .medium)
        XCTAssertEqual(TaskPriorityScheduler.TaskComplexity(from: "unknown"), .medium)
    }

    // MARK: - Multiple Orchestrations

    func testMultipleOrchestrations() {
        let cmd1 = UUID()
        let cmd2 = UUID()

        let defs1 = [makeDef(title: "A1"), makeDef(title: "B1")]
        let defs2 = [makeDef(title: "A2"), makeDef(title: "B2"), makeDef(title: "C2")]

        scheduler.scheduleSubTasks(commanderId: cmd1, subTasks: makeSubTasks(defs1))
        scheduler.scheduleSubTasks(commanderId: cmd2, subTasks: makeSubTasks(defs2))

        XCTAssertEqual(scheduler.readyCount(commanderId: cmd1), 2)
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd2), 3)
        XCTAssertEqual(scheduler.schedule.count, 5)

        scheduler.removeOrchestration(commanderId: cmd1)
        XCTAssertEqual(scheduler.schedule.count, 3)
        XCTAssertEqual(scheduler.readyCount(commanderId: cmd2), 3)
    }

    // MARK: - State Distribution

    func testStateDistribution() {
        let cmd = UUID()
        let defs = [
            makeDef(title: "A"),
            makeDef(title: "B"),
            makeDef(title: "C", deps: [0]),
        ]
        scheduler.scheduleSubTasks(commanderId: cmd, subTasks: makeSubTasks(defs))

        let dist = scheduler.stateDistribution(commanderId: cmd)
        XCTAssertEqual(dist[.ready], 2) // A and B
        XCTAssertEqual(dist[.pending], 1) // C
    }
}
