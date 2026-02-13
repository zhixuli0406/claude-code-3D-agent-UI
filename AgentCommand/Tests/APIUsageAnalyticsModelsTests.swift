import XCTest
@testable import AgentCommand

// MARK: - M3: API Usage Analytics Models Unit Tests

// MARK: - APICallMetrics Tests

final class APICallMetricsTests: XCTestCase {

    func testMetricCreation() {
        let metric = APICallMetrics(
            model: "claude-sonnet-4-5-20250929",
            inputTokens: 500,
            outputTokens: 200,
            latencyMs: 1500,
            costUSD: 0.0035
        )
        XCTAssertFalse(metric.id.isEmpty)
        XCTAssertEqual(metric.model, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(metric.inputTokens, 500)
        XCTAssertEqual(metric.outputTokens, 200)
        XCTAssertEqual(metric.taskType, "general")
        XCTAssertFalse(metric.isError)
    }

    func testTotalTokens() {
        let metric = APICallMetrics(model: "gpt-4", inputTokens: 300, outputTokens: 150, latencyMs: 800, costUSD: 0.002)
        XCTAssertEqual(metric.totalTokens, 450)
    }

    func testFormattedLatencyMilliseconds() {
        let metric = APICallMetrics(model: "claude", inputTokens: 100, outputTokens: 50, latencyMs: 450, costUSD: 0.001)
        XCTAssertEqual(metric.formattedLatency, "450ms")
    }

    func testFormattedLatencySeconds() {
        let metric = APICallMetrics(model: "claude", inputTokens: 100, outputTokens: 50, latencyMs: 2500, costUSD: 0.001)
        XCTAssertEqual(metric.formattedLatency, "2.5s")
    }

    func testFormattedCost() {
        let metric = APICallMetrics(model: "claude", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.0015)
        XCTAssertEqual(metric.formattedCost, "$0.0015")
    }

    func testErrorMetric() {
        let metric = APICallMetrics(model: "claude", inputTokens: 100, outputTokens: 0, latencyMs: 30000, costUSD: 0, isError: true, errorType: "timeout")
        XCTAssertTrue(metric.isError)
        XCTAssertEqual(metric.errorType, "timeout")
    }

    func testMetricCodable() throws {
        let metric = APICallMetrics(model: "test-model", inputTokens: 200, outputTokens: 100, latencyMs: 600, costUSD: 0.005, taskType: "coding")
        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(APICallMetrics.self, from: data)
        XCTAssertEqual(decoded.model, "test-model")
        XCTAssertEqual(decoded.totalTokens, 300)
        XCTAssertEqual(decoded.taskType, "coding")
    }
}

// MARK: - CostBreakdown Tests

final class CostBreakdownTests: XCTestCase {

    func testBreakdownCreation() {
        let entries = [
            CostBreakdownEntry(category: "claude-opus", cost: 5.0, tokenCount: 10000, callCount: 50, totalCost: 8.0),
            CostBreakdownEntry(category: "claude-sonnet", cost: 3.0, tokenCount: 15000, callCount: 100, totalCost: 8.0)
        ]
        let breakdown = CostBreakdown(entries: entries, period: "Last 7 days")
        XCTAssertEqual(breakdown.totalCost, 8.0)
        XCTAssertEqual(breakdown.entries.count, 2)
    }

    func testBreakdownFormattedTotal() {
        let entries = [
            CostBreakdownEntry(category: "model-a", cost: 12.34, tokenCount: 5000, callCount: 20, totalCost: 12.34)
        ]
        let breakdown = CostBreakdown(entries: entries, period: "Monthly")
        XCTAssertEqual(breakdown.formattedTotal, "$12.34")
    }

    func testEntryPercentage() {
        let entry = CostBreakdownEntry(category: "model-a", cost: 25.0, tokenCount: 5000, callCount: 10, totalCost: 100.0)
        XCTAssertEqual(entry.percentage, 0.25, accuracy: 0.001)
        XCTAssertEqual(entry.percentageDisplay, 25)
    }

    func testEntryPercentageZeroDivision() {
        let entry = CostBreakdownEntry(category: "model-a", cost: 0, tokenCount: 0, callCount: 0, totalCost: 0)
        XCTAssertEqual(entry.percentage, 0)
    }

