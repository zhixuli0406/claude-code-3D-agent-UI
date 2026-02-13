import XCTest
@testable import AgentCommand

// MARK: - M1: Analytics Dashboard Models Unit Tests

// MARK: - DashboardReport Tests

final class DashboardReportTests: XCTestCase {

    func testReportCreation() {
        let report = DashboardReport(name: "Test Report", description: "A test")
        XCTAssertFalse(report.id.isEmpty)
        XCTAssertEqual(report.name, "Test Report")
        XCTAssertEqual(report.description, "A test")
        XCTAssertTrue(report.widgets.isEmpty)
        XCTAssertFalse(report.isDefault)
    }

    func testReportWithWidgets() {
        let widget = ReportWidget(type: .lineChart, title: "Tokens", dataSource: .tokenUsage)
        let report = DashboardReport(name: "With Widgets", widgets: [widget])
        XCTAssertEqual(report.widgets.count, 1)
        XCTAssertEqual(report.widgets.first?.type, .lineChart)
    }

    func testReportDefaultFlag() {
        let report = DashboardReport(name: "Default", isDefault: true)
        XCTAssertTrue(report.isDefault)
    }

    func testReportCodable() throws {
        let report = DashboardReport(name: "Codable Test")
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(DashboardReport.self, from: data)
        XCTAssertEqual(decoded.name, "Codable Test")
        XCTAssertEqual(decoded.id, report.id)
    }
}

// MARK: - ReportWidget Tests

final class ReportWidgetTests: XCTestCase {

    func testWidgetCreation() {
        let widget = ReportWidget(type: .barChart, title: "Cost", dataSource: .costOverTime, size: .large, position: 2)
        XCTAssertFalse(widget.id.isEmpty)
        XCTAssertEqual(widget.type, .barChart)
        XCTAssertEqual(widget.title, "Cost")
        XCTAssertEqual(widget.dataSource, .costOverTime)
        XCTAssertEqual(widget.size, .large)
        XCTAssertEqual(widget.position, 2)
    }

    func testWidgetTypeDisplayNames() {
        for widgetType in ReportWidget.WidgetType.allCases {
            XCTAssertFalse(widgetType.displayName.isEmpty, "\(widgetType) should have a displayName")
        }
    }

    func testWidgetTypeIconNames() {
        for widgetType in ReportWidget.WidgetType.allCases {
            XCTAssertFalse(widgetType.iconName.isEmpty, "\(widgetType) should have an iconName")
        }
    }

    func testWidgetDataSourceDisplayNames() {
        for source in ReportWidget.WidgetDataSource.allCases {
            XCTAssertFalse(source.displayName.isEmpty, "\(source) should have a displayName")
        }
    }

    func testWidgetSizeColumnSpan() {
        XCTAssertEqual(ReportWidget.WidgetSize.small.columnSpan, 1)
        XCTAssertEqual(ReportWidget.WidgetSize.medium.columnSpan, 2)
        XCTAssertEqual(ReportWidget.WidgetSize.large.columnSpan, 3)
    }

    func testWidgetCodable() throws {
        let widget = ReportWidget(type: .pieChart, title: "Distribution", dataSource: .modelDistribution)
        let data = try JSONEncoder().encode(widget)
        let decoded = try JSONDecoder().decode(ReportWidget.self, from: data)
        XCTAssertEqual(decoded.type, .pieChart)
        XCTAssertEqual(decoded.title, "Distribution")
    }
}

// MARK: - TrendForecast Tests

final class TrendForecastTests: XCTestCase {

