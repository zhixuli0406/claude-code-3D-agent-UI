import XCTest
@testable import AgentCommand

// MARK: - M-Series Integration Tests
//
// These tests verify cross-module interactions between M-series features:
// - M1 (Analytics Dashboard) ↔ M3 (API Usage Analytics)
// - M2 (Report Export) ↔ M1 (Analytics Dashboard)
// - M3 (Budget Alert) ↔ M3 (Usage Forecast)

// MARK: - Analytics Dashboard Integration

final class AnalyticsDashboardIntegrationTests: XCTestCase {

    // MARK: - Report + Widget Pipeline

    func testReportWithMultipleWidgetTypes() {
        let widgets = ReportWidget.WidgetType.allCases.enumerated().map { index, type in
            ReportWidget(type: type, title: "Widget \(index)", dataSource: .tokenUsage, position: index)
        }
        let report = DashboardReport(name: "Full Dashboard", widgets: widgets)
        XCTAssertEqual(report.widgets.count, ReportWidget.WidgetType.allCases.count)
        for (i, widget) in report.widgets.enumerated() {
            XCTAssertEqual(widget.position, i)
        }
    }

    func testReportWidgetDataSourceCoverage() {
        let widgets = ReportWidget.WidgetDataSource.allCases.map { source in
            ReportWidget(type: .lineChart, title: source.displayName, dataSource: source)
        }
        let report = DashboardReport(name: "Data Sources", widgets: widgets)
        XCTAssertEqual(report.widgets.count, ReportWidget.WidgetDataSource.allCases.count)
    }

    // MARK: - Forecast + Data Points

    func testForecastDataPointConsistency() {
        let now = Date()
        let historical = (0..<7).map { day in
            ForecastDataPoint(
                date: now.addingTimeInterval(-Double(6 - day) * 86400),
                value: Double(100 + day * 10),
                lowerBound: Double(100 + day * 10),
                upperBound: Double(100 + day * 10),
                isActual: true
            )
        }
        let predicted = (0..<7).map { day in
            ForecastDataPoint(
                date: now.addingTimeInterval(Double(day + 1) * 86400),
                value: 170.0,
                lowerBound: 150.0,
                upperBound: 190.0,
                isActual: false
            )
        }
        let allPoints = historical + predicted

        let forecast = TrendForecast(metric: .tokenUsage, dataPoints: allPoints, confidence: 0.85, periodDays: 7)
        XCTAssertEqual(forecast.dataPoints.count, 14)

        let actualPoints = forecast.dataPoints.filter(\.isActual)
        let forecastPoints = forecast.dataPoints.filter { !$0.isActual }
        XCTAssertEqual(actualPoints.count, 7)
        XCTAssertEqual(forecastPoints.count, 7)

        // Predicted points should have uncertainty bounds wider than the value
        for point in forecastPoints {
            XCTAssertLessThanOrEqual(point.lowerBound, point.value)
            XCTAssertGreaterThanOrEqual(point.upperBound, point.value)
        }
    }

    // MARK: - Benchmark Entry Sorting

    func testBenchmarkEntriesSortByScore() {
        let entries = [
            BenchmarkEntry(label: "Low", score: 0.3),
            BenchmarkEntry(label: "High", score: 0.95),
            BenchmarkEntry(label: "Mid", score: 0.6)
        ]
        let sorted = entries.sorted { $0.score > $1.score }
        XCTAssertEqual(sorted[0].label, "High")
        XCTAssertEqual(sorted[1].label, "Mid")
        XCTAssertEqual(sorted[2].label, "Low")
    }

    func testBenchmarkWithDetails() {
        let entry = BenchmarkEntry(
            label: "Agent X",
            score: 0.85,
            details: ["avgLatencyMs": 500.0, "errorRate": 0.05, "costPerTask": 0.02]
        )
        XCTAssertEqual(entry.details.count, 3)
        XCTAssertEqual(entry.details["avgLatencyMs"], 500.0)
    }
}

// MARK: - Report Export Integration

final class ReportExportIntegrationTests: XCTestCase {

    // MARK: - Template + Section Pipeline