    func testBreakdownCodable() throws {
        let entries = [
            CostBreakdownEntry(category: "test", cost: 1.0, tokenCount: 100, callCount: 5, totalCost: 1.0)
        ]
        let breakdown = CostBreakdown(entries: entries, period: "Test")
        let data = try JSONEncoder().encode(breakdown)
        let decoded = try JSONDecoder().decode(CostBreakdown.self, from: data)
        XCTAssertEqual(decoded.totalCost, 1.0)
        XCTAssertEqual(decoded.entries.count, 1)
    }
}

// MARK: - BudgetAlert Tests

final class BudgetAlertTests: XCTestCase {

    func testBudgetCreation() {
        let alert = BudgetAlert(monthlyBudget: 100.0)
        XCTAssertEqual(alert.monthlyBudget, 100.0)
        XCTAssertEqual(alert.currentSpend, 0)
        XCTAssertEqual(alert.alertThreshold, 0.8)
        XCTAssertTrue(alert.isActive)
    }

    func testSpendPercentage() {
        var alert = BudgetAlert(monthlyBudget: 200.0)
        alert.currentSpend = 100.0
        XCTAssertEqual(alert.spendPercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(alert.spendPercentageDisplay, 50)
    }

    func testSpendPercentageZeroBudget() {
        let alert = BudgetAlert(monthlyBudget: 0)
        XCTAssertEqual(alert.spendPercentage, 0)
    }

    func testRemainingBudget() {
        var alert = BudgetAlert(monthlyBudget: 100.0)
        alert.currentSpend = 60.0
        XCTAssertEqual(alert.remainingBudget, 40.0, accuracy: 0.01)
    }

    func testRemainingBudgetNeverNegative() {
        var alert = BudgetAlert(monthlyBudget: 50.0)
        alert.currentSpend = 75.0
        XCTAssertEqual(alert.remainingBudget, 0)
    }

    func testFormattedValues() {
        var alert = BudgetAlert(monthlyBudget: 150.50)
        alert.currentSpend = 80.25
        XCTAssertEqual(alert.formattedBudget, "$150.50")
        XCTAssertEqual(alert.formattedSpend, "$80.25")
        XCTAssertEqual(alert.formattedRemaining, "$70.25")
    }

    func testAlertLevelNormal() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 50.0
        XCTAssertEqual(alert.alertLevel, .normal)
    }

    func testAlertLevelWarning() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 85.0
        XCTAssertEqual(alert.alertLevel, .warning)
    }

    func testAlertLevelCritical() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 95.0
        XCTAssertEqual(alert.alertLevel, .critical)
    }

    func testAlertLevelColorHex() {
        XCTAssertEqual(BudgetAlert.BudgetAlertLevel.normal.colorHex, "#4CAF50")
        XCTAssertEqual(BudgetAlert.BudgetAlertLevel.warning.colorHex, "#FF9800")
        XCTAssertEqual(BudgetAlert.BudgetAlertLevel.critical.colorHex, "#F44336")
    }

    func testAlertLevelIconName() {
        for level in [BudgetAlert.BudgetAlertLevel.normal, .warning, .critical] {
            XCTAssertFalse(level.iconName.isEmpty)
        }
    }

    func testBudgetCodable() throws {
        var alert = BudgetAlert(monthlyBudget: 200.0, alertThreshold: 0.75)
        alert.currentSpend = 120.0
        let data = try JSONEncoder().encode(alert)
        let decoded = try JSONDecoder().decode(BudgetAlert.self, from: data)
        XCTAssertEqual(decoded.monthlyBudget, 200.0)
        XCTAssertEqual(decoded.currentSpend, 120.0)
        XCTAssertEqual(decoded.alertThreshold, 0.75)
    }
}

// MARK: - UsageForecast Tests

final class UsageForecastTests: XCTestCase {

    func testForecastCreation() {
        let forecast = UsageForecast(
            forecastedMonthEndCost: 250.0,
            forecastedMonthEndTokens: 500000,
            dailyAverage: 8.33,
            trend: .increasing
        )
        XCTAssertFalse(forecast.id.isEmpty)
        XCTAssertEqual(forecast.forecastedMonthEndCost, 250.0)
        XCTAssertEqual(forecast.trend, .increasing)
    }

    func testFormattedForecastCost() {
        let forecast = UsageForecast(forecastedMonthEndCost: 123.45, forecastedMonthEndTokens: 100000, dailyAverage: 4.11, trend: .stable)
        XCTAssertEqual(forecast.formattedForecastCost, "$123.45")
    }