    func testForecastCreation() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 0.85, periodDays: 14)
        XCTAssertFalse(forecast.id.isEmpty)
        XCTAssertEqual(forecast.metric, .cost)
        XCTAssertEqual(forecast.confidencePercentage, 85)
        XCTAssertEqual(forecast.periodDays, 14)
    }

    func testConfidenceLabelHigh() {
        let forecast = TrendForecast(metric: .tokenUsage, dataPoints: [], confidence: 0.9, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "High")
        XCTAssertEqual(forecast.confidenceColorHex, "#4CAF50")
    }

    func testConfidenceLabelMedium() {
        let forecast = TrendForecast(metric: .tokenUsage, dataPoints: [], confidence: 0.7, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "Medium")
        XCTAssertEqual(forecast.confidenceColorHex, "#FF9800")
    }

    func testConfidenceLabelLow() {
        let forecast = TrendForecast(metric: .tokenUsage, dataPoints: [], confidence: 0.4, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "Low")
        XCTAssertEqual(forecast.confidenceColorHex, "#F44336")
    }

    func testConfidenceBoundaryAt80() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 0.8, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "High")
    }

    func testConfidenceBoundaryAt60() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 0.6, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "Medium")
    }
}

// MARK: - ForecastDataPoint Tests

final class ForecastDataPointTests: XCTestCase {

    func testDataPointCreation() {
        let date = Date()
        let point = ForecastDataPoint(date: date, value: 100.0, lowerBound: 80.0, upperBound: 120.0)
        XCTAssertEqual(point.value, 100.0)
        XCTAssertEqual(point.lowerBound, 80.0)
        XCTAssertEqual(point.upperBound, 120.0)
        XCTAssertFalse(point.isActual)
    }

    func testActualDataPoint() {
        let point = ForecastDataPoint(date: Date(), value: 50.0, lowerBound: 50.0, upperBound: 50.0, isActual: true)
        XCTAssertTrue(point.isActual)
    }

    func testDataPointCodable() throws {
        let point = ForecastDataPoint(date: Date(), value: 42.0, lowerBound: 30.0, upperBound: 55.0)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(ForecastDataPoint.self, from: data)
        XCTAssertEqual(decoded.value, 42.0)
    }
}

// MARK: - ForecastMetric Tests

final class ForecastMetricTests: XCTestCase {

    func testAllMetricsHaveDisplayName() {
        for metric in ForecastMetric.allCases {
            XCTAssertFalse(metric.displayName.isEmpty, "\(metric) should have a displayName")
        }
    }

    func testAllMetricsHaveUnit() {
        for metric in ForecastMetric.allCases {
            XCTAssertFalse(metric.unit.isEmpty, "\(metric) should have a unit")
        }
    }

    func testAllMetricsHaveIconName() {
        for metric in ForecastMetric.allCases {
            XCTAssertFalse(metric.iconName.isEmpty, "\(metric) should have an iconName")
        }
    }

    func testCostMetricUnit() {
        XCTAssertEqual(ForecastMetric.cost.unit, "USD")
    }

    func testTokenUsageMetricUnit() {
        XCTAssertEqual(ForecastMetric.tokenUsage.unit, "tokens")
    }
}

// MARK: - CostOptimizationTip Tests

final class CostOptimizationTipTests: XCTestCase {

    func testTipCreation() {
        let tip = CostOptimizationTip(
            category: .modelSelection,
            title: "Use lighter models",
            description: "Switch to cheaper models for simple tasks",
            estimatedSavings: 12.50,
            impact: .high
        )
        XCTAssertFalse(tip.id.isEmpty)
        XCTAssertEqual(tip.category, .modelSelection)
        XCTAssertEqual(tip.estimatedSavings, 12.50)
        XCTAssertFalse(tip.isApplied)
    }

    func testFormattedSavings() {
        let tip = CostOptimizationTip(category: .caching, title: "Cache", description: "Cache results", estimatedSavings: 5.75, impact: .medium)
        XCTAssertEqual(tip.formattedSavings, "$5.75/mo")
    }