    func testDefaultTemplateHasAllSections() {
        let template = ReportTemplate.defaultTemplate
        let allTypes = Set(ReportSection.SectionType.allCases)
        let templateTypes = Set(template.sections.map(\.type))
        XCTAssertEqual(allTypes, templateTypes)
    }

    func testScheduleWithTemplate() {
        let template = ReportTemplate(name: "Weekly")
        let schedule = ReportSchedule(
            name: "Auto Weekly",
            templateId: template.id,
            frequency: .weekly,
            exportFormat: .pdf
        )
        XCTAssertEqual(schedule.templateId, template.id)
        XCTAssertNotNil(schedule.nextRunAt)
    }

    // MARK: - Export Job Lifecycle

    func testExportJobLifecycle() {
        var job = ExportJob(format: .csv)
        XCTAssertEqual(job.status, .pending)
        XCTAssertEqual(job.progress, 0)

        // Simulate progress
        job.status = .inProgress
        job.progress = 0.5
        XCTAssertEqual(job.progressPercentage, 50)

        // Simulate completion
        job.status = .completed
        job.progress = 1.0
        job.completedAt = job.startedAt.addingTimeInterval(2.0)
        job.outputPath = "/tmp/report.csv"
        job.fileSize = 4096

        XCTAssertEqual(job.progressPercentage, 100)
        XCTAssertNotNil(job.duration)
        XCTAssertNotNil(job.formattedFileSize)
        XCTAssertEqual(job.outputPath, "/tmp/report.csv")
    }

    func testExportJobFailure() {
        var job = ExportJob(format: .json)
        job.status = .failed
        job.errorMessage = "Disk full"

        XCTAssertEqual(job.status, .failed)
        XCTAssertEqual(job.errorMessage, "Disk full")
        XCTAssertNil(job.outputPath)
    }

    // MARK: - Report Data Consistency

    func testReportDataCodableRoundTrip() throws {
        let summary = ReportSummary(
            totalTokens: 50000,
            totalCost: 12.50,
            totalTasks: 100,
            successRate: 0.95,
            averageLatency: 350.0,
            periodDescription: "Last 7 days"
        )
        let taskMetrics = ReportTaskMetrics(completed: 90, failed: 5, cancelled: 5, averageDuration: 25.0)
        let errorMetrics = ReportErrorMetrics(
            totalErrors: 8,
            errorsByType: ["timeout": 5, "rate_limit": 3],
            recoveryRate: 0.75,
            mostCommonError: "timeout"
        )

        let report = ReportData(
            title: "Test Report",
            timeRange: "Weekly",
            summary: summary,
            tokenUsageData: [
                AnalyticsDataPoint(timestamp: Date(), value: 5000),
                AnalyticsDataPoint(timestamp: Date().addingTimeInterval(86400), value: 7000)
            ],
            costData: [
                AnalyticsDataPoint(timestamp: Date(), value: 1.50)
            ],
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(report)
        let decoded = try JSONDecoder().decode(ReportData.self, from: data)

        XCTAssertEqual(decoded.title, "Test Report")
        XCTAssertEqual(decoded.summary.totalTokens, 50000)
        XCTAssertEqual(decoded.summary.totalCost, 12.50)
        XCTAssertEqual(decoded.taskMetrics.completed, 90)
        XCTAssertEqual(decoded.errorMetrics.totalErrors, 8)
        XCTAssertEqual(decoded.tokenUsageData.count, 2)
        XCTAssertEqual(decoded.costData.count, 1)
    }
}

// MARK: - API Usage Analytics Integration

final class APIUsageAnalyticsIntegrationTests: XCTestCase {

    // MARK: - Cost Breakdown Calculation

    func testCostBreakdownPercentagesSum() {
        let entries = [
            CostBreakdownEntry(category: "opus", cost: 50.0, tokenCount: 100000, callCount: 200, totalCost: 100.0),
            CostBreakdownEntry(category: "sonnet", cost: 30.0, tokenCount: 80000, callCount: 300, totalCost: 100.0),
            CostBreakdownEntry(category: "haiku", cost: 20.0, tokenCount: 50000, callCount: 500, totalCost: 100.0)
        ]
        let breakdown = CostBreakdown(entries: entries, period: "Monthly")

        let totalPercentage = breakdown.entries.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 1.0, accuracy: 0.01)
    }