    func testFormattedDailyAverage() {
        let forecast = UsageForecast(forecastedMonthEndCost: 100.0, forecastedMonthEndTokens: 50000, dailyAverage: 3.33, trend: .decreasing)
        XCTAssertEqual(forecast.formattedDailyAverage, "$3.33/day")
    }

    func testUsageTrendDisplayNames() {
        XCTAssertEqual(UsageForecast.UsageTrend.increasing.displayName, "Increasing")
        XCTAssertEqual(UsageForecast.UsageTrend.stable.displayName, "Stable")
        XCTAssertEqual(UsageForecast.UsageTrend.decreasing.displayName, "Decreasing")
    }

    func testUsageTrendIconNames() {
        for trend in [UsageForecast.UsageTrend.increasing, .stable, .decreasing] {
            XCTAssertFalse(trend.iconName.isEmpty)
        }
    }

    func testUsageTrendColorHex() {
        XCTAssertEqual(UsageForecast.UsageTrend.increasing.colorHex, "#F44336")
        XCTAssertEqual(UsageForecast.UsageTrend.stable.colorHex, "#FF9800")
        XCTAssertEqual(UsageForecast.UsageTrend.decreasing.colorHex, "#4CAF50")
    }

    func testForecastCodable() throws {
        let forecast = UsageForecast(forecastedMonthEndCost: 50.0, forecastedMonthEndTokens: 25000, dailyAverage: 1.67, trend: .stable)
        let data = try JSONEncoder().encode(forecast)
        let decoded = try JSONDecoder().decode(UsageForecast.self, from: data)
        XCTAssertEqual(decoded.forecastedMonthEndCost, 50.0)
        XCTAssertEqual(decoded.trend, .stable)
    }
}

// MARK: - ModelUsageStats Tests

final class ModelUsageStatsTests: XCTestCase {

    func testStatsCreation() {
        let stats = ModelUsageStats(modelName: "claude-sonnet", totalCalls: 100, totalTokens: 50000, totalCost: 25.0, averageLatencyMs: 800, errorRate: 0.05)
        XCTAssertEqual(stats.modelName, "claude-sonnet")
        XCTAssertEqual(stats.totalCalls, 100)
    }

    func testFormattedCost() {
        let stats = ModelUsageStats(modelName: "test", totalCost: 12.50)
        XCTAssertEqual(stats.formattedCost, "$12.50")
    }

    func testErrorRatePercentage() {
        let stats = ModelUsageStats(modelName: "test", errorRate: 0.15)
        XCTAssertEqual(stats.errorRatePercentage, 15)
    }

    func testCostPerCall() {
        let stats = ModelUsageStats(modelName: "test", totalCalls: 50, totalCost: 10.0)
        XCTAssertEqual(stats.costPerCall, 0.2, accuracy: 0.001)
    }

    func testCostPerCallZeroDivision() {
        let stats = ModelUsageStats(modelName: "test", totalCalls: 0, totalCost: 0)
        XCTAssertEqual(stats.costPerCall, 0)
    }

    func testTokensPerCall() {
        let stats = ModelUsageStats(modelName: "test", totalCalls: 20, totalTokens: 10000)
        XCTAssertEqual(stats.tokensPerCall, 500.0, accuracy: 0.001)
    }

    func testTokensPerCallZeroDivision() {
        let stats = ModelUsageStats(modelName: "test", totalCalls: 0, totalTokens: 0)
        XCTAssertEqual(stats.tokensPerCall, 0)
    }
}

// MARK: - APIUsageSummary Tests

final class APIUsageSummaryTests: XCTestCase {

    func testEmptySummary() {
        let empty = APIUsageSummary.empty
        XCTAssertEqual(empty.totalCalls, 0)
        XCTAssertEqual(empty.totalTokens, 0)
        XCTAssertEqual(empty.totalCost, 0)
        XCTAssertEqual(empty.errorCount, 0)
    }

    func testErrorRate() {
        let summary = APIUsageSummary(
            totalCalls: 100, totalTokens: 50000, totalCost: 25.0,
            averageLatencyMs: 500, errorCount: 10, uniqueModels: 3,
            periodStart: Date(), periodEnd: Date()
        )
        XCTAssertEqual(summary.errorRate, 0.1, accuracy: 0.001)
        XCTAssertEqual(summary.errorRatePercentage, 10)
    }