    func testAllCategoriesHaveDisplayName() {
        for category in CostOptimizationTip.OptimizationCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category) should have a displayName")
        }
    }

    func testAllCategoriesHaveIconName() {
        for category in CostOptimizationTip.OptimizationCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty, "\(category) should have an iconName")
        }
    }

    func testImpactColors() {
        XCTAssertEqual(CostOptimizationTip.OptimizationImpact.high.colorHex, "#4CAF50")
        XCTAssertEqual(CostOptimizationTip.OptimizationImpact.medium.colorHex, "#FF9800")
        XCTAssertEqual(CostOptimizationTip.OptimizationImpact.low.colorHex, "#2196F3")
    }

    func testTipCodable() throws {
        let tip = CostOptimizationTip(category: .tokenReduction, title: "Reduce", description: "Less tokens", estimatedSavings: 3.0, impact: .low)
        let data = try JSONEncoder().encode(tip)
        let decoded = try JSONDecoder().decode(CostOptimizationTip.self, from: data)
        XCTAssertEqual(decoded.title, "Reduce")
        XCTAssertEqual(decoded.category, .tokenReduction)
    }
}

// MARK: - PerformanceBenchmark Tests

final class PerformanceBenchmarkTests: XCTestCase {

    func testBenchmarkCreation() {
        let entries = [
            BenchmarkEntry(label: "Agent A", score: 0.9),
            BenchmarkEntry(label: "Agent B", score: 0.75)
        ]
        let benchmark = PerformanceBenchmark(name: "Test", entries: entries, metric: .taskSuccessRate)
        XCTAssertEqual(benchmark.entries.count, 2)
        XCTAssertEqual(benchmark.metric, .taskSuccessRate)
    }

    func testBestEntry() {
        let entries = [
            BenchmarkEntry(label: "A", score: 0.6),
            BenchmarkEntry(label: "B", score: 0.95),
            BenchmarkEntry(label: "C", score: 0.8)
        ]
        let benchmark = PerformanceBenchmark(name: "Test", entries: entries, metric: .costEfficiency)
        XCTAssertEqual(benchmark.bestEntry?.label, "B")
    }

    func testAverageScore() {
        let entries = [
            BenchmarkEntry(label: "A", score: 0.8),
            BenchmarkEntry(label: "B", score: 0.6)
        ]
        let benchmark = PerformanceBenchmark(name: "Test", entries: entries, metric: .tokenEfficiency)
        XCTAssertEqual(benchmark.averageScore, 0.7, accuracy: 0.001)
    }

    func testEmptyBenchmarkAverageScore() {
        let benchmark = PerformanceBenchmark(name: "Empty", entries: [], metric: .errorRecoveryRate)
        XCTAssertEqual(benchmark.averageScore, 0)
    }

    func testEntryScorePercentage() {
        let entry = BenchmarkEntry(label: "Test", score: 0.85)
        XCTAssertEqual(entry.scorePercentage, 85)
    }

    func testAllBenchmarkMetricsHaveDisplayName() {
        for metric in BenchmarkMetric.allCases {
            XCTAssertFalse(metric.displayName.isEmpty)
        }
    }

    func testAllBenchmarkMetricsHaveUnit() {
        for metric in BenchmarkMetric.allCases {
            XCTAssertFalse(metric.unit.isEmpty)
        }
    }
}

// MARK: - AnalyticsTimeRange Tests

final class AnalyticsTimeRangeTests: XCTestCase {

    func testAllRangesHaveDisplayName() {
        for range in AnalyticsTimeRange.allCases {
            XCTAssertFalse(range.displayName.isEmpty)
        }
    }

    func testCustomRangeDateInterval() {
        XCTAssertNil(AnalyticsTimeRange.custom.dateInterval)
    }

    func testNonCustomRangesHaveDateInterval() {
        for range in AnalyticsTimeRange.allCases where range != .custom {
            XCTAssertNotNil(range.dateInterval, "\(range) should have a dateInterval")
        }
    }

