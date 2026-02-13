import XCTest
@testable import AgentCommand

// MARK: - M3: API Usage Analytics Manager Unit Tests

@MainActor
final class APIUsageAnalyticsManagerTests: XCTestCase {

    private var manager: APIUsageAnalyticsManager!

    override func setUp() {
        super.setUp()
        manager = APIUsageAnalyticsManager()
    }

    override func tearDown() {
        manager.stopMonitoring()
        manager = nil
        super.tearDown()
    }

    // MARK: - Start / Stop Monitoring

    func testStartMonitoring() {
        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)
    }

    func testStopMonitoring() {
        manager.startMonitoring()
        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
    }

    func testStopMonitoring_WhenNotMonitoring() {
        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
    }

    // MARK: - Record API Call (Basic)

    func testRecordAPICall_Basic() {
        manager.recordAPICall(
            model: "claude-sonnet-4",
            inputTokens: 500,
            outputTokens: 200,
            latencyMs: 1500.0,
            costUSD: 0.0035,
            taskType: "code-generation"
        )
        XCTAssertEqual(manager.callRecords.count, 1)
        XCTAssertEqual(manager.callRecords[0].model, "claude-sonnet-4")
        XCTAssertEqual(manager.callRecords[0].inputTokens, 500)
        XCTAssertEqual(manager.callRecords[0].outputTokens, 200)
        XCTAssertEqual(manager.callRecords[0].latencyMs, 1500.0)
        XCTAssertEqual(manager.callRecords[0].costUSD, 0.0035)
        XCTAssertEqual(manager.callRecords[0].taskType, "code-generation")
        XCTAssertFalse(manager.callRecords[0].isError)
        XCTAssertNil(manager.callRecords[0].errorType)
    }

    func testRecordAPICall_InsertsAtFront() {
        manager.recordAPICall(
            model: "claude-sonnet-4",
            inputTokens: 100,
            outputTokens: 50,
            latencyMs: 800.0,
            costUSD: 0.001,
            taskType: "general"
        )
        manager.recordAPICall(
            model: "claude-opus-4",
            inputTokens: 200,
            outputTokens: 100,
            latencyMs: 1200.0,
            costUSD: 0.005,
            taskType: "debugging"
        )
        XCTAssertEqual(manager.callRecords.count, 2)
        XCTAssertEqual(manager.callRecords[0].model, "claude-opus-4")
        XCTAssertEqual(manager.callRecords[1].model, "claude-sonnet-4")
    }

    func testRecordAPICall_EvictionCapAt500() {
        for i in 0..<505 {
            manager.recordAPICall(
                model: "claude-sonnet-4",
                inputTokens: 100,
                outputTokens: 50,
                latencyMs: 500.0,
                costUSD: 0.001,
                taskType: "task-\(i)"
            )
        }
        XCTAssertLessThanOrEqual(manager.callRecords.count, 500)
    }

    func testRecordAPICall_UpdatesSummary() {
        XCTAssertEqual(manager.summary.totalCalls, 0)
        manager.recordAPICall(
            model: "claude-sonnet-4",
            inputTokens: 300,
            outputTokens: 150,
            latencyMs: 1000.0,
            costUSD: 0.002,
            taskType: "analysis"
        )
        XCTAssertEqual(manager.summary.totalCalls, 1)
        XCTAssertEqual(manager.summary.totalTokens, 450)
        XCTAssertEqual(manager.summary.totalCost, 0.002, accuracy: 0.0001)
    }

    // MARK: - Record API Call (Error)

    func testRecordAPICall_WithError() {
        manager.recordAPICall(
            model: "claude-opus-4",
            inputTokens: 100,
            outputTokens: 0,
            latencyMs: 30000.0,
            costUSD: 0.0,
            taskType: "code-generation",
            isError: true,
            errorType: "timeout"
        )
        XCTAssertEqual(manager.callRecords.count, 1)
        XCTAssertTrue(manager.callRecords[0].isError)
        XCTAssertEqual(manager.callRecords[0].errorType, "timeout")
    }

    // MARK: - Record API Call (Budget Integration)

    func testRecordAPICall_UpdatesBudgetSpend() {
        manager.setBudget(monthly: 100.0)
        XCTAssertEqual(manager.budgetAlert?.currentSpend, 0.0)

        manager.recordAPICall(
            model: "claude-opus-4",
            inputTokens: 500,
            outputTokens: 300,
            latencyMs: 2000.0,
            costUSD: 0.05,
            taskType: "code-generation"
        )
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 0.05, accuracy: 0.001)

        manager.recordAPICall(
            model: "claude-sonnet-4",
            inputTokens: 200,
            outputTokens: 100,
            latencyMs: 800.0,
            costUSD: 0.02,
            taskType: "analysis"
        )
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 0.07, accuracy: 0.001)
    }

    // MARK: - Generate Cost Breakdown

    func testGenerateCostBreakdown_GroupsByModel() {
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 2000.0, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 400, outputTokens: 200, latencyMs: 1800.0, costUSD: 0.08, taskType: "coding")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 300, outputTokens: 150, latencyMs: 1000.0, costUSD: 0.02, taskType: "review")

        manager.generateCostBreakdown(period: "Last 7 Days")

        XCTAssertEqual(manager.costBreakdowns.count, 1)
        let breakdown = manager.costBreakdowns[0]
        XCTAssertEqual(breakdown.entries.count, 2)
        XCTAssertEqual(breakdown.period, "Last 7 Days")
    }

    func testGenerateCostBreakdown_SortedByCostDesc() {
        manager.recordAPICall(model: "claude-haiku-3.5", inputTokens: 100, outputTokens: 50, latencyMs: 300.0, costUSD: 0.001, taskType: "general")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 3000.0, costUSD: 0.20, taskType: "coding")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 300, outputTokens: 150, latencyMs: 1000.0, costUSD: 0.05, taskType: "review")

        manager.generateCostBreakdown(period: "Test")

        let breakdown = manager.costBreakdowns[0]
        XCTAssertEqual(breakdown.entries[0].category, "claude-opus-4")
        XCTAssertEqual(breakdown.entries[1].category, "claude-sonnet-4")
        XCTAssertEqual(breakdown.entries[2].category, "claude-haiku-3.5")
    }

    func testGenerateCostBreakdown_EmptyRecordsGuard() {
        manager.generateCostBreakdown(period: "Empty Test")
        XCTAssertTrue(manager.costBreakdowns.isEmpty)
    }

    func testGenerateCostBreakdown_EvictionCapAt10() {
        // Add a record so breakdowns can be generated
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50, latencyMs: 500.0, costUSD: 0.01, taskType: "general")

        for i in 0..<12 {
            manager.generateCostBreakdown(period: "Period \(i)")
        }
        XCTAssertLessThanOrEqual(manager.costBreakdowns.count, 10)
    }

    // MARK: - Set Budget

    func testSetBudget_CreatesAlert() {
        manager.setBudget(monthly: 100.0, alertThreshold: 0.75)
        XCTAssertNotNil(manager.budgetAlert)
        XCTAssertEqual(manager.budgetAlert?.monthlyBudget, 100.0)
        XCTAssertEqual(manager.budgetAlert?.alertThreshold, 0.75)
        XCTAssertEqual(manager.budgetAlert?.currentSpend, 0.0)
        XCTAssertTrue(manager.budgetAlert?.isActive ?? false)
    }

    func testSetBudget_DefaultThreshold() {
        manager.setBudget(monthly: 50.0)
        XCTAssertEqual(manager.budgetAlert?.alertThreshold, 0.8)
    }

    func testSetBudget_CarriesForwardSpend() {
        manager.setBudget(monthly: 100.0)
        manager.updateBudgetSpend(30.0)
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 30.0, accuracy: 0.001)

        // Replace budget — spend should carry forward
        manager.setBudget(monthly: 200.0, alertThreshold: 0.9)
        XCTAssertEqual(manager.budgetAlert?.monthlyBudget, 200.0)
        XCTAssertEqual(manager.budgetAlert?.alertThreshold, 0.9)
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 30.0, accuracy: 0.001)
    }

    // MARK: - Update Budget Spend

    func testUpdateBudgetSpend_Accumulates() {
        manager.setBudget(monthly: 100.0)
        manager.updateBudgetSpend(10.0)
        manager.updateBudgetSpend(15.0)
        manager.updateBudgetSpend(5.0)
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 30.0, accuracy: 0.001)
    }

    func testUpdateBudgetSpend_NoBudget_NoOp() {
        // Should not crash when no budget is set
        manager.updateBudgetSpend(10.0)
        XCTAssertNil(manager.budgetAlert)
    }

    func testUpdateBudgetSpend_TriggersWarningLevel() {
        manager.setBudget(monthly: 100.0, alertThreshold: 0.8)
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .normal)

        // Spend 85% — should move to warning
        manager.updateBudgetSpend(85.0)
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .warning)
        XCTAssertNotNil(manager.budgetAlert?.lastTriggeredAt)
    }

    func testUpdateBudgetSpend_TriggersCriticalLevel() {
        manager.setBudget(monthly: 100.0, alertThreshold: 0.8)

        // Spend 95% — should move to critical
        manager.updateBudgetSpend(95.0)
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .critical)
        XCTAssertNotNil(manager.budgetAlert?.lastTriggeredAt)
    }

    func testUpdateBudgetSpend_NormalToWarningToCritical() {
        manager.setBudget(monthly: 100.0, alertThreshold: 0.8)
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .normal)

        manager.updateBudgetSpend(50.0)
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .normal)

        manager.updateBudgetSpend(35.0) // total 85
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .warning)

        manager.updateBudgetSpend(10.0) // total 95
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .critical)
    }

    // MARK: - Remove Budget

    func testRemoveBudget() {
        manager.setBudget(monthly: 100.0)
        XCTAssertNotNil(manager.budgetAlert)
        manager.removeBudget()
        XCTAssertNil(manager.budgetAlert)
    }

    func testRemoveBudget_WhenNoBudget() {
        // Should not crash
        manager.removeBudget()
        XCTAssertNil(manager.budgetAlert)
    }

    // MARK: - Generate Forecast

    func testGenerateForecast_RequiresAtLeast3Records() {
        // With fewer than 3 records, forecast should not be generated
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50, latencyMs: 500.0, costUSD: 0.01, taskType: "general")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 200, outputTokens: 100, latencyMs: 800.0, costUSD: 0.02, taskType: "general")
        manager.generateForecast()
        XCTAssertNil(manager.usageForecast)
    }

    func testGenerateForecast_WithSufficientRecords() {
        // Add 5 records with varying timestamps to ensure distinct days
        for i in 0..<5 {
            manager.recordAPICall(
                model: "claude-sonnet-4",
                inputTokens: 100 + i * 50,
                outputTokens: 50 + i * 25,
                latencyMs: 500.0 + Double(i) * 100,
                costUSD: 0.01 + Double(i) * 0.005,
                taskType: "coding"
            )
        }
        manager.generateForecast()
        XCTAssertNotNil(manager.usageForecast)
        XCTAssertGreaterThan(manager.usageForecast?.forecastedMonthEndCost ?? 0, 0)
        XCTAssertGreaterThan(manager.usageForecast?.dailyAverage ?? 0, 0)
    }

    func testGenerateForecast_HasDataPoints() {
        for i in 0..<5 {
            manager.recordAPICall(
                model: "claude-opus-4",
                inputTokens: 500,
                outputTokens: 300,
                latencyMs: 2000.0,
                costUSD: 0.10,
                taskType: "coding"
            )
        }
        manager.generateForecast()
        XCTAssertNotNil(manager.usageForecast)
        XCTAssertFalse(manager.usageForecast?.dataPoints.isEmpty ?? true)
    }

    func testGenerateForecast_SkipsWithFewerThan3Records() {
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50, latencyMs: 500.0, costUSD: 0.01, taskType: "general")
        manager.generateForecast()
        XCTAssertNil(manager.usageForecast)
    }

    // MARK: - Update Summary

    func testUpdateSummary_CalculatesFromRecords() {
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 2000.0, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 200, outputTokens: 100, latencyMs: 1000.0, costUSD: 0.02, taskType: "review")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 400, outputTokens: 200, latencyMs: 1500.0, costUSD: 0.08, taskType: "debugging", isError: true, errorType: "timeout")

        // recordAPICall calls updateSummary automatically, but call explicitly for clarity
        manager.updateSummary()

        XCTAssertEqual(manager.summary.totalCalls, 3)
        XCTAssertEqual(manager.summary.totalTokens, 500 + 300 + 200 + 100 + 400 + 200) // 1700
        XCTAssertEqual(manager.summary.totalCost, 0.20, accuracy: 0.001)
        XCTAssertEqual(manager.summary.errorCount, 1)
        XCTAssertEqual(manager.summary.uniqueModels, 2)
        let expectedAvgLatency = (2000.0 + 1000.0 + 1500.0) / 3.0
        XCTAssertEqual(manager.summary.averageLatencyMs, expectedAvgLatency, accuracy: 0.1)
    }

    func testUpdateSummary_ReturnsEmptyWhenNoRecords() {
        manager.updateSummary()
        XCTAssertEqual(manager.summary.totalCalls, 0)
        XCTAssertEqual(manager.summary.totalTokens, 0)
        XCTAssertEqual(manager.summary.totalCost, 0)
        XCTAssertEqual(manager.summary.errorCount, 0)
    }

    // MARK: - Update Model Stats

    func testUpdateModelStats_GroupsCorrectly() {
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 2000.0, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 400, outputTokens: 200, latencyMs: 1800.0, costUSD: 0.08, taskType: "coding")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 200, outputTokens: 100, latencyMs: 1000.0, costUSD: 0.02, taskType: "review")
        manager.recordAPICall(model: "claude-haiku-3.5", inputTokens: 100, outputTokens: 50, latencyMs: 300.0, costUSD: 0.001, taskType: "general")

        manager.updateModelStats()

        XCTAssertEqual(manager.modelStats.count, 3)
    }

    func testUpdateModelStats_SortedByCostDesc() {
        manager.recordAPICall(model: "claude-haiku-3.5", inputTokens: 100, outputTokens: 50, latencyMs: 300.0, costUSD: 0.001, taskType: "general")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 2000.0, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 200, outputTokens: 100, latencyMs: 1000.0, costUSD: 0.03, taskType: "review")

        manager.updateModelStats()

        XCTAssertEqual(manager.modelStats[0].modelName, "claude-opus-4")
        XCTAssertEqual(manager.modelStats[1].modelName, "claude-sonnet-4")
        XCTAssertEqual(manager.modelStats[2].modelName, "claude-haiku-3.5")
    }

    func testUpdateModelStats_CalculatesPerModelValues() {
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 2000.0, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 400, outputTokens: 200, latencyMs: 1800.0, costUSD: 0.08, taskType: "coding", isError: true, errorType: "timeout")

        manager.updateModelStats()

        let opusStats = manager.modelStats.first { $0.modelName == "claude-opus-4" }
        XCTAssertNotNil(opusStats)
        XCTAssertEqual(opusStats?.totalCalls, 2)
        XCTAssertEqual(opusStats?.totalTokens, 500 + 300 + 400 + 200) // 1400
        XCTAssertEqual(opusStats?.totalCost ?? 0, 0.18, accuracy: 0.001)
        XCTAssertEqual(opusStats?.errorRate ?? 0, 0.5, accuracy: 0.001)
        let expectedAvgLatency = (2000.0 + 1800.0) / 2.0
        XCTAssertEqual(opusStats?.averageLatencyMs ?? 0, expectedAvgLatency, accuracy: 0.1)
    }

    // MARK: - Load Sample Data

    func testLoadSampleData_RecordCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.callRecords.count, 25)
    }

    func testLoadSampleData_CostBreakdownsNotEmpty() {
        manager.loadSampleData()
        XCTAssertFalse(manager.costBreakdowns.isEmpty)
    }

    func testLoadSampleData_ModelStats() {
        manager.loadSampleData()
        XCTAssertEqual(manager.modelStats.count, 3)
    }

    func testLoadSampleData_BudgetSet() {
        manager.loadSampleData()
        XCTAssertNotNil(manager.budgetAlert)
        XCTAssertEqual(manager.budgetAlert?.monthlyBudget, 50.0)
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 30.0, accuracy: 0.01)
    }

    func testLoadSampleData_ForecastSet() {
        manager.loadSampleData()
        XCTAssertNotNil(manager.usageForecast)
        XCTAssertEqual(manager.usageForecast?.trend, .increasing)
    }

    func testLoadSampleData_SummaryUpdated() {
        manager.loadSampleData()
        XCTAssertEqual(manager.summary.totalCalls, 25)
        XCTAssertGreaterThan(manager.summary.totalCost, 0)
    }

    // MARK: - Error Rate (Computed)

    func testErrorRate_NoErrors() {
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50, latencyMs: 500.0, costUSD: 0.01, taskType: "general")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 200, outputTokens: 100, latencyMs: 800.0, costUSD: 0.02, taskType: "general")
        XCTAssertEqual(manager.errorRate, 0.0, accuracy: 0.001)
    }

    func testErrorRate_WithErrors() {
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50, latencyMs: 500.0, costUSD: 0.01, taskType: "general")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 0, latencyMs: 30000.0, costUSD: 0.0, taskType: "general", isError: true, errorType: "timeout")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 200, outputTokens: 100, latencyMs: 1200.0, costUSD: 0.05, taskType: "coding")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 200, outputTokens: 0, latencyMs: 25000.0, costUSD: 0.0, taskType: "coding", isError: true, errorType: "rate_limit")
        // 2 errors out of 4 = 50%
        XCTAssertEqual(manager.errorRate, 0.5, accuracy: 0.001)
    }

    func testErrorRate_EmptyRecords() {
        XCTAssertEqual(manager.errorRate, 0.0)
    }

    // MARK: - Average Latency (Computed)

    func testAvgLatency_Computed() {
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50, latencyMs: 500.0, costUSD: 0.01, taskType: "general")
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 200, outputTokens: 100, latencyMs: 1500.0, costUSD: 0.05, taskType: "coding")
        manager.recordAPICall(model: "claude-haiku-3.5", inputTokens: 50, outputTokens: 25, latencyMs: 200.0, costUSD: 0.001, taskType: "general")
        // Average: (500 + 1500 + 200) / 3 = 733.33...
        let expected = (500.0 + 1500.0 + 200.0) / 3.0
        XCTAssertEqual(manager.avgLatency, expected, accuracy: 0.01)
    }

    func testAvgLatency_EmptyRecords() {
        XCTAssertEqual(manager.avgLatency, 0.0)
    }

    // MARK: - Total Cost (Computed)

    func testTotalCost_Computed() {
        manager.recordAPICall(model: "claude-opus-4", inputTokens: 500, outputTokens: 300, latencyMs: 2000.0, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "claude-sonnet-4", inputTokens: 200, outputTokens: 100, latencyMs: 1000.0, costUSD: 0.02, taskType: "review")
        manager.recordAPICall(model: "claude-haiku-3.5", inputTokens: 100, outputTokens: 50, latencyMs: 300.0, costUSD: 0.001, taskType: "general")
        XCTAssertEqual(manager.totalCost, 0.121, accuracy: 0.0001)
    }

    func testTotalCost_EmptyReturnsZero() {
        XCTAssertEqual(manager.totalCost, 0.0)
    }

    // MARK: - Forecast Data Point Validation

    func testGenerateForecast_ActualPointsHaveEqualBounds() {
        let now = Date()
        for i in 0..<5 {
            var metric = APICallMetrics(
                model: "test", inputTokens: 100, outputTokens: 50,
                latencyMs: 500.0, costUSD: 1.0, taskType: "test"
            )
            metric.timestamp = now.addingTimeInterval(-Double(i) * 86400)
            manager.callRecords.insert(metric, at: 0)
        }
        manager.generateForecast()

        let actualPoints = manager.usageForecast?.dataPoints.filter(\.isActual) ?? []
        for point in actualPoints {
            XCTAssertEqual(point.lowerBound, point.value, accuracy: 0.001)
            XCTAssertEqual(point.upperBound, point.value, accuracy: 0.001)
        }
    }

    func testGenerateForecast_PredictedPointsHaveWiderBounds() {
        let now = Date()
        for i in 0..<7 {
            var metric = APICallMetrics(
                model: "test", inputTokens: 100, outputTokens: 50,
                latencyMs: 500.0, costUSD: Double.random(in: 0.5...2.0), taskType: "test"
            )
            metric.timestamp = now.addingTimeInterval(-Double(i) * 86400)
            manager.callRecords.insert(metric, at: 0)
        }
        manager.generateForecast()

        let predictedPoints = manager.usageForecast?.dataPoints.filter { !$0.isActual } ?? []
        for point in predictedPoints {
            XCTAssertLessThanOrEqual(point.lowerBound, point.value)
            XCTAssertGreaterThanOrEqual(point.upperBound, point.value)
        }
    }

    // MARK: - Budget Edge Cases

    func testBudgetSpendDoesNotUpdateWhenInactive() {
        manager.setBudget(monthly: 100.0)
        manager.budgetAlert?.isActive = false
        manager.updateBudgetSpend(50.0)
        XCTAssertEqual(manager.budgetAlert!.currentSpend, 0, accuracy: 0.001)
    }

    func testBudgetAlertLevelProgressionWithSmallIncrements() {
        manager.setBudget(monthly: 100.0, alertThreshold: 0.8)

        for _ in 0..<79 {
            manager.updateBudgetSpend(1.0)
        }
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .normal)

        manager.updateBudgetSpend(2.0) // Total: 81
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .warning)

        for _ in 0..<9 {
            manager.updateBudgetSpend(1.0)
        }
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .critical) // Total: 90
    }

    // MARK: - Summary Edge Cases

    func testSummaryPeriodStartAndEnd() {
        let now = Date()
        var m1 = APICallMetrics(model: "a", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.01, taskType: "test")
        m1.timestamp = now.addingTimeInterval(-86400)
        var m2 = APICallMetrics(model: "b", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.01, taskType: "test")
        m2.timestamp = now

        manager.callRecords = [m2, m1]
        manager.updateSummary()

        XCTAssertLessThan(manager.summary.periodStart, manager.summary.periodEnd)
    }

    // MARK: - Model Stats Edge Cases

    func testUpdateModelStats_WithNoRecords() {
        manager.updateModelStats()
        XCTAssertTrue(manager.modelStats.isEmpty)
    }

    func testUpdateModelStats_SingleModel() {
        manager.recordAPICall(model: "sole-model", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.01, taskType: "test")
        manager.updateModelStats()
        XCTAssertEqual(manager.modelStats.count, 1)
        XCTAssertEqual(manager.modelStats.first?.modelName, "sole-model")
    }
}