    func testErrorRateZeroDivision() {
        let summary = APIUsageSummary.empty
        XCTAssertEqual(summary.errorRate, 0)
    }

    func testFormattedCost() {
        let summary = APIUsageSummary(
            totalCalls: 50, totalTokens: 25000, totalCost: 8.75,
            averageLatencyMs: 600, errorCount: 2, uniqueModels: 2,
            periodStart: Date(), periodEnd: Date()
        )
        XCTAssertEqual(summary.formattedCost, "$8.75")
    }

    func testSummaryCodable() throws {
        let summary = APIUsageSummary(
            totalCalls: 10, totalTokens: 5000, totalCost: 2.50,
            averageLatencyMs: 400, errorCount: 1, uniqueModels: 1,
            periodStart: Date(), periodEnd: Date()
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(APIUsageSummary.self, from: data)
        XCTAssertEqual(decoded.totalCalls, 10)
        XCTAssertEqual(decoded.totalCost, 2.50)
    }
}

// MARK: - Edge Case & Boundary Tests

final class APIUsageAnalyticsEdgeCaseTests: XCTestCase {

    // MARK: - APICallMetrics Edge Cases

    func testMetricZeroTokens() {
        let metric = APICallMetrics(model: "test", inputTokens: 0, outputTokens: 0, latencyMs: 100, costUSD: 0)
        XCTAssertEqual(metric.totalTokens, 0)
    }

    func testMetricLargeTokenCount() {
        let metric = APICallMetrics(model: "test", inputTokens: 100_000, outputTokens: 50_000, latencyMs: 10000, costUSD: 5.0)
        XCTAssertEqual(metric.totalTokens, 150_000)
    }

    func testFormattedLatencyAtExactly1000ms() {
        let metric = APICallMetrics(model: "test", inputTokens: 100, outputTokens: 50, latencyMs: 1000, costUSD: 0.01)
        XCTAssertEqual(metric.formattedLatency, "1.0s")
    }

    func testFormattedLatencyJustBelow1000ms() {
        let metric = APICallMetrics(model: "test", inputTokens: 100, outputTokens: 50, latencyMs: 999, costUSD: 0.01)
        XCTAssertEqual(metric.formattedLatency, "999ms")
    }

    func testFormattedCostZero() {
        let metric = APICallMetrics(model: "test", inputTokens: 0, outputTokens: 0, latencyMs: 0, costUSD: 0)
        XCTAssertEqual(metric.formattedCost, "$0.0000")
    }

    func testMetricUniqueIDs() {
        let m1 = APICallMetrics(model: "a", inputTokens: 1, outputTokens: 1, latencyMs: 1, costUSD: 0)
        let m2 = APICallMetrics(model: "a", inputTokens: 1, outputTokens: 1, latencyMs: 1, costUSD: 0)
        XCTAssertNotEqual(m1.id, m2.id)
    }

    func testMetricWithCustomTaskType() {
        let metric = APICallMetrics(model: "test", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.01, taskType: "custom-task")
        XCTAssertEqual(metric.taskType, "custom-task")
    }

    // MARK: - CostBreakdown Edge Cases

    func testBreakdownEmptyEntries() {
        let breakdown = CostBreakdown(entries: [], period: "Empty")
        XCTAssertEqual(breakdown.totalCost, 0)
        XCTAssertEqual(breakdown.formattedTotal, "$0.00")
    }

    func testBreakdownSingleEntry() {
        let entry = CostBreakdownEntry(category: "solo", cost: 10.0, tokenCount: 5000, callCount: 20, totalCost: 10.0)
        let breakdown = CostBreakdown(entries: [entry], period: "Solo")
        XCTAssertEqual(breakdown.totalCost, 10.0)
        XCTAssertEqual(breakdown.entries.first!.percentage, 1.0, accuracy: 0.001)
    }

    func testBreakdownEntryFormattedCost() {
        let entry = CostBreakdownEntry(category: "test", cost: 0.005, tokenCount: 10, callCount: 1, totalCost: 0.005)
        XCTAssertEqual(entry.formattedCost, "$0.01") // Rounded to 2 decimal places
    }

    // MARK: - BudgetAlert Edge Cases

    func testBudgetAlertExactThreshold() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 80.0
        XCTAssertEqual(alert.alertLevel, .warning)
    }

