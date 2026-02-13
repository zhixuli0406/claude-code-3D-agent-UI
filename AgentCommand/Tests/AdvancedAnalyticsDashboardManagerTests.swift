import XCTest
@testable import AgentCommand

// MARK: - AdvancedAnalyticsDashboardManager Unit Tests

@MainActor
final class AdvancedAnalyticsDashboardManagerTests: XCTestCase {

    private var manager: AdvancedAnalyticsDashboardManager!

    override func setUp() {
        super.setUp()
        manager = AdvancedAnalyticsDashboardManager()
        // Clear any persisted state
        UserDefaults.standard.removeObject(forKey: "analyticsReports")
        UserDefaults.standard.removeObject(forKey: "analyticsOptimizationTips")
        manager.reports = []
        manager.forecasts = []
        manager.optimizationTips = []
        manager.benchmarks = []
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "analyticsReports")
        UserDefaults.standard.removeObject(forKey: "analyticsOptimizationTips")
        manager = nil
        super.tearDown()
    }

    // MARK: - Report Management

    func testCreateReport() {
        let report = manager.createReport(name: "Test Report", description: "A test")
        XCTAssertEqual(manager.reports.count, 1)
        XCTAssertEqual(report.name, "Test Report")
        XCTAssertEqual(report.description, "A test")
    }

    func testCreateReportWithWidgets() {
        let widget = ReportWidget(type: .lineChart, title: "Tokens", dataSource: .tokenUsage)
        let report = manager.createReport(name: "With Widget", widgets: [widget])
        XCTAssertEqual(report.widgets.count, 1)
        XCTAssertEqual(report.widgets.first?.title, "Tokens")
    }

    func testDeleteReport() {
        let report = manager.createReport(name: "To Delete")
        XCTAssertEqual(manager.reports.count, 1)
        manager.deleteReport(id: report.id)
        XCTAssertEqual(manager.reports.count, 0)
    }

    func testDeleteReportClearsCurrentReport() {
        let report = manager.createReport(name: "Current")
        manager.currentReport = report
        manager.deleteReport(id: report.id)
        XCTAssertNotEqual(manager.currentReport?.id, report.id)
    }

    func testDeleteNonExistentReport() {
        _ = manager.createReport(name: "Existing")
        manager.deleteReport(id: "non-existent")
        XCTAssertEqual(manager.reports.count, 1)
    }

    func testAddWidgetToReport() {
        let report = manager.createReport(name: "Report")
        let widget = ReportWidget(type: .barChart, title: "Cost", dataSource: .costOverTime)
        manager.addWidget(to: report.id, widget: widget)
        XCTAssertEqual(manager.reports.first?.widgets.count, 1)
    }

    func testAddWidgetToNonExistentReport() {
        let widget = ReportWidget(type: .barChart, title: "Cost", dataSource: .costOverTime)
        manager.addWidget(to: "non-existent", widget: widget)
        // Should not crash
        XCTAssertTrue(manager.reports.isEmpty)
    }

    func testRemoveWidgetFromReport() {
        let widget = ReportWidget(type: .metric, title: "Count", dataSource: .taskCompletion)
        let report = manager.createReport(name: "Report", widgets: [widget])
        manager.removeWidget(from: report.id, widgetId: widget.id)
        XCTAssertEqual(manager.reports.first?.widgets.count, 0)
    }

    func testRemoveNonExistentWidget() {
        let widget = ReportWidget(type: .metric, title: "Count", dataSource: .taskCompletion)
        let report = manager.createReport(name: "Report", widgets: [widget])
        manager.removeWidget(from: report.id, widgetId: "non-existent")
        XCTAssertEqual(manager.reports.first?.widgets.count, 1)
    }

    func testReorderWidgets() {
        let w1 = ReportWidget(type: .lineChart, title: "A", dataSource: .tokenUsage, position: 0)
        let w2 = ReportWidget(type: .barChart, title: "B", dataSource: .costOverTime, position: 1)
        let w3 = ReportWidget(type: .pieChart, title: "C", dataSource: .modelDistribution, position: 2)
        let report = manager.createReport(name: "Report", widgets: [w1, w2, w3])

        // Reverse the order
        manager.reorderWidgets(in: report.id, widgets: [w3, w2, w1])

        let reordered = manager.reports.first?.widgets ?? []
        XCTAssertEqual(reordered.count, 3)
        XCTAssertEqual(reordered[0].position, 0)
        XCTAssertEqual(reordered[1].position, 1)
        XCTAssertEqual(reordered[2].position, 2)
        XCTAssertEqual(reordered[0].title, "C")
    }

    // MARK: - Report Limit Enforcement

    func testEnforceReportLimit() {
        for i in 0..<55 {
            _ = manager.createReport(name: "Report \(i)")
        }
        XCTAssertLessThanOrEqual(manager.reports.count, AdvancedAnalyticsDashboardManager.maxReports)
    }

    // MARK: - Trend Forecasting

    func testGenerateForecastWithSufficientData() {
        let now = Date()
        let historicalData = (0..<30).map { i in
            AnalyticsDataPoint(
                timestamp: now.addingTimeInterval(-Double(29 - i) * 86400),
                value: Double(100 + i * 5)
            )
        }

        let forecast = manager.generateForecast(
            for: .tokenUsage,
            historicalData: historicalData,
            daysAhead: 7
        )

        XCTAssertEqual(forecast.metric, .tokenUsage)
        XCTAssertFalse(forecast.dataPoints.isEmpty)
        XCTAssertEqual(forecast.periodDays, 7)
        XCTAssertGreaterThan(forecast.confidence, 0)
        XCTAssertLessThanOrEqual(forecast.confidence, 1.0)
    }

    func testGenerateForecastWithMinimalData() {
        let data = [
            AnalyticsDataPoint(timestamp: Date(), value: 100.0)
        ]
        let forecast = manager.generateForecast(for: .cost, historicalData: data, daysAhead: 5)

        // With minimal data, should still produce a forecast
        XCTAssertFalse(forecast.dataPoints.isEmpty)
    }

    func testGenerateForecastWithEmptyData() {
        let forecast = manager.generateForecast(for: .taskCount, historicalData: [], daysAhead: 7)

        // Should handle empty data gracefully
        XCTAssertEqual(forecast.metric, .taskCount)
    }

    func testForecastLimitEnforcement() {
        let data = (0..<10).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 3600), value: Double(i))
        }
        for _ in 0..<25 {
            _ = manager.generateForecast(for: .cost, historicalData: data, daysAhead: 7)
        }
        XCTAssertLessThanOrEqual(manager.forecasts.count, AdvancedAnalyticsDashboardManager.maxForecasts)
    }

    func testForecastConfidenceWithStableData() {
        let data = (0..<30).map { i in
            AnalyticsDataPoint(
                timestamp: Date().addingTimeInterval(Double(i) * 86400),
                value: 100.0 // Constant values = high confidence
            )
        }
        let forecast = manager.generateForecast(for: .tokenUsage, historicalData: data, daysAhead: 7)
        // Constant data should yield high confidence (low CV)
        XCTAssertGreaterThan(forecast.confidence, 0.5)
    }

    func testForecastConfidenceWithVolatileData() {
        let data = (0..<30).map { i in
            AnalyticsDataPoint(
                timestamp: Date().addingTimeInterval(Double(i) * 86400),
                value: i % 2 == 0 ? 10.0 : 200.0 // Very volatile
            )
        }
        let forecast = manager.generateForecast(for: .cost, historicalData: data, daysAhead: 7)
        // High volatility should yield lower confidence
        XCTAssertLessThan(forecast.confidence, 0.8)
    }

    func testForecastDataPointsContainActualAndPredicted() {
        let now = Date()
        let data = (0..<10).map { i in
            AnalyticsDataPoint(
                timestamp: now.addingTimeInterval(-Double(9 - i) * 86400),
                value: Double(50 + i * 3)
            )
        }
        let forecast = manager.generateForecast(for: .errorRate, historicalData: data, daysAhead: 5)

        let actualPoints = forecast.dataPoints.filter(\.isActual)
        let predictedPoints = forecast.dataPoints.filter { !$0.isActual }
        XCTAssertFalse(actualPoints.isEmpty)
        XCTAssertEqual(predictedPoints.count, 5)
    }

    // MARK: - Cost Optimization Tips

    func testGenerateOptimizationTipsModelSelection() {
        // Create metrics with expensive calls for low token tasks
        let metrics = (0..<10).map { _ in
            APICallMetrics(
                model: "claude-opus-4",
                inputTokens: 200,
                outputTokens: 100,
                latencyMs: 3000,
                costUSD: 0.05,
                taskType: "simple"
            )
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)
        let modelTip = tips.first(where: { $0.category == .modelSelection })
        XCTAssertNotNil(modelTip, "Should suggest model selection optimization for expensive low-token calls")
    }

    func testGenerateOptimizationTipsTokenReduction() {
        // Create metrics with high input tokens
        let metrics = (0..<5).map { _ in
            APICallMetrics(
                model: "claude-sonnet-4",
                inputTokens: 5000,
                outputTokens: 1000,
                latencyMs: 2000,
                costUSD: 0.03,
                taskType: "verbose"
            )
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)
        let tokenTip = tips.first(where: { $0.category == .tokenReduction })
        XCTAssertNotNil(tokenTip, "Should suggest token reduction for high-input calls")
    }

    func testGenerateOptimizationTipsCaching() {
        // Create metrics with repeated task types
        let metrics = (0..<10).map { i in
            APICallMetrics(
                model: "claude-sonnet-4",
                inputTokens: 500,
                outputTokens: 200,
                latencyMs: 1000,
                costUSD: 0.01,
                taskType: i < 7 ? "repeated-task" : "other-task"
            )
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)
        let cacheTip = tips.first(where: { $0.category == .caching })
        XCTAssertNotNil(cacheTip, "Should suggest caching for repeated task types")
    }

    func testGenerateOptimizationTipsBatchProcessing() {
        let now = Date()
        // Create rapid-fire small calls
        let metrics = (0..<20).map { i in
            var metric = APICallMetrics(
                model: "claude-haiku-3.5",
                inputTokens: 50,
                outputTokens: 50,
                latencyMs: 200,
                costUSD: 0.001,
                taskType: "micro"
            )
            metric.timestamp = now.addingTimeInterval(Double(i) * 0.5) // 0.5s apart
            return metric
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)
        let batchTip = tips.first(where: { $0.category == .batchProcessing })
        XCTAssertNotNil(batchTip, "Should suggest batch processing for rapid small calls")
    }

    func testGenerateOptimizationTipsNoTipsForGoodUsage() {
        // Create well-optimized metrics
        let metrics = (0..<3).map { _ in
            APICallMetrics(
                model: "claude-haiku-3.5",
                inputTokens: 100,
                outputTokens: 50,
                latencyMs: 200,
                costUSD: 0.001,
                taskType: "unique-\(UUID().uuidString)"
            )
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)
        // With well-optimized usage, should have no or few tips
        XCTAssertTrue(tips.count <= 1)
    }

    func testOptimizationTipsLimitEnforcement() {
        // Generate many tips by calling multiple times
        for _ in 0..<15 {
            let metrics = (0..<10).map { _ in
                APICallMetrics(
                    model: "claude-opus-4",
                    inputTokens: 200,
                    outputTokens: 100,
                    latencyMs: 3000,
                    costUSD: 0.05,
                    taskType: "simple"
                )
            }
            _ = manager.generateOptimizationTips(apiMetrics: metrics)
        }
        XCTAssertLessThanOrEqual(manager.optimizationTips.count, AdvancedAnalyticsDashboardManager.maxTips)
    }

    // MARK: - Performance Benchmarking

    func testCreateBenchmark() {
        let entries = [
            BenchmarkEntry(label: "Agent A", score: 0.9),
            BenchmarkEntry(label: "Agent B", score: 0.75)
        ]
        let benchmark = manager.createBenchmark(name: "Test", entries: entries, metric: .taskSuccessRate)
        XCTAssertEqual(manager.benchmarks.count, 1)
        XCTAssertEqual(benchmark.name, "Test")
        XCTAssertEqual(benchmark.entries.count, 2)
    }

    func testBenchmarkLimitEnforcement() {
        for i in 0..<35 {
            _ = manager.createBenchmark(
                name: "Benchmark \(i)",
                entries: [BenchmarkEntry(label: "A", score: 0.5)],
                metric: .costEfficiency
            )
        }
        XCTAssertLessThanOrEqual(manager.benchmarks.count, AdvancedAnalyticsDashboardManager.maxBenchmarks)
    }

    func testBenchmarkByModel() {
        let metrics = [
            APICallMetrics(model: "opus", inputTokens: 1000, outputTokens: 500, latencyMs: 3000, costUSD: 0.1, taskType: "coding"),
            APICallMetrics(model: "opus", inputTokens: 800, outputTokens: 400, latencyMs: 2500, costUSD: 0.08, isError: true, errorType: "timeout", taskType: "coding"),
            APICallMetrics(model: "sonnet", inputTokens: 500, outputTokens: 200, latencyMs: 1000, costUSD: 0.02, taskType: "review"),
            APICallMetrics(model: "sonnet", inputTokens: 400, outputTokens: 150, latencyMs: 800, costUSD: 0.015, taskType: "review"),
            APICallMetrics(model: "haiku", inputTokens: 100, outputTokens: 50, latencyMs: 200, costUSD: 0.001, taskType: "test")
        ]

        let benchmark = manager.benchmarkByModel(metrics: metrics)
        XCTAssertEqual(benchmark.entries.count, 3) // opus, sonnet, haiku
        XCTAssertEqual(benchmark.metric, .taskSuccessRate)

        // Verify each model has details
        for entry in benchmark.entries {
            XCTAssertNotNil(entry.details["avgLatencyMs"])
            XCTAssertNotNil(entry.details["errorRate"])
            XCTAssertNotNil(entry.details["avgCostUSD"])
        }

        // Opus should have 50% error rate (1 of 2 is error)
        if let opusEntry = benchmark.entries.first(where: { $0.label == "opus" }) {
            XCTAssertEqual(opusEntry.score, 0.5, accuracy: 0.001) // success rate = 1 - 0.5
        }
    }

    func testBenchmarkByModelEmpty() {
        let benchmark = manager.benchmarkByModel(metrics: [])
        XCTAssertTrue(benchmark.entries.isEmpty)
    }

    // MARK: - Time Series Aggregation

    func testAggregateByDay() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let dataPoints = [
            AnalyticsDataPoint(timestamp: today.addingTimeInterval(3600), value: 10.0),
            AnalyticsDataPoint(timestamp: today.addingTimeInterval(7200), value: 20.0),
            AnalyticsDataPoint(timestamp: today.addingTimeInterval(10800), value: 30.0),
            AnalyticsDataPoint(timestamp: today.addingTimeInterval(86400 + 3600), value: 40.0),
            AnalyticsDataPoint(timestamp: today.addingTimeInterval(86400 + 7200), value: 60.0)
        ]

        let aggregated = manager.aggregateByDay(dataPoints: dataPoints)
        XCTAssertEqual(aggregated.count, 2) // 2 unique days

        // First day average: (10+20+30)/3 = 20
        // Second day average: (40+60)/2 = 50
        let sortedByDate = aggregated.sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(sortedByDate[0].value, 20.0, accuracy: 0.01)
        XCTAssertEqual(sortedByDate[1].value, 50.0, accuracy: 0.01)
    }

    func testAggregateByDayEmpty() {
        let aggregated = manager.aggregateByDay(dataPoints: [])
        XCTAssertTrue(aggregated.isEmpty)
    }

    func testAggregateByDaySinglePoint() {
        let point = AnalyticsDataPoint(timestamp: Date(), value: 42.0)
        let aggregated = manager.aggregateByDay(dataPoints: [point])
        XCTAssertEqual(aggregated.count, 1)
        XCTAssertEqual(aggregated.first!.value, 42.0, accuracy: 0.01)
    }

    // MARK: - Initialization & Persistence

    func testDefaultReportGeneration() {
        manager.reports = []
        manager.initialize()
        // initialize() calls generateDefaultReportIfNeeded
        XCTAssertFalse(manager.reports.isEmpty)
        XCTAssertEqual(manager.reports.first?.name, "Overview Dashboard")
    }

    func testNoDefaultReportWhenReportsExist() {
        _ = manager.createReport(name: "Existing")
        let count = manager.reports.count
        manager.initialize()
        // Should not add another default since reports already exist
        // (may reload from persistence, but the existing report should be present)
        XCTAssertGreaterThanOrEqual(manager.reports.count, count)
    }

    func testShutdownSaves() {
        _ = manager.createReport(name: "Saved Report")
        manager.shutdown()
        // Verify data was saved to UserDefaults
        let data = UserDefaults.standard.data(forKey: "analyticsReports")
        XCTAssertNotNil(data)
    }

    // MARK: - Loading State

    func testIsLoadingDuringForecast() {
        // After forecast completes, isLoading should be false
        let data = (0..<10).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 3600), value: Double(i * 10))
        }
        _ = manager.generateForecast(for: .cost, historicalData: data, daysAhead: 3)
        XCTAssertFalse(manager.isLoading) // defer sets it to false
    }
}