    func testCostBreakdownEntrySorted() {
        let entries = [
            CostBreakdownEntry(category: "cheap", cost: 5.0, tokenCount: 1000, callCount: 10, totalCost: 100.0),
            CostBreakdownEntry(category: "expensive", cost: 80.0, tokenCount: 50000, callCount: 100, totalCost: 100.0),
            CostBreakdownEntry(category: "mid", cost: 15.0, tokenCount: 5000, callCount: 30, totalCost: 100.0)
        ]
        let sorted = entries.sorted { $0.cost > $1.cost }
        XCTAssertEqual(sorted[0].category, "expensive")
        XCTAssertEqual(sorted[1].category, "mid")
        XCTAssertEqual(sorted[2].category, "cheap")
    }

    // MARK: - Budget + Spend Tracking

    func testBudgetAlertProgressionThroughLevels() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)

        // Start: normal
        alert.currentSpend = 50.0
        XCTAssertEqual(alert.alertLevel, .normal)

        // Cross warning threshold (80%)
        alert.currentSpend = 85.0
        XCTAssertEqual(alert.alertLevel, .warning)

        // Cross critical threshold (90%)
        alert.currentSpend = 95.0
        XCTAssertEqual(alert.alertLevel, .critical)

        // Over budget
        alert.currentSpend = 110.0
        XCTAssertEqual(alert.alertLevel, .critical)
        XCTAssertEqual(alert.remainingBudget, 0)
    }

    func testBudgetAlertCustomThreshold() {
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.5)

        alert.currentSpend = 55.0
        XCTAssertEqual(alert.alertLevel, .warning)

        alert.currentSpend = 45.0
        XCTAssertEqual(alert.alertLevel, .normal)
    }

    // MARK: - Usage Forecast Trends

    func testForecastWithDataPoints() {
        let now = Date()
        let actual = (0..<5).map { i in
            ForecastDataPoint(
                date: now.addingTimeInterval(Double(-4 + i) * 86400),
                value: Double(3 + i),
                lowerBound: Double(3 + i),
                upperBound: Double(3 + i),
                isActual: true
            )
        }
        let predicted = (0..<5).map { i in
            ForecastDataPoint(
                date: now.addingTimeInterval(Double(i + 1) * 86400),
                value: 8.0,
                lowerBound: 6.0,
                upperBound: 10.0,
                isActual: false
            )
        }

        let forecast = UsageForecast(
            forecastedMonthEndCost: 200.0,
            forecastedMonthEndTokens: 400000,
            dailyAverage: 6.67,
            trend: .increasing,
            dataPoints: actual + predicted
        )

        XCTAssertEqual(forecast.dataPoints.count, 10)
        XCTAssertEqual(forecast.trend, .increasing)
        XCTAssertEqual(forecast.formattedForecastCost, "$200.00")
    }

    // MARK: - Model Statistics Comparison

    func testModelStatsComparison() {
        let opusStats = ModelUsageStats(
            modelName: "opus",
            totalCalls: 50,
            totalTokens: 100000,
            totalCost: 50.0,
            averageLatencyMs: 3000,
            errorRate: 0.02
        )
        let sonnetStats = ModelUsageStats(
            modelName: "sonnet",
            totalCalls: 200,
            totalTokens: 200000,
            totalCost: 20.0,
            averageLatencyMs: 1500,
            errorRate: 0.05
        )

        // Opus is more expensive per call
        XCTAssertGreaterThan(opusStats.costPerCall, sonnetStats.costPerCall)

        // Sonnet handles more calls
        XCTAssertGreaterThan(sonnetStats.totalCalls, opusStats.totalCalls)

        // Opus has lower error rate
        XCTAssertLessThan(opusStats.errorRate, sonnetStats.errorRate)
    }

    // MARK: - API Metrics Aggregation

    func testMetricsAggregation() {
        let metrics = [
            APICallMetrics(model: "opus", inputTokens: 1000, outputTokens: 500, latencyMs: 2000, costUSD: 0.05, taskType: "coding"),
            APICallMetrics(model: "opus", inputTokens: 2000, outputTokens: 1000, latencyMs: 3000, costUSD: 0.10, taskType: "coding"),
            APICallMetrics(model: "sonnet", inputTokens: 500, outputTokens: 200, latencyMs: 800, costUSD: 0.01, taskType: "review"),
            APICallMetrics(model: "sonnet", inputTokens: 300, outputTokens: 100, latencyMs: 600, costUSD: 0.005, isError: true, errorType: "timeout", taskType: "review")
        ]

        let totalTokens = metrics.reduce(0) { $0 + $1.totalTokens }
        XCTAssertEqual(totalTokens, 5600)

        let totalCost = metrics.reduce(0.0) { $0 + $1.costUSD }
        XCTAssertEqual(totalCost, 0.165, accuracy: 0.001)

        let errorCount = metrics.filter(\.isError).count
        XCTAssertEqual(errorCount, 1)

        let uniqueModels = Set(metrics.map(\.model)).count
        XCTAssertEqual(uniqueModels, 2)
    }

    // MARK: - Cross-Module: Analytics + Export Data

    func testAnalyticsDataPointsForExport() {
        let points = (0..<10).map { i in
            AnalyticsDataPoint(
                timestamp: Date().addingTimeInterval(Double(i) * 3600),
                value: Double(i * 100),
                label: "Hour \(i)"
            )
        }

        // Verify data is suitable for charting
        for i in 1..<points.count {
            XCTAssertGreaterThan(points[i].timestamp, points[i - 1].timestamp, "Data points should be chronologically ordered")
        }

        // Verify data can be encoded for export
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        XCTAssertNoThrow(try encoder.encode(points))
    }
}

