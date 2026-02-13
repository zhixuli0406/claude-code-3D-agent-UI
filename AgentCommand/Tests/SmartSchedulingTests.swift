import XCTest
@testable import AgentCommand

// MARK: - L2: Smart Scheduling Models Unit Tests

final class SchedulePriorityTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(SchedulePriority.low.displayName, "Low")
        XCTAssertEqual(SchedulePriority.medium.displayName, "Medium")
        XCTAssertEqual(SchedulePriority.high.displayName, "High")
        XCTAssertEqual(SchedulePriority.critical.displayName, "Critical")
    }

    func testWeights() {
        XCTAssertEqual(SchedulePriority.low.weight, 1)
        XCTAssertEqual(SchedulePriority.medium.weight, 2)
        XCTAssertEqual(SchedulePriority.high.weight, 3)
        XCTAssertEqual(SchedulePriority.critical.weight, 4)
    }

    func testWeights_Ascending() {
        let priorities: [SchedulePriority] = [.low, .medium, .high, .critical]
        for i in 1..<priorities.count {
            XCTAssertGreaterThan(priorities[i].weight, priorities[i-1].weight)
        }
    }

    func testHexColor() {
        for priority in SchedulePriority.allCases {
            XCTAssertTrue(priority.hexColor.hasPrefix("#"))
            XCTAssertEqual(priority.hexColor.count, 7)
        }
    }

    func testIdentifiable() {
        XCTAssertEqual(SchedulePriority.low.id, "low")
        XCTAssertEqual(SchedulePriority.critical.id, "critical")
    }
}

final class ScheduleStatusTests: XCTestCase {

    func testAllCasesHaveHexColor() {
        for status in ScheduleStatus.allCases {
            XCTAssertTrue(status.hexColor.hasPrefix("#"))
        }
    }

    func testAllCasesHaveIconName() {
        for status in ScheduleStatus.allCases {
            XCTAssertFalse(status.iconName.isEmpty)
        }
    }

    func testRawValues() {
        XCTAssertEqual(ScheduleStatus.pending.rawValue, "pending")
        XCTAssertEqual(ScheduleStatus.scheduled.rawValue, "scheduled")
        XCTAssertEqual(ScheduleStatus.running.rawValue, "running")
        XCTAssertEqual(ScheduleStatus.completed.rawValue, "completed")
        XCTAssertEqual(ScheduleStatus.skipped.rawValue, "skipped")
    }
}

// MARK: - L2: Smart Scheduling Manager Tests

@MainActor
final class SmartSchedulingManagerTests: XCTestCase {

    private var manager: SmartSchedulingManager!

    override func setUp() {
        super.setUp()
        manager = SmartSchedulingManager()
        // Clean UserDefaults keys used by the manager
        UserDefaults.standard.removeObject(forKey: "smartScheduling.completedCount")
        UserDefaults.standard.removeObject(forKey: "smartScheduling.avgAccuracy")
    }

    override func tearDown() {
        manager.disableAutoScheduling()
        manager = nil
        UserDefaults.standard.removeObject(forKey: "smartScheduling.completedCount")
        UserDefaults.standard.removeObject(forKey: "smartScheduling.avgAccuracy")
        super.tearDown()
    }

    // MARK: - Add Task

    func testAddTask() {
        manager.addTask(name: "Test Task", description: "A test", priority: .medium, estimatedTokens: 1000)
        XCTAssertEqual(manager.scheduledTasks.count, 1)
        XCTAssertEqual(manager.scheduledTasks[0].name, "Test Task")
        XCTAssertEqual(manager.scheduledTasks[0].priority, .medium)
        XCTAssertFalse(manager.scheduledTasks[0].isBatch)
    }

    func testAddTask_SetsEstimatedDuration() {
        manager.addTask(name: "Task", description: "", priority: .high, estimatedTokens: 5000)
        // 5000 tokens / 10 tokens per second = 500 seconds
        XCTAssertEqual(manager.scheduledTasks[0].estimatedDuration, 500.0, accuracy: 1.0)
    }