    func testBudgetAlertJustBelowThreshold() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 79.99
        XCTAssertEqual(alert.alertLevel, .normal)
    }

    func testBudgetAlertExactCritical() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 90.0
        XCTAssertEqual(alert.alertLevel, .critical)
    }

    func testBudgetAlertJustBelowCritical() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        alert.currentSpend = 89.99
        XCTAssertEqual(alert.alertLevel, .warning)
    }

    func testBudgetAlertOverBudget() {
        var alert = BudgetAlert(monthlyBudget: 100.0)
        alert.currentSpend = 150.0
        XCTAssertEqual(alert.spendPercentage, 1.5, accuracy: 0.001)
        XCTAssertEqual(alert.remainingBudget, 0)
        XCTAssertEqual(alert.alertLevel, .critical)
    }

    func testBudgetAlertAllLevelDisplayNames() {
        for level in [BudgetAlert.BudgetAlertLevel.normal, .warning, .critical] {
            XCTAssertFalse(level.displayName.isEmpty)
        }
    }

    // MARK: - UsageForecast Edge Cases

    func testForecastWithEmptyDataPoints() {
        let forecast = UsageForecast(
            forecastedMonthEndCost: 0, forecastedMonthEndTokens: 0,
            dailyAverage: 0, trend: .stable, dataPoints: []
        )
        XCTAssertTrue(forecast.dataPoints.isEmpty)
        XCTAssertEqual(forecast.formattedForecastCost, "$0.00")
        XCTAssertEqual(forecast.formattedDailyAverage, "$0.00/day")
    }

    func testForecastHighCost() {
        let forecast = UsageForecast(
            forecastedMonthEndCost: 10000.0, forecastedMonthEndTokens: 5_000_000,
            dailyAverage: 333.33, trend: .increasing
        )
        XCTAssertEqual(forecast.formattedForecastCost, "$10000.00")
        XCTAssertEqual(forecast.formattedDailyAverage, "$333.33/day")
    }

    // MARK: - ModelUsageStats Edge Cases

    func testModelStatsDefaultValues() {
        let stats = ModelUsageStats(modelName: "default")
        XCTAssertEqual(stats.totalCalls, 0)
        XCTAssertEqual(stats.totalTokens, 0)
        XCTAssertEqual(stats.totalCost, 0)
        XCTAssertEqual(stats.averageLatencyMs, 0)
        XCTAssertEqual(stats.errorRate, 0)
        XCTAssertNil(stats.lastUsedAt)
    }

    func testModelStatsCostPerCallNonZero() {
        let stats = ModelUsageStats(modelName: "test", totalCalls: 100, totalCost: 5.0)
        XCTAssertEqual(stats.costPerCall, 0.05, accuracy: 0.001)
    }

    func testModelStatsTokensPerCallNonZero() {
        let stats = ModelUsageStats(modelName: "test", totalCalls: 100, totalTokens: 50000)
        XCTAssertEqual(stats.tokensPerCall, 500.0, accuracy: 0.001)
    }

    func testModelStatsCodable() throws {
        var stats = ModelUsageStats(modelName: "claude-opus", totalCalls: 50, totalTokens: 25000, totalCost: 12.5, averageLatencyMs: 2000, errorRate: 0.04)
        stats.lastUsedAt = Date()
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(ModelUsageStats.self, from: data)
        XCTAssertEqual(decoded.modelName, "claude-opus")
        XCTAssertEqual(decoded.totalCalls, 50)
        XCTAssertNotNil(decoded.lastUsedAt)
    }

    // MARK: - APIUsageSummary Edge Cases

    func testSummaryAllErrors() {
        let summary = APIUsageSummary(
            totalCalls: 10, totalTokens: 1000, totalCost: 1.0,
            averageLatencyMs: 5000, errorCount: 10, uniqueModels: 1,
            periodStart: Date(), periodEnd: Date()
        )
        XCTAssertEqual(summary.errorRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(summary.errorRatePercentage, 100)
    }

    func testSummaryNoErrors() {
        let summary = APIUsageSummary(
            totalCalls: 100, totalTokens: 50000, totalCost: 10.0,
            averageLatencyMs: 500, errorCount: 0, uniqueModels: 3,
            periodStart: Date(), periodEnd: Date()
        )
        XCTAssertEqual(summary.errorRate, 0)
        XCTAssertEqual(summary.errorRatePercentage, 0)
    }
}