// MARK: - Service-Level Integration Tests

@MainActor
final class ServiceLevelIntegrationTests: XCTestCase {

    // MARK: - AdvancedAnalyticsDashboardManager + APICallMetrics Integration

    func testOptimizationTipsFromRealisticMetrics() {
        let manager = AdvancedAnalyticsDashboardManager()
        manager.reports = []
        manager.optimizationTips = []

        // Create realistic mixed API call patterns
        var metrics: [APICallMetrics] = []

        // Expensive calls with low tokens (model selection opportunity)
        for _ in 0..<8 {
            metrics.append(APICallMetrics(
                model: "claude-opus-4", inputTokens: 150, outputTokens: 100,
                latencyMs: 3000, costUSD: 0.05, taskType: "classification"
            ))
        }

        // High token calls (token reduction opportunity)
        for _ in 0..<5 {
            metrics.append(APICallMetrics(
                model: "claude-sonnet-4", inputTokens: 5000, outputTokens: 2000,
                latencyMs: 2000, costUSD: 0.03, taskType: "code-generation"
            ))
        }

        // Repeated task types (caching opportunity)
        for _ in 0..<8 {
            metrics.append(APICallMetrics(
                model: "claude-haiku-3.5", inputTokens: 200, outputTokens: 100,
                latencyMs: 300, costUSD: 0.002, taskType: "format-check"
            ))
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)

        // Should detect multiple optimization opportunities
        XCTAssertGreaterThanOrEqual(tips.count, 2, "Should find at least 2 optimization opportunities")

        // Verify all tips have valid savings
        for tip in tips {
            XCTAssertGreaterThan(tip.estimatedSavings, 0)
            XCTAssertFalse(tip.title.isEmpty)
            XCTAssertFalse(tip.description.isEmpty)
        }
    }

    func testBenchmarkByModelWithMixedErrorRates() {
        let manager = AdvancedAnalyticsDashboardManager()
        manager.benchmarks = []

        // Create metrics with varying error rates per model
        var metrics: [APICallMetrics] = []

        // Opus: 0% error rate
        for _ in 0..<5 {
            metrics.append(APICallMetrics(
                model: "opus", inputTokens: 1000, outputTokens: 500,
                latencyMs: 3000, costUSD: 0.1, taskType: "coding"
            ))
        }

        // Sonnet: 50% error rate
        metrics.append(APICallMetrics(model: "sonnet", inputTokens: 500, outputTokens: 200, latencyMs: 1000, costUSD: 0.02, taskType: "review"))
        metrics.append(APICallMetrics(model: "sonnet", inputTokens: 500, outputTokens: 0, latencyMs: 30000, costUSD: 0, isError: true, errorType: "timeout", taskType: "review"))

        let benchmark = manager.benchmarkByModel(metrics: metrics)

        // Opus should have higher score (100% success) than Sonnet (50%)
        let opusEntry = benchmark.entries.first(where: { $0.label == "opus" })
        let sonnetEntry = benchmark.entries.first(where: { $0.label == "sonnet" })

        XCTAssertNotNil(opusEntry)
        XCTAssertNotNil(sonnetEntry)
        XCTAssertEqual(opusEntry!.score, 1.0, accuracy: 0.001) // 0% error = 100% success
        XCTAssertEqual(sonnetEntry!.score, 0.5, accuracy: 0.001) // 50% error = 50% success
        XCTAssertGreaterThan(opusEntry?.score ?? 0, sonnetEntry?.score ?? 0)
    }