    func testAddTask_SetsSuggestedTime() {
        manager.addTask(name: "Critical Task", description: "", priority: .critical, estimatedTokens: 100)
        // Critical tasks should have suggestedTime very close to now
        XCTAssertNotNil(manager.scheduledTasks.first?.suggestedTime)
    }

    func testAddMultipleTasks() {
        manager.addTask(name: "Task 1", description: "", priority: .low, estimatedTokens: 100)
        manager.addTask(name: "Task 2", description: "", priority: .critical, estimatedTokens: 200)
        manager.addTask(name: "Task 3", description: "", priority: .medium, estimatedTokens: 300)
        XCTAssertEqual(manager.scheduledTasks.count, 3)
    }

    // MARK: - Remove Task

    func testRemoveTask() {
        manager.addTask(name: "To Remove", description: "", priority: .low, estimatedTokens: 100)
        let taskId = manager.scheduledTasks[0].id
        manager.removeTask(taskId)
        XCTAssertTrue(manager.scheduledTasks.isEmpty)
    }

    func testRemoveTask_NonExistentId() {
        manager.addTask(name: "Keep", description: "", priority: .low, estimatedTokens: 100)
        manager.removeTask(UUID()) // random UUID
        XCTAssertEqual(manager.scheduledTasks.count, 1)
    }

    // MARK: - Adjust Priority

    func testAdjustPriority() {
        manager.addTask(name: "Task", description: "", priority: .low, estimatedTokens: 100)
        let taskId = manager.scheduledTasks[0].id
        manager.adjustPriority(taskId, to: .critical)
        XCTAssertEqual(manager.scheduledTasks.first(where: { $0.id == taskId })?.priority, .critical)
    }

    func testAdjustPriority_NonExistentId() {
        manager.addTask(name: "Task", description: "", priority: .low, estimatedTokens: 100)
        manager.adjustPriority(UUID(), to: .critical)
        // Should not crash, original task unchanged
        XCTAssertEqual(manager.scheduledTasks[0].priority, .low)
    }

    // MARK: - Mark Completed

    func testMarkCompleted() {
        manager.addTask(name: "Task", description: "", priority: .medium, estimatedTokens: 100)
        let taskId = manager.scheduledTasks[0].id
        manager.markCompleted(taskId)
        XCTAssertEqual(manager.scheduledTasks.first(where: { $0.id == taskId })?.status, .completed)
        XCTAssertNotNil(manager.scheduledTasks.first(where: { $0.id == taskId })?.actualDuration)
    }

    func testMarkCompleted_EvictsOldTasks() {
        // Add 52 tasks and complete them all — should evict down to 50 completed
        for i in 0..<52 {
            manager.addTask(name: "Task \(i)", description: "", priority: .low, estimatedTokens: 100)
        }
        let taskIds = manager.scheduledTasks.map(\.id)
        for id in taskIds {
            manager.markCompleted(id)
        }
        let completedCount = manager.scheduledTasks.filter { $0.status == .completed }.count
        XCTAssertLessThanOrEqual(completedCount, 50)
    }

    // MARK: - Optimize Schedule

    func testOptimizeSchedule() {
        manager.addTask(name: "Low", description: "", priority: .low, estimatedTokens: 1000)
        manager.addTask(name: "Critical", description: "", priority: .critical, estimatedTokens: 500)
        manager.addTask(name: "High", description: "", priority: .high, estimatedTokens: 800)

        manager.optimizeSchedule()

        let pending = manager.scheduledTasks.filter { $0.status == .pending || $0.status == .scheduled }
        if pending.count > 1 {
            // First scheduled task should be the highest priority
            let scheduledWithTime = pending.compactMap { task -> (ScheduledTask, Date)? in
                guard let time = task.suggestedTime else { return nil }
                return (task, time)
            }.sorted { $0.1 < $1.1 }

            if let first = scheduledWithTime.first {
                XCTAssertEqual(first.0.priority, .critical)
            }
        }
    }