    func testLastHourInterval() {
        guard let interval = AnalyticsTimeRange.lastHour.dateInterval else {
            XCTFail("lastHour should have a dateInterval")
            return
        }
        XCTAssertEqual(interval.duration, 3600, accuracy: 1.0)
    }

    func testLast24HoursInterval() {
        guard let interval = AnalyticsTimeRange.last24Hours.dateInterval else {
            XCTFail("last24Hours should have a dateInterval")
            return
        }
        XCTAssertEqual(interval.duration, 86400, accuracy: 1.0)
    }

    func testLast7DaysInterval() {
        guard let interval = AnalyticsTimeRange.last7Days.dateInterval else {
            XCTFail("last7Days should have a dateInterval")
            return
        }
        XCTAssertEqual(interval.duration, 604800, accuracy: 1.0)
    }
}

// MARK: - AnalyticsDataPoint Tests

final class AnalyticsDataPointTests: XCTestCase {

    func testDataPointCreation() {
        let point = AnalyticsDataPoint(timestamp: Date(), value: 42.5, label: "Test")
        XCTAssertFalse(point.id.isEmpty)
        XCTAssertEqual(point.value, 42.5)
        XCTAssertEqual(point.label, "Test")
    }

    func testDataPointWithoutLabel() {
        let point = AnalyticsDataPoint(timestamp: Date(), value: 10.0)
        XCTAssertNil(point.label)
    }

    func testDataPointCodable() throws {
        let point = AnalyticsDataPoint(timestamp: Date(), value: 99.9, label: "Coded")
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(AnalyticsDataPoint.self, from: data)
        XCTAssertEqual(decoded.value, 99.9, accuracy: 0.01)
        XCTAssertEqual(decoded.label, "Coded")
    }
}

// MARK: - Edge Case & Boundary Tests

final class AnalyticsDashboardEdgeCaseTests: XCTestCase {

    // MARK: - TrendForecast Boundary Confidence Values

