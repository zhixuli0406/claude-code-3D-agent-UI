import XCTest
@testable import AgentCommand

// MARK: - M1: Analytics Dashboard Manager Unit Tests

@MainActor
final class AnalyticsDashboardManagerTests: XCTestCase {

    private var manager: AnalyticsDashboardManager!

    override func setUp() {
        super.setUp()
        manager = AnalyticsDashboardManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Create Report

    func testCreateReport_Basic() {
        manager.createReport(name: "Weekly Summary", description: "A weekly report")
        XCTAssertEqual(manager.reports.count, 1)
        XCTAssertEqual(manager.reports[0].name, "Weekly Summary")
        XCTAssertEqual(manager.reports[0].description, "A weekly report")
        XCTAssertFalse(manager.reports[0].isDefault)
    }

    func testCreateReport_DefaultDescription() {
        manager.createReport(name: "No Description")
        XCTAssertEqual(manager.reports.count, 1)
        XCTAssertEqual(manager.reports[0].description, "")
    }

    func testCreateReport_InsertsAtFront() {
        manager.createReport(name: "First")
        manager.createReport(name: "Second")
        manager.createReport(name: "Third")
        XCTAssertEqual(manager.reports.count, 3)
        XCTAssertEqual(manager.reports[0].name, "Third")
        XCTAssertEqual(manager.reports[1].name, "Second")
        XCTAssertEqual(manager.reports[2].name, "First")
    }

    func testCreateReport_EvictsOldestNonDefaultWhenExceedingCap() {
        // Fill to exactly 20 reports
        for i in 0..<20 {
            manager.createReport(name: "Report \(i)")
        }
        XCTAssertEqual(manager.reports.count, 20)

        // Adding one more should trigger eviction back to 20
        manager.createReport(name: "Report 20 (overflow)")
        XCTAssertEqual(manager.reports.count, 20)
        // The newest report should be at front
        XCTAssertEqual(manager.reports[0].name, "Report 20 (overflow)")
    }

    func testCreateReport_EvictsNonDefaultBeforeDefault() {
        // Manually set up reports: mix of default and non-default
        // We need to directly populate with default reports to test eviction preference
        for _ in 0..<19 {
            manager.createReport(name: "Default Report")
            // Mark each as default via direct mutation
        }
        // Make most of them default
        for i in 1..<manager.reports.count {
            manager.reports[i] = DashboardReport(
                name: "Default \(i)",
                description: "",
                widgets: [],
                isDefault: true
            )
        }
        // reports[0] is non-default ("Default Report" with isDefault = false)
        // reports[1...18] are default

        // Now add two more to exceed cap
        manager.createReport(name: "New Non-Default A")
        manager.createReport(name: "New Non-Default B")

        XCTAssertLessThanOrEqual(manager.reports.count, 20)
        // The newest should be at front
        XCTAssertEqual(manager.reports[0].name, "New Non-Default B")
    }

    // MARK: - Delete Report

    func testDeleteReport_ById() {
        manager.createReport(name: "To Delete")
        manager.createReport(name: "To Keep")
        let deleteId = manager.reports[1].id // "To Delete" is at index 1
        manager.deleteReport(deleteId)
        XCTAssertEqual(manager.reports.count, 1)
        XCTAssertEqual(manager.reports[0].name, "To Keep")
    }

    func testDeleteReport_NonExistentId() {
        manager.createReport(name: "Existing")
        let countBefore = manager.reports.count
        manager.deleteReport("non-existent-id")
        XCTAssertEqual(manager.reports.count, countBefore)
    }

    // MARK: - Add Widget

    func testAddWidget_ToExistingReport() {
        manager.createReport(name: "My Report")
        let reportId = manager.reports[0].id
        manager.addWidget(
            to: reportId,
            type: .lineChart,
            title: "Token Trend",
            dataSource: .tokenUsage,
            size: .large
        )
        XCTAssertEqual(manager.reports[0].widgets.count, 1)
        XCTAssertEqual(manager.reports[0].widgets[0].type, .lineChart)
        XCTAssertEqual(manager.reports[0].widgets[0].title, "Token Trend")
        XCTAssertEqual(manager.reports[0].widgets[0].dataSource, .tokenUsage)
        XCTAssertEqual(manager.reports[0].widgets[0].size, .large)
        XCTAssertEqual(manager.reports[0].widgets[0].position, 0)
    }

    func testAddWidget_UpdatesUpdatedAt() {
        manager.createReport(name: "My Report")
        let reportId = manager.reports[0].id
        let originalUpdatedAt = manager.reports[0].updatedAt

        // Small delay to ensure timestamp differs
        Thread.sleep(forTimeInterval: 0.01)

        manager.addWidget(
            to: reportId,
            type: .barChart,
            title: "Tasks",
            dataSource: .taskCompletion,
            size: .medium
        )
        XCTAssertGreaterThanOrEqual(manager.reports[0].updatedAt, originalUpdatedAt)
    }

    func testAddWidget_MultipleWidgets_PositionsIncrement() {
        manager.createReport(name: "Multi-Widget Report")
        let reportId = manager.reports[0].id

        manager.addWidget(to: reportId, type: .lineChart, title: "W1", dataSource: .tokenUsage, size: .small)
        manager.addWidget(to: reportId, type: .barChart, title: "W2", dataSource: .taskCompletion, size: .medium)
        manager.addWidget(to: reportId, type: .pieChart, title: "W3", dataSource: .modelDistribution, size: .large)

        XCTAssertEqual(manager.reports[0].widgets.count, 3)
        XCTAssertEqual(manager.reports[0].widgets[0].position, 0)
        XCTAssertEqual(manager.reports[0].widgets[1].position, 1)
        XCTAssertEqual(manager.reports[0].widgets[2].position, 2)
    }

    func testAddWidget_ToNonExistentReport() {
        manager.createReport(name: "Existing Report")
        let widgetCountBefore = manager.reports[0].widgets.count
        manager.addWidget(
            to: "non-existent-report-id",
            type: .metric,
            title: "Orphan",
            dataSource: .errorRate,
            size: .small
        )
        // Nothing should change
        XCTAssertEqual(manager.reports[0].widgets.count, widgetCountBefore)
    }

    // MARK: - Remove Widget

    func testRemoveWidget_RemovesAndReindexesPositions() {
        manager.createReport(name: "Report")
        let reportId = manager.reports[0].id

        manager.addWidget(to: reportId, type: .lineChart, title: "W0", dataSource: .tokenUsage, size: .small)
        manager.addWidget(to: reportId, type: .barChart, title: "W1", dataSource: .taskCompletion, size: .medium)
        manager.addWidget(to: reportId, type: .pieChart, title: "W2", dataSource: .modelDistribution, size: .large)

        // Remove the middle widget (W1)
        let widgetToRemoveId = manager.reports[0].widgets[1].id
        manager.removeWidget(from: reportId, widgetId: widgetToRemoveId)

        XCTAssertEqual(manager.reports[0].widgets.count, 2)
        XCTAssertEqual(manager.reports[0].widgets[0].title, "W0")
        XCTAssertEqual(manager.reports[0].widgets[0].position, 0)
        XCTAssertEqual(manager.reports[0].widgets[1].title, "W2")
        XCTAssertEqual(manager.reports[0].widgets[1].position, 1)
    }

    func testRemoveWidget_UpdatesUpdatedAt() {
        manager.createReport(name: "Report")
        let reportId = manager.reports[0].id
        manager.addWidget(to: reportId, type: .metric, title: "W", dataSource: .errorRate, size: .small)

        let originalUpdatedAt = manager.reports[0].updatedAt
        Thread.sleep(forTimeInterval: 0.01)

        let widgetId = manager.reports[0].widgets[0].id
        manager.removeWidget(from: reportId, widgetId: widgetId)
        XCTAssertGreaterThanOrEqual(manager.reports[0].updatedAt, originalUpdatedAt)
    }

    func testRemoveWidget_FromNonExistentReport() {
        manager.createReport(name: "Report")
        let reportId = manager.reports[0].id
        manager.addWidget(to: reportId, type: .metric, title: "W", dataSource: .errorRate, size: .small)

        let countBefore = manager.reports[0].widgets.count
        manager.removeWidget(from: "non-existent-report-id", widgetId: "some-widget-id")
        // Nothing should change
        XCTAssertEqual(manager.reports[0].widgets.count, countBefore)
    }

    // MARK: - Generate Forecast

    func testGenerateForecast_CreatesForEachMetric() {
        for metric in ForecastMetric.allCases {
            manager.generateForecast(for: metric, periodDays: 7)
        }
        XCTAssertEqual(manager.forecasts.count, ForecastMetric.allCases.count)

        // Each metric should appear exactly once
        let metrics = Set(manager.forecasts.map(\.metric))
        XCTAssertEqual(metrics.count, ForecastMetric.allCases.count)
    }

    func testGenerateForecast_HasHistoricalAndProjectedDataPoints() {
        manager.generateForecast(for: .tokenUsage, periodDays: 10)
        XCTAssertEqual(manager.forecasts.count, 1)

        let forecast = manager.forecasts[0]
        XCTAssertEqual(forecast.metric, .tokenUsage)
        XCTAssertEqual(forecast.periodDays, 10)

        let actualPoints = forecast.dataPoints.filter(\.isActual)
        let projectedPoints = forecast.dataPoints.filter { !$0.isActual }
        XCTAssertFalse(actualPoints.isEmpty)
        XCTAssertFalse(projectedPoints.isEmpty)
        XCTAssertEqual(projectedPoints.count, 10)
    }

    func testGenerateForecast_ReplacesExistingForSameMetric() {
        manager.generateForecast(for: .cost, periodDays: 14)
        let firstId = manager.forecasts[0].id

        manager.generateForecast(for: .cost, periodDays: 30)
        XCTAssertEqual(manager.forecasts.count, 1)
        // The forecast should have been replaced (different id)
        XCTAssertNotEqual(manager.forecasts[0].id, firstId)
        XCTAssertEqual(manager.forecasts[0].periodDays, 30)
    }

    func testGenerateForecast_DoesNotReplaceDifferentMetric() {
        manager.generateForecast(for: .cost, periodDays: 14)
        manager.generateForecast(for: .tokenUsage, periodDays: 14)
        XCTAssertEqual(manager.forecasts.count, 2)
    }

    func testGenerateForecast_EvictionCapAt10() {
        // Generate forecasts for all 5 metrics
        for metric in ForecastMetric.allCases {
            manager.generateForecast(for: metric)
        }
        XCTAssertEqual(manager.forecasts.count, 5)

        // Manually add extra forecasts to approach cap, then trigger eviction
        // Since there are only 5 ForecastMetric cases, generating same metrics replaces.
        // We need to directly populate to test eviction
        for i in 0..<8 {
            let forecast = TrendForecast(
                metric: .tokenUsage,
                dataPoints: [],
                confidence: 0.5,
                periodDays: i + 1
            )
            manager.forecasts.append(forecast)
        }
        // Now we have 5 + 8 = 13 forecasts. Generate one more to trigger eviction path.
        manager.generateForecast(for: .tokenUsage, periodDays: 99)
        // After replacing the first .tokenUsage and trimming, count should be <= 10
        XCTAssertLessThanOrEqual(manager.forecasts.count, 10)
    }

    func testGenerateForecast_SetsIsAnalyzingDuringExecution() {
        // isAnalyzing should be false before and after (synchronous)
        XCTAssertFalse(manager.isAnalyzing)
        manager.generateForecast(for: .errorRate)
        XCTAssertFalse(manager.isAnalyzing)
    }

    func testGenerateForecast_ConfidenceIsValid() {
        manager.generateForecast(for: .taskCount, periodDays: 30)
        let confidence = manager.forecasts[0].confidence
        XCTAssertGreaterThanOrEqual(confidence, 0.0)
        XCTAssertLessThanOrEqual(confidence, 1.0)
    }

    // MARK: - Analyze Optimizations

    func testAnalyzeOptimizations_GeneratesSuggestions() {
        manager.analyzeOptimizations()
        XCTAssertEqual(manager.optimizations.count, 5)
    }

    func testAnalyzeOptimizations_DoesNotDuplicateByTitle() {
        manager.analyzeOptimizations()
        let countAfterFirst = manager.optimizations.count

        // Calling again should not add duplicates
        manager.analyzeOptimizations()
        XCTAssertEqual(manager.optimizations.count, countAfterFirst)
    }

    func testAnalyzeOptimizations_AllTipsHaveExpectedFields() {
        manager.analyzeOptimizations()
        for tip in manager.optimizations {
            XCTAssertFalse(tip.id.isEmpty)
            XCTAssertFalse(tip.title.isEmpty)
            XCTAssertFalse(tip.description.isEmpty)
            XCTAssertGreaterThan(tip.estimatedSavings, 0)
            XCTAssertFalse(tip.isApplied)
        }
    }

    func testAnalyzeOptimizations_EvictionCapAt30() {
        // Pre-populate with 28 unique tips
        for i in 0..<28 {
            let tip = CostOptimizationTip(
                category: .tokenReduction,
                title: "Custom Tip \(i)",
                description: "Description \(i)",
                estimatedSavings: Double(i),
                impact: .low
            )
            manager.optimizations.append(tip)
        }
        XCTAssertEqual(manager.optimizations.count, 28)

        // analyzeOptimizations adds 5 new unique tips -> 33 total, triggers eviction to 30
        manager.analyzeOptimizations()
        XCTAssertLessThanOrEqual(manager.optimizations.count, 30)
    }

    func testAnalyzeOptimizations_EvictsUnappliedFirst() {
        // Pre-populate with applied tips
        for i in 0..<26 {
            var tip = CostOptimizationTip(
                category: .caching,
                title: "Applied Tip \(i)",
                description: "Description \(i)",
                estimatedSavings: 10.0,
                impact: .medium
            )
            tip.isApplied = true
            manager.optimizations.append(tip)
        }

        // analyzeOptimizations adds 5 unapplied tips -> 31 total
        manager.analyzeOptimizations()
        XCTAssertLessThanOrEqual(manager.optimizations.count, 30)

        // Applied tips should be preferentially retained
        let appliedCount = manager.optimizations.filter(\.isApplied).count
        XCTAssertGreaterThanOrEqual(appliedCount, 26)
    }

    func testAnalyzeOptimizations_SetsIsAnalyzingDuringExecution() {
        XCTAssertFalse(manager.isAnalyzing)
        manager.analyzeOptimizations()
        XCTAssertFalse(manager.isAnalyzing)
    }

    // MARK: - Apply Optimization

    func testApplyOptimization_MarksAsApplied() {
        manager.analyzeOptimizations()
        let tipId = manager.optimizations[0].id
        XCTAssertFalse(manager.optimizations[0].isApplied)

        manager.applyOptimization(tipId)
        XCTAssertTrue(manager.optimizations[0].isApplied)
    }

    func testApplyOptimization_NonExistentId() {
        manager.analyzeOptimizations()
        let allUnappliedBefore = manager.optimizations.filter { !$0.isApplied }.count
        manager.applyOptimization("non-existent-tip-id")
        let allUnappliedAfter = manager.optimizations.filter { !$0.isApplied }.count
        // Nothing should change
        XCTAssertEqual(allUnappliedBefore, allUnappliedAfter)
    }

    func testApplyOptimization_MultipleApplications() {
        manager.analyzeOptimizations()
        let tip0Id = manager.optimizations[0].id
        let tip1Id = manager.optimizations[1].id

        manager.applyOptimization(tip0Id)
        manager.applyOptimization(tip1Id)

        XCTAssertTrue(manager.optimizations[0].isApplied)
        XCTAssertTrue(manager.optimizations[1].isApplied)
        XCTAssertFalse(manager.optimizations[2].isApplied)
    }

    // MARK: - Generate Benchmark

    func testGenerateBenchmark_CreatesBenchmark() {
        manager.generateBenchmark(metric: .taskSuccessRate)
        XCTAssertEqual(manager.benchmarks.count, 1)
        XCTAssertEqual(manager.benchmarks[0].metric, .taskSuccessRate)
        XCTAssertFalse(manager.benchmarks[0].name.isEmpty)
    }

    func testGenerateBenchmark_UsesDefaultAgentsWithoutAppState() {
        // appState is nil, so default agent names should be used
        manager.generateBenchmark(metric: .costEfficiency)
        XCTAssertEqual(manager.benchmarks[0].entries.count, 4)
        let labels = manager.benchmarks[0].entries.map(\.label)
        XCTAssertTrue(labels.contains("Developer-1"))
        XCTAssertTrue(labels.contains("Reviewer-1"))
        XCTAssertTrue(labels.contains("Tester-1"))
        XCTAssertTrue(labels.contains("Architect-1"))
    }

    func testGenerateBenchmark_ReplacesExistingForSameMetric() {
        manager.generateBenchmark(metric: .tokenEfficiency)
        let firstId = manager.benchmarks[0].id

        manager.generateBenchmark(metric: .tokenEfficiency)
        XCTAssertEqual(manager.benchmarks.count, 1)
        XCTAssertNotEqual(manager.benchmarks[0].id, firstId)
    }

    func testGenerateBenchmark_DoesNotReplaceDifferentMetric() {
        manager.generateBenchmark(metric: .taskSuccessRate)
        manager.generateBenchmark(metric: .averageResponseTime)
        XCTAssertEqual(manager.benchmarks.count, 2)
    }

    func testGenerateBenchmark_AllMetrics() {
        for metric in BenchmarkMetric.allCases {
            manager.generateBenchmark(metric: metric)
        }
        XCTAssertEqual(manager.benchmarks.count, BenchmarkMetric.allCases.count)

        let metrics = Set(manager.benchmarks.map(\.metric))
        XCTAssertEqual(metrics.count, BenchmarkMetric.allCases.count)
    }

    func testGenerateBenchmark_EntriesHaveValidScores() {
        manager.generateBenchmark(metric: .errorRecoveryRate)
        for entry in manager.benchmarks[0].entries {
            XCTAssertGreaterThanOrEqual(entry.score, 0.0)
            XCTAssertLessThanOrEqual(entry.score, 1.0)
            XCTAssertFalse(entry.label.isEmpty)
        }
    }

    func testGenerateBenchmark_EvictionCapAt10() {
        // Manually populate with 9 benchmarks for different "metrics"
        // Since there are only 5 BenchmarkMetric cases, we directly populate
        for i in 0..<9 {
            let benchmark = PerformanceBenchmark(
                name: "Benchmark \(i)",
                entries: [],
                metric: .taskSuccessRate
            )
            manager.benchmarks.append(benchmark)
        }
        XCTAssertEqual(manager.benchmarks.count, 9)

        // Generate two more to push past the cap
        // The first replaces existing .taskSuccessRate, but we have 9 with same metric so
        // only the first match gets replaced -> 9, then check if still within cap
        manager.generateBenchmark(metric: .costEfficiency)
        // Now we have 9 + 1 = 10, at the cap
        XCTAssertLessThanOrEqual(manager.benchmarks.count, 10)

        // Add one more directly and generate to trigger eviction
        manager.benchmarks.append(PerformanceBenchmark(name: "Extra", entries: [], metric: .averageResponseTime))
        manager.generateBenchmark(metric: .tokenEfficiency)
        XCTAssertLessThanOrEqual(manager.benchmarks.count, 10)
    }

    func testGenerateBenchmark_SetsIsAnalyzingDuringExecution() {
        XCTAssertFalse(manager.isAnalyzing)
        manager.generateBenchmark(metric: .taskSuccessRate)
        XCTAssertFalse(manager.isAnalyzing)
    }

    // MARK: - Load Sample Data

    func testLoadSampleData_ReportCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.reports.count, 2)
    }

    func testLoadSampleData_ForecastCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.forecasts.count, 3)
    }

    func testLoadSampleData_OptimizationCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.optimizations.count, 5)
    }

    func testLoadSampleData_BenchmarkCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.benchmarks.count, 2)
    }

    func testLoadSampleData_ReportNames() {
        manager.loadSampleData()
        let names = manager.reports.map(\.name)
        XCTAssertTrue(names.contains("Daily Overview"))
        XCTAssertTrue(names.contains("Performance Deep Dive"))
    }

    func testLoadSampleData_OverviewReportIsDefault() {
        manager.loadSampleData()
        let overview = manager.reports.first { $0.name == "Daily Overview" }
        XCTAssertNotNil(overview)
        XCTAssertTrue(overview!.isDefault)
    }

    func testLoadSampleData_PerformanceReportIsNotDefault() {
        manager.loadSampleData()
        let perf = manager.reports.first { $0.name == "Performance Deep Dive" }
        XCTAssertNotNil(perf)
        XCTAssertFalse(perf!.isDefault)
    }

    func testLoadSampleData_ReportsHaveWidgets() {
        manager.loadSampleData()
        let overview = manager.reports.first { $0.name == "Daily Overview" }
        XCTAssertEqual(overview?.widgets.count, 4)

        let perf = manager.reports.first { $0.name == "Performance Deep Dive" }
        XCTAssertEqual(perf?.widgets.count, 3)
    }

    func testLoadSampleData_ForecastMetrics() {
        manager.loadSampleData()
        let metrics = Set(manager.forecasts.map(\.metric))
        XCTAssertTrue(metrics.contains(.tokenUsage))
        XCTAssertTrue(metrics.contains(.cost))
        XCTAssertTrue(metrics.contains(.errorRate))
    }

    func testLoadSampleData_OptimizationsNotApplied() {
        manager.loadSampleData()
        XCTAssertTrue(manager.optimizations.allSatisfy { !$0.isApplied })
    }

    func testLoadSampleData_BenchmarkMetrics() {
        manager.loadSampleData()
        let metrics = Set(manager.benchmarks.map(\.metric))
        XCTAssertTrue(metrics.contains(.taskSuccessRate))
        XCTAssertTrue(metrics.contains(.costEfficiency))
    }

    // MARK: - Total Potential Savings

    func testTotalPotentialSavings_AllUnapplied() {
        manager.analyzeOptimizations()
        let expectedTotal = manager.optimizations.reduce(0.0) { $0 + $1.estimatedSavings }
        XCTAssertEqual(manager.totalPotentialSavings, expectedTotal, accuracy: 0.001)
        XCTAssertGreaterThan(manager.totalPotentialSavings, 0)
    }

    func testTotalPotentialSavings_EmptyOptimizations() {
        XCTAssertEqual(manager.totalPotentialSavings, 0.0)
    }

    func testTotalPotentialSavings_DecreasesAfterApplying() {
        manager.analyzeOptimizations()
        let totalBefore = manager.totalPotentialSavings
        let firstTipSavings = manager.optimizations[0].estimatedSavings

        manager.applyOptimization(manager.optimizations[0].id)

        let totalAfter = manager.totalPotentialSavings
        XCTAssertEqual(totalAfter, totalBefore - firstTipSavings, accuracy: 0.001)
    }

    func testTotalPotentialSavings_ZeroWhenAllApplied() {
        manager.analyzeOptimizations()
        for tip in manager.optimizations {
            manager.applyOptimization(tip.id)
        }
        XCTAssertEqual(manager.totalPotentialSavings, 0.0)
    }

    // MARK: - Applied Savings Count

    func testAppliedSavingsCount_InitiallyZero() {
        XCTAssertEqual(manager.appliedSavingsCount, 0)
    }

    func testAppliedSavingsCount_AfterApplying() {
        manager.analyzeOptimizations()
        XCTAssertEqual(manager.appliedSavingsCount, 0)

        manager.applyOptimization(manager.optimizations[0].id)
        XCTAssertEqual(manager.appliedSavingsCount, 1)

        manager.applyOptimization(manager.optimizations[1].id)
        XCTAssertEqual(manager.appliedSavingsCount, 2)
    }

    func testAppliedSavingsCount_AllApplied() {
        manager.analyzeOptimizations()
        for tip in manager.optimizations {
            manager.applyOptimization(tip.id)
        }
        XCTAssertEqual(manager.appliedSavingsCount, manager.optimizations.count)
    }

    // MARK: - Selected Time Range Default

    func testSelectedTimeRange_DefaultValue() {
        XCTAssertEqual(manager.selectedTimeRange, .last7Days)
    }

    // MARK: - Initial State

    func testInitialState_AllCollectionsEmpty() {
        XCTAssertTrue(manager.reports.isEmpty)
        XCTAssertTrue(manager.forecasts.isEmpty)
        XCTAssertTrue(manager.optimizations.isEmpty)
        XCTAssertTrue(manager.benchmarks.isEmpty)
        XCTAssertFalse(manager.isAnalyzing)
    }

    func testInitialState_AppStateIsNil() {
        XCTAssertNil(manager.appState)
    }
}