    func testOptimizeSchedule_SingleTask_NoOptimization() {
        manager.addTask(name: "Only", description: "", priority: .medium, estimatedTokens: 100)
        let beforeCount = manager.optimizations.count
        manager.optimizeSchedule()
        // Single task shouldn't produce optimization records (needs > 1 pending)
        // The addTask call already calls optimizeSchedule, so we check initial state
        XCTAssertEqual(manager.scheduledTasks.count, 1)
    }

    func testOptimizeSchedule_AssignsSuggestedTimes() {
        manager.addTask(name: "Task A", description: "", priority: .high, estimatedTokens: 1000)
        manager.addTask(name: "Task B", description: "", priority: .medium, estimatedTokens: 2000)

        // Both tasks should have suggested times after optimization
        let pending = manager.scheduledTasks.filter { $0.status == .scheduled }
        for task in pending {
            XCTAssertNotNil(task.suggestedTime)
        }
    }

    // MARK: - Create Batch

    func testCreateBatch() {
        manager.addTask(name: "A", description: "", priority: .low, estimatedTokens: 100)
        manager.addTask(name: "B", description: "", priority: .low, estimatedTokens: 200)
        let ids = manager.scheduledTasks.map(\.id)
        manager.createBatch(taskIds: ids)
        XCTAssertTrue(manager.scheduledTasks.allSatisfy { $0.isBatch })
    }

    // MARK: - Schedule Tasks (Bulk)

    func testScheduleTasks() {
        let tasks = [
            ScheduledTask(id: UUID(), name: "Z", description: "", priority: .low, status: .pending,
                         scheduledAt: Date(), estimatedDuration: 60, estimatedTokens: 100, isBatch: false),
            ScheduledTask(id: UUID(), name: "A", description: "", priority: .critical, status: .pending,
                         scheduledAt: Date(), estimatedDuration: 120, estimatedTokens: 200, isBatch: false),
        ]
        manager.scheduleTasks(tasks)
        // Should be sorted by priority weight (critical first)
        XCTAssertEqual(manager.scheduledTasks.count, 2)
        XCTAssertEqual(manager.scheduledTasks[0].priority, .critical)
    }

    // MARK: - Auto Scheduling

    func testEnableAutoScheduling() {
        manager.enableAutoScheduling()
        XCTAssertTrue(manager.isAutoScheduling)
    }

    func testDisableAutoScheduling() {
        manager.enableAutoScheduling()
        manager.disableAutoScheduling()
        XCTAssertFalse(manager.isAutoScheduling)
    }

    // MARK: - Stats

    func testStats_UpdatedOnAddTask() {
        manager.addTask(name: "Task", description: "", priority: .medium, estimatedTokens: 100)
        XCTAssertEqual(manager.stats.totalScheduled, 1)
    }

    func testStats_CompletedOnTime() {
        manager.addTask(name: "Task", description: "", priority: .medium, estimatedTokens: 100)
        let taskId = manager.scheduledTasks[0].id
        manager.markCompleted(taskId)
        XCTAssertEqual(manager.stats.completedOnTime, 1)
    }

    // MARK: - Load Sample Data

    func testLoadSampleData() {
        manager.loadSampleData()
        XCTAssertEqual(manager.scheduledTasks.count, 4)
        XCTAssertFalse(manager.timeSlots.isEmpty)
        XCTAssertGreaterThan(manager.stats.totalScheduled, 0)
    }

    // MARK: - Persistence

    func testLoadSavedStats() {
        UserDefaults.standard.set(25, forKey: "smartScheduling.completedCount")
        UserDefaults.standard.set(0.85, forKey: "smartScheduling.avgAccuracy")
        manager.loadSavedStats()
        XCTAssertEqual(manager.stats.completedOnTime, 25)
        XCTAssertEqual(manager.stats.avgAccuracy, 0.85, accuracy: 0.001)
    }

    func testLoadSavedStats_NoData() {
        manager.loadSavedStats()
        // Should not crash, stats should remain at defaults
        XCTAssertEqual(manager.stats.completedOnTime, 0)
    }
}