    func testConfidenceAtExactBoundary100() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 1.0, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "High")
        XCTAssertEqual(forecast.confidencePercentage, 100)
    }

    func testConfidenceAtZero() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 0.0, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "Low")
        XCTAssertEqual(forecast.confidencePercentage, 0)
    }

    func testConfidenceJustBelow60() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 0.59, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "Low")
    }

    func testConfidenceJustBelow80() {
        let forecast = TrendForecast(metric: .cost, dataPoints: [], confidence: 0.79, periodDays: 7)
        XCTAssertEqual(forecast.confidenceLabel, "Medium")
    }

    // MARK: - PerformanceBenchmark Edge Cases

    func testBenchmarkWithSingleEntry() {
        let entry = BenchmarkEntry(label: "Solo", score: 0.5)
        let benchmark = PerformanceBenchmark(name: "Solo", entries: [entry], metric: .taskSuccessRate)
        XCTAssertEqual(benchmark.bestEntry?.label, "Solo")
        XCTAssertEqual(benchmark.averageScore, 0.5, accuracy: 0.001)
    }

    func testBenchmarkBestEntryTieBreaker() {
        let entries = [
            BenchmarkEntry(label: "A", score: 0.9),
            BenchmarkEntry(label: "B", score: 0.9)
        ]
        let benchmark = PerformanceBenchmark(name: "Tie", entries: entries, metric: .costEfficiency)
        // max(by:) returns the last max element
        XCTAssertNotNil(benchmark.bestEntry)
        XCTAssertEqual(benchmark.bestEntry?.score, 0.9)
    }

    func testBenchmarkEmptyBestEntry() {
        let benchmark = PerformanceBenchmark(name: "Empty", entries: [], metric: .errorRecoveryRate)
        XCTAssertNil(benchmark.bestEntry)
    }

    // MARK: - BenchmarkEntry Score Edge Cases

    func testEntryScorePercentageZero() {
        let entry = BenchmarkEntry(label: "Zero", score: 0.0)
        XCTAssertEqual(entry.scorePercentage, 0)
    }

    func testEntryScorePercentageOne() {
        let entry = BenchmarkEntry(label: "Perfect", score: 1.0)
        XCTAssertEqual(entry.scorePercentage, 100)
    }

    func testEntryWithEmptyDetails() {
        let entry = BenchmarkEntry(label: "Simple", score: 0.5, details: [:])
        XCTAssertTrue(entry.details.isEmpty)
    }

    // MARK: - AnalyticsTimeRange Edge Cases

    func testLast30DaysInterval() {
        guard let interval = AnalyticsTimeRange.last30Days.dateInterval else {
            XCTFail("last30Days should have a dateInterval")
            return
        }
        XCTAssertEqual(interval.duration, 2592000, accuracy: 1.0)
    }

    func testLast90DaysInterval() {
        guard let interval = AnalyticsTimeRange.last90Days.dateInterval else {
            XCTFail("last90Days should have a dateInterval")
            return
        }
        XCTAssertEqual(interval.duration, 7776000, accuracy: 1.0)
    }

    // MARK: - CostOptimizationTip Edge Cases

    func testTipFormattedSavingsZero() {
        let tip = CostOptimizationTip(category: .caching, title: "Free", description: "No savings", estimatedSavings: 0.0, impact: .low)
        XCTAssertEqual(tip.formattedSavings, "$0.00/mo")
    }

    func testTipFormattedSavingsLargeAmount() {
        let tip = CostOptimizationTip(category: .modelSelection, title: "Big", description: "Big savings", estimatedSavings: 9999.99, impact: .high)
        XCTAssertEqual(tip.formattedSavings, "$9999.99/mo")
    }

    func testAllImpactLevelsHaveDisplayName() {
        for impact in CostOptimizationTip.OptimizationImpact.allCases {
            XCTAssertFalse(impact.displayName.isEmpty)
        }
    }

    // MARK: - DashboardReport Edge Cases

    func testReportUniqueIDs() {
        let report1 = DashboardReport(name: "A")
        let report2 = DashboardReport(name: "A")
        XCTAssertNotEqual(report1.id, report2.id)
    }

    func testReportWithEmptyName() {
        let report = DashboardReport(name: "")
        XCTAssertEqual(report.name, "")
        XCTAssertFalse(report.id.isEmpty)
    }

    // MARK: - ReportWidget Hashable

    func testWidgetHashableAndIdentifiable() {
        let w1 = ReportWidget(type: .lineChart, title: "A", dataSource: .tokenUsage)
        let w2 = ReportWidget(type: .lineChart, title: "A", dataSource: .tokenUsage)
        // Different IDs should produce different hashes
        XCTAssertNotEqual(w1.id, w2.id)
        XCTAssertNotEqual(w1.hashValue, w2.hashValue)
    }

    // MARK: - AnalyticsDataPoint Edge Cases

    func testDataPointNegativeValue() {
        let point = AnalyticsDataPoint(timestamp: Date(), value: -5.0)
        XCTAssertEqual(point.value, -5.0)
    }

    func testDataPointZeroValue() {
        let point = AnalyticsDataPoint(timestamp: Date(), value: 0.0)
        XCTAssertEqual(point.value, 0.0)
    }

    func testDataPointVeryLargeValue() {
        let point = AnalyticsDataPoint(timestamp: Date(), value: 1_000_000_000.0)
        XCTAssertEqual(point.value, 1_000_000_000.0)
    }

    // MARK: - ForecastMetric Specific Values

    func testErrorRateMetricUnit() {
        XCTAssertEqual(ForecastMetric.errorRate.unit, "%")
    }

    func testResponseTimeMetricUnit() {
        XCTAssertEqual(ForecastMetric.responseTime.unit, "ms")
    }

    func testTaskCountMetricUnit() {
        XCTAssertEqual(ForecastMetric.taskCount.unit, "tasks")
    }
}