    func testForecastWithTrendingData() {
        let manager = AdvancedAnalyticsDashboardManager()
        manager.forecasts = []
        let now = Date()

        // Create steadily increasing data
        let data = (0..<20).map { i in
            AnalyticsDataPoint(
                timestamp: now.addingTimeInterval(-Double(19 - i) * 86400),
                value: 100.0 + Double(i) * 10.0 // 100, 110, 120, ..., 290
            )
        }

        let forecast = manager.generateForecast(for: .cost, historicalData: data, daysAhead: 7)

        // With steadily increasing data, predictions should exist
        let predictedPoints = forecast.dataPoints.filter { !$0.isActual }
        XCTAssertEqual(predictedPoints.count, 7)

        // All predicted points should have uncertainty bounds that widen over time
        for i in 1..<predictedPoints.count {
            let prevRange = predictedPoints[i-1].upperBound - predictedPoints[i-1].lowerBound
            let currRange = predictedPoints[i].upperBound - predictedPoints[i].lowerBound
            XCTAssertGreaterThanOrEqual(currRange, prevRange - 0.01, "Uncertainty should widen or stay same over time")
        }
    }

    // MARK: - ReportGenerationManager + ReportData Integration

    func testReportGenerationAndFormatConversion() {
        let manager = ReportGenerationManager()
        manager.templates = []
        manager.schedules = []
        manager.exportJobs = []

        let template = manager.createTemplate(
            name: "Integration Test Report",
            sections: [
                ReportSection(type: .executiveSummary),
                ReportSection(type: .tokenUsage),
                ReportSection(type: .costAnalysis)
            ]
        )

        let summary = ReportSummary(
            totalTokens: 50000, totalCost: 12.50, totalTasks: 200,
            successRate: 0.95, averageLatency: 450.0, periodDescription: "Last 7 days"
        )
        let taskMetrics = ReportTaskMetrics(completed: 190, failed: 5, cancelled: 5, averageDuration: 25.0)
        let errorMetrics = ReportErrorMetrics(
            totalErrors: 8, errorsByType: ["timeout": 5, "rate_limit": 3],
            recoveryRate: 0.75, mostCommonError: "timeout"
        )
        let tokenData = (0..<7).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 86400), value: Double(5000 + i * 1000))
        }

        let report = manager.generateReport(
            template: template,
            summary: summary,
            tokenUsageData: tokenData,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )

        // Test JSON generation
        let json = manager.generateJSON(from: report)
        XCTAssertTrue(json.contains("Integration Test Report"))

        // Test CSV generation
        let csv = manager.generateCSV(from: report)
        XCTAssertTrue(csv.contains("50000"))
        XCTAssertTrue(csv.contains("Date,Token Usage"))

        // Test Markdown generation
        let md = manager.generateMarkdown(from: report)
        XCTAssertTrue(md.contains("# Integration Test Report"))
        XCTAssertTrue(md.contains("190"))
        XCTAssertTrue(md.contains("timeout"))

        // Clean up
        manager.shutdown()
        UserDefaults.standard.removeObject(forKey: "reportTemplates")
        UserDefaults.standard.removeObject(forKey: "reportSchedules")
    }

    func testExportJobCreationAndCompletion() {
        let manager = ReportGenerationManager()
        manager.templates = []
        manager.exportJobs = []

        let summary = ReportSummary(
            totalTokens: 1000, totalCost: 0.5, totalTasks: 10,
            successRate: 0.9, averageLatency: 300.0, periodDescription: "Test"
        )
        let taskMetrics = ReportTaskMetrics(completed: 9, failed: 1, cancelled: 0, averageDuration: 10.0)
        let errorMetrics = ReportErrorMetrics(totalErrors: 1, errorsByType: ["parse": 1], recoveryRate: 0.5, mostCommonError: "parse")

        let report = ReportData(
            title: "Export Test", timeRange: "1 day",
            summary: summary, taskMetrics: taskMetrics, errorMetrics: errorMetrics
        )

        // Export to all formats
        for format in ExportFormat.allCases {
            let job = manager.exportReport(report, format: format)
            XCTAssertEqual(job.format, format)
            // Should complete or fail (not stay pending)
            XCTAssertTrue(job.status == .completed || job.status == .failed,
                          "Export job for \(format) should be completed or failed, got \(job.status)")
        }

        // Clean up
        manager.shutdown()
        UserDefaults.standard.removeObject(forKey: "reportTemplates")
        UserDefaults.standard.removeObject(forKey: "reportSchedules")
    }

    // MARK: - APIUsageAnalyticsManager + Budget + Forecast Integration

    func testBudgetAlertIntegrationWithAPIRecording() {
        let manager = APIUsageAnalyticsManager()
        manager.setBudget(monthly: 1.0, alertThreshold: 0.5)

        // Record calls that push past budget thresholds
        manager.recordAPICall(model: "opus", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.30, taskType: "test")
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .normal) // 30%

        manager.recordAPICall(model: "opus", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.25, taskType: "test")
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .warning) // 55%

        manager.recordAPICall(model: "opus", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.40, taskType: "test")
        XCTAssertEqual(manager.budgetAlert?.alertLevel, .critical) // 95%

        // Total cost should match budget tracking
        XCTAssertEqual(manager.totalCost, 0.95, accuracy: 0.01)
        XCTAssertEqual(manager.budgetAlert?.currentSpend ?? 0, 0.95, accuracy: 0.01)

        manager.stopMonitoring()
    }

    func testCostBreakdownConsistencyWithSummary() {
        let manager = APIUsageAnalyticsManager()

        manager.recordAPICall(model: "opus", inputTokens: 1000, outputTokens: 500, latencyMs: 3000, costUSD: 0.10, taskType: "coding")
        manager.recordAPICall(model: "sonnet", inputTokens: 500, outputTokens: 200, latencyMs: 1000, costUSD: 0.02, taskType: "review")
        manager.recordAPICall(model: "haiku", inputTokens: 100, outputTokens: 50, latencyMs: 200, costUSD: 0.001, taskType: "classify")

        manager.generateCostBreakdown(period: "Test")

        // Breakdown total should match summary total
        let breakdownTotal = manager.costBreakdowns.first?.totalCost ?? 0
        XCTAssertEqual(breakdownTotal, manager.totalCost, accuracy: 0.001)
        XCTAssertEqual(breakdownTotal, manager.summary.totalCost, accuracy: 0.001)

        manager.stopMonitoring()
    }

    // MARK: - Cross-Module Data Flow: Analytics → Report → Export

    func testEndToEndDataFlow() {
        // Step 1: Create analytics data
        let apiMetrics = [
            APICallMetrics(model: "opus", inputTokens: 1000, outputTokens: 500, latencyMs: 3000, costUSD: 0.10, taskType: "coding"),
            APICallMetrics(model: "sonnet", inputTokens: 500, outputTokens: 200, latencyMs: 1000, costUSD: 0.02, taskType: "review"),
            APICallMetrics(model: "haiku", inputTokens: 100, outputTokens: 50, latencyMs: 200, costUSD: 0.001, taskType: "classify")
        ]

        let totalTokens = apiMetrics.reduce(0) { $0 + $1.totalTokens }
        let totalCost = apiMetrics.reduce(0.0) { $0 + $1.costUSD }
        let errorCount = apiMetrics.filter(\.isError).count

        // Step 2: Create report data from analytics
        let summary = ReportSummary(
            totalTokens: totalTokens,
            totalCost: totalCost,
            totalTasks: apiMetrics.count,
            successRate: Double(apiMetrics.count - errorCount) / Double(apiMetrics.count),
            averageLatency: apiMetrics.reduce(0.0) { $0 + $1.latencyMs } / Double(apiMetrics.count),
            periodDescription: "Integration Test"
        )
        let taskMetrics = ReportTaskMetrics(
            completed: apiMetrics.count - errorCount,
            failed: errorCount,
            cancelled: 0,
            averageDuration: 30.0
        )
        let errorMetrics = ReportErrorMetrics(
            totalErrors: errorCount,
            errorsByType: [:],
            recoveryRate: 0,
            mostCommonError: nil
        )

        let reportData = ReportData(
            title: "End-to-End Test",
            timeRange: "Test Period",
            summary: summary,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )

        // Step 3: Verify data consistency across layers
        XCTAssertEqual(reportData.summary.totalTokens, 2350) // 1500+700+150
        XCTAssertEqual(reportData.summary.totalCost, 0.121, accuracy: 0.001)
        XCTAssertEqual(reportData.taskMetrics.total, 3)
        XCTAssertEqual(reportData.taskMetrics.successRate, 1.0, accuracy: 0.001)

        // Step 4: Verify it can be encoded for export
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        XCTAssertNoThrow(try encoder.encode(reportData))
    }

    // MARK: - Template ↔ Schedule Relationship

    func testTemplateScheduleRelationship() {
        let manager = ReportGenerationManager()
        manager.templates = []
        manager.schedules = []

        let template1 = manager.createTemplate(name: "Daily Report", sections: [ReportSection(type: .executiveSummary)])
        let template2 = manager.createTemplate(name: "Weekly Report", sections: [ReportSection(type: .costAnalysis)])

        _ = manager.createSchedule(name: "Daily Auto", templateId: template1.id, frequency: .daily, exportFormat: .json)
        _ = manager.createSchedule(name: "Weekly Auto", templateId: template2.id, frequency: .weekly, exportFormat: .csv)

        XCTAssertEqual(manager.schedules.count, 2)

        // Delete template1 - should also remove its schedule
        manager.deleteTemplate(id: template1.id)
        XCTAssertEqual(manager.templates.count, 1)
        XCTAssertEqual(manager.schedules.count, 1)
        XCTAssertEqual(manager.schedules.first?.templateId, template2.id)

        // Clean up
        manager.shutdown()
        UserDefaults.standard.removeObject(forKey: "reportTemplates")
        UserDefaults.standard.removeObject(forKey: "reportSchedules")
    }

    // MARK: - Optimization Tips Filtering

    func testOptimizationTipsCategoryCoverage() {
        let manager = AdvancedAnalyticsDashboardManager()
        manager.optimizationTips = []

        // Create metrics that trigger ALL tip categories
        var metrics: [APICallMetrics] = []
        let now = Date()

        // Model selection: expensive calls with low tokens
        for _ in 0..<10 {
            metrics.append(APICallMetrics(
                model: "opus", inputTokens: 100, outputTokens: 50,
                latencyMs: 3000, costUSD: 0.05, taskType: "simple"
            ))
        }

        // Token reduction: high input tokens
        for _ in 0..<5 {
            metrics.append(APICallMetrics(
                model: "sonnet", inputTokens: 5000, outputTokens: 1000,
                latencyMs: 2000, costUSD: 0.03, taskType: "verbose"
            ))
        }

        // Caching: repeated task types
        for _ in 0..<8 {
            metrics.append(APICallMetrics(
                model: "haiku", inputTokens: 200, outputTokens: 100,
                latencyMs: 200, costUSD: 0.001, taskType: "repeated"
            ))
        }

        // Batch processing: rapid sequential small calls
        for i in 0..<15 {
            var metric = APICallMetrics(
                model: "haiku", inputTokens: 50, outputTokens: 30,
                latencyMs: 100, costUSD: 0.0005, taskType: "micro"
            )
            metric.timestamp = now.addingTimeInterval(Double(i) * 0.5)
            metrics.append(metric)
        }

        let tips = manager.generateOptimizationTips(apiMetrics: metrics)
        let categories = Set(tips.map(\.category))

        // Should cover multiple categories
        XCTAssertGreaterThanOrEqual(categories.count, 3,
                                     "Should detect optimization opportunities across at least 3 categories")
    }
}
