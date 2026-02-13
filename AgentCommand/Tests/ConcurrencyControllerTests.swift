import XCTest
@testable import AgentCommand

@MainActor
final class ConcurrencyControllerTests: XCTestCase {

    var controller: ConcurrencyController!
    var startedTasks: [(commanderId: UUID, taskIndex: Int, model: ClaudeModel)]!

    override func setUp() {
        super.setUp()
        controller = ConcurrencyController()
        startedTasks = []

        controller.onStartSubAgent = { [weak self] commanderId, taskIndex, model in
            self?.startedTasks.append((commanderId, taskIndex, model))
        }
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        startedTasks = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(controller.currentActiveCount, 0)
        XCTAssertEqual(controller.currentQueuedCount, 0)
        XCTAssertEqual(controller.effectiveLimit, 6)
        XCTAssertFalse(controller.isAtCapacity)
    }

    // MARK: - Available Slots

    func testAvailableSlots_AllFree() {
        XCTAssertEqual(controller.availableSlots(), 6)
    }

    func testAvailableSlots_SomeUsed() {
        let cmd = UUID()
        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet)
        XCTAssertEqual(controller.availableSlots(), 4)
    }

    // MARK: - Request Start

    func testRequestStart_ImmediateStart() {
        let cmd = UUID()
        let started = controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        XCTAssertTrue(started)
        XCTAssertEqual(controller.currentActiveCount, 1)
        XCTAssertEqual(startedTasks.count, 1)
        XCTAssertEqual(startedTasks[0].taskIndex, 0)
    }

    func testRequestStart_QueuedWhenFull() {
        controller.config.maxConcurrentProcesses = 2
        controller.adjustForPressure(.normal) // apply config

        let cmd = UUID()
        XCTAssertTrue(controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet))
        XCTAssertTrue(controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet))

        // Third should be queued
        let queued = controller.requestStart(commanderId: cmd, taskIndex: 2, model: .sonnet)
        XCTAssertFalse(queued)
        XCTAssertEqual(controller.currentActiveCount, 2)
        XCTAssertEqual(controller.currentQueuedCount, 1)
        XCTAssertEqual(startedTasks.count, 2)
    }

    func testRequestStart_DrainQueueOnCompletion() {
        controller.config.maxConcurrentProcesses = 1
        controller.adjustForPressure(.normal)

        let cmd = UUID()
        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet) // queued

        XCTAssertEqual(startedTasks.count, 1)
        XCTAssertEqual(controller.currentQueuedCount, 1)

        // Complete first task — should drain queue
        controller.taskCompleted(commanderId: cmd, taskIndex: 0)

        XCTAssertEqual(startedTasks.count, 2)
        XCTAssertEqual(startedTasks[1].taskIndex, 1)
        XCTAssertEqual(controller.currentQueuedCount, 0)
        XCTAssertEqual(controller.currentActiveCount, 1)
    }

    // MARK: - Priority Ordering

    func testRequestStart_PriorityOrdering() {
        controller.config.maxConcurrentProcesses = 1
        controller.adjustForPressure(.normal)

        let cmd = UUID()
        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet) // takes the slot

        // Queue with different priorities
        controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet, priority: .low)
        controller.requestStart(commanderId: cmd, taskIndex: 2, model: .sonnet, priority: .critical)
        controller.requestStart(commanderId: cmd, taskIndex: 3, model: .sonnet, priority: .high)

        // Complete first task — critical should go next
        controller.taskCompleted(commanderId: cmd, taskIndex: 0)
        XCTAssertEqual(startedTasks.count, 2)
        XCTAssertEqual(startedTasks[1].taskIndex, 2) // critical
    }

    // MARK: - Adaptive Throttling

    func testAdjustForPressure_Normal() {
        controller.config.maxConcurrentProcesses = 8
        controller.adjustForPressure(.normal)
        XCTAssertEqual(controller.effectiveLimit, 8)
    }

    func testAdjustForPressure_Elevated() {
        controller.config.maxConcurrentProcesses = 8
        controller.adjustForPressure(.elevated)
        XCTAssertEqual(controller.effectiveLimit, 6) // 8 * 3/4
    }

    func testAdjustForPressure_High() {
        controller.config.maxConcurrentProcesses = 8
        controller.adjustForPressure(.high)
        XCTAssertEqual(controller.effectiveLimit, 4) // 8 / 2
    }

    func testAdjustForPressure_Critical() {
        controller.config.maxConcurrentProcesses = 8
        controller.config.minConcurrentProcesses = 2
        controller.adjustForPressure(.critical)
        XCTAssertEqual(controller.effectiveLimit, 2) // min
    }

    func testAdjustForPressure_DisabledAdaptive() {
        controller.config.maxConcurrentProcesses = 8
        controller.config.enableAdaptiveThrottling = false
        controller.adjustForPressure(.critical)
        XCTAssertEqual(controller.effectiveLimit, 8) // no change
    }

    // MARK: - Optimal Wave Size

    func testOptimalWaveSize_AllSlotsFree() {
        controller.config.maxConcurrentProcesses = 6
        controller.adjustForPressure(.normal)
        let size = controller.optimalWaveSize(readyCount: 4, totalRemaining: 4)
        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThanOrEqual(size, 4)
    }

    func testOptimalWaveSize_NoSlots() {
        controller.config.maxConcurrentProcesses = 2
        controller.adjustForPressure(.normal)

        let cmd = UUID()
        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet)

        let size = controller.optimalWaveSize(readyCount: 3, totalRemaining: 5)
        XCTAssertEqual(size, 0)
    }

    func testOptimalWaveSize_WithLookAhead() {
        controller.config.maxConcurrentProcesses = 6
        controller.config.lookAheadDepth = 3
        controller.adjustForPressure(.normal)

        // With more remaining than ready, should leave headroom
        let size = controller.optimalWaveSize(readyCount: 2, totalRemaining: 8)
        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThanOrEqual(size, 6)
    }

    // MARK: - Running Count

    func testRunningCount() {
        let cmd1 = UUID()
        let cmd2 = UUID()

        controller.requestStart(commanderId: cmd1, taskIndex: 0, model: .sonnet)
        controller.requestStart(commanderId: cmd1, taskIndex: 1, model: .sonnet)
        controller.requestStart(commanderId: cmd2, taskIndex: 0, model: .sonnet)

        XCTAssertEqual(controller.runningCount(for: cmd1), 2)
        XCTAssertEqual(controller.runningCount(for: cmd2), 1)
        XCTAssertEqual(controller.totalRunningCount, 3)
    }

    // MARK: - IsAtCapacity

    func testIsAtCapacity() {
        controller.config.maxConcurrentProcesses = 2
        controller.adjustForPressure(.normal)

        let cmd = UUID()
        XCTAssertFalse(controller.isAtCapacity)

        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet)
        XCTAssertTrue(controller.isAtCapacity)
    }

    // MARK: - Task Cancelled

    func testTaskCancelled_FreesSlot() {
        let cmd = UUID()
        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        XCTAssertEqual(controller.currentActiveCount, 1)

        controller.taskCancelled(commanderId: cmd, taskIndex: 0)
        XCTAssertEqual(controller.currentActiveCount, 0)
    }

    // MARK: - Reset

    func testReset() {
        let cmd = UUID()
        controller.requestStart(commanderId: cmd, taskIndex: 0, model: .sonnet)
        controller.requestStart(commanderId: cmd, taskIndex: 1, model: .sonnet)

        controller.reset()
        XCTAssertEqual(controller.currentActiveCount, 0)
        XCTAssertEqual(controller.currentQueuedCount, 0)
        XCTAssertEqual(controller.totalRunningCount, 0)
    }
}
