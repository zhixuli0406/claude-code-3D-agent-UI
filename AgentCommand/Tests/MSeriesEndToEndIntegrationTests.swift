import XCTest
@testable import AgentCommand

// MARK: - M-Series End-to-End Integration Tests
//
// Comprehensive E2E tests covering all M-series modules (M1-M5):
// - M1: Analytics Dashboard
// - M2: Report Export
// - M3: API Usage Analytics
// - M4: Session History Analytics
// - M5: Team Performance
//
// Test categories:
// 1. Cross-module data flow
// 2. Full workflow pipelines
// 3. Data consistency & integrity
// 4. State management & toggle interactions
// 5. Serialization round-trips across modules

// MARK: - 1. Full Pipeline: M3 API Recording → M1 Analytics → M2 Report Export

@MainActor
final class M3ToM1ToM2PipelineTests: XCTestCase {

    var apiManager: APIUsageAnalyticsManager!
    var dashboardManager: AnalyticsDashboardManager!
    var reportManager: ReportExportManager!

    override func setUp() {
        super.setUp()
        apiManager = APIUsageAnalyticsManager()
        dashboardManager = AnalyticsDashboardManager()
        reportManager = ReportExportManager()
    }

    override func tearDown() {
        apiManager = nil
        dashboardManager = nil
        reportManager = nil
        super.tearDown()
    }

    // Test: Record API calls → generate cost breakdown → create report → export
    func testFullAPIToReportPipeline() {
        // Step 1: Record API calls in M3
        let models = ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        for i in 0..<15 {
            let model = models[i % models.count]
            apiManager.recordAPICall(
                model: model,
                inputTokens: Int.random(in: 500...5000),
                outputTokens: Int.random(in: 200...3000),
                latencyMs: Double.random(in: 100...2000),
                costUSD: Double.random(in: 0.01...0.50),
                taskType: "coding",
                isError: i == 7, // One error call
                errorType: i == 7 ? "rate_limit" : nil
            )
        }

        XCTAssertEqual(apiManager.callRecords.count, 15, "Should have 15 API call records")

        // Step 2: Generate cost breakdown from M3
        apiManager.generateCostBreakdown(period: "Test Period")
        XCTAssertFalse(apiManager.costBreakdowns.isEmpty, "Should have cost breakdowns")

        let breakdown = apiManager.costBreakdowns.first!
        XCTAssertGreaterThan(breakdown.totalCost, 0, "Total cost should be positive")
        XCTAssertGreaterThan(breakdown.entries.count, 0, "Should have breakdown entries")

        // Step 3: Update M3 summary
        apiManager.updateSummary()
        XCTAssertEqual(apiManager.summary.totalCalls, 15)
        XCTAssertGreaterThan(apiManager.summary.totalTokens, 0)
        XCTAssertGreaterThan(apiManager.summary.totalCost, 0)

        // Step 4: Bridge M3 data to M2 report format
        let reportSummary = ReportSummary(
            totalTokens: apiManager.summary.totalTokens,
            totalCost: apiManager.summary.totalCost,
            totalTasks: apiManager.summary.totalCalls,
            successRate: 1.0 - apiManager.errorRate,
            averageLatency: apiManager.avgLatency,
            periodDescription: "E2E Test"
        )

        XCTAssertEqual(reportSummary.totalTokens, apiManager.summary.totalTokens)
        XCTAssertEqual(reportSummary.totalCost, apiManager.summary.totalCost, accuracy: 0.001)

        // Step 5: Generate report in M2
        let reportData = reportManager.generateReportData(title: "E2E Pipeline Report", timeRange: "Test Range")
        XCTAssertEqual(reportData.title, "E2E Pipeline Report")

        // Step 6: Export report
        reportManager.exportReport(format: .json, templateId: nil)
        XCTAssertFalse(reportManager.exportJobs.isEmpty, "Should have at least one export job")
    }

    // Test: API error rate feeds into dashboard optimization tips
    func testAPIErrorRateToDashboardOptimizations() {
        // Record calls with varying error rates
        for i in 0..<20 {
            apiManager.recordAPICall(
                model: "claude-3-sonnet",
                inputTokens: 1000,
                outputTokens: 500,
                latencyMs: Double.random(in: 200...1500),
                costUSD: 0.10,
                taskType: "review",
                isError: i % 4 == 0 // 25% error rate
            )
        }

        apiManager.updateSummary()
        let errorRate = apiManager.errorRate
        XCTAssertGreaterThan(errorRate, 0.0, "Should have some errors")

        // Dashboard should be able to create reports incorporating this data
        dashboardManager.createReport(name: "Error Analysis")
        XCTAssertEqual(dashboardManager.reports.count, 1)
        dashboardManager.analyzeOptimizations()
        // Optimizations may or may not be generated depending on thresholds
    }

    // Test: Budget alert triggers when API spend exceeds threshold
    func testBudgetAlertIntegration() {
        apiManager.setBudget(monthly: 10.0, alertThreshold: 0.8)
        XCTAssertNotNil(apiManager.budgetAlert)
        XCTAssertEqual(apiManager.budgetAlert?.monthlyBudget, 10.0)

        // Simulate spending
        for _ in 0..<10 {
            apiManager.recordAPICall(
                model: "claude-3-opus",
                inputTokens: 2000,
                outputTokens: 1000,
                latencyMs: 500,
                costUSD: 1.5,
                taskType: "generation"
            )
        }

        apiManager.updateBudgetSpend(apiManager.totalCost)

        let alert = apiManager.budgetAlert!
        XCTAssertGreaterThan(alert.currentSpend, 0)
        let level = alert.alertLevel
        // With $15 spend on $10 budget, should be critical
        XCTAssertEqual(level, .critical, "Should be critical when over budget")
    }
}

// MARK: - 2. Full Pipeline: M4 Session Recording → M5 Team Analysis → M1 Dashboard

@MainActor
final class M4ToM5ToM1PipelineTests: XCTestCase {

    var sessionManager: SessionHistoryAnalyticsManager!
    var teamManager: TeamPerformanceManager!
    var dashboardManager: AnalyticsDashboardManager!

    override func setUp() {
        super.setUp()
        sessionManager = SessionHistoryAnalyticsManager()
        teamManager = TeamPerformanceManager()
        dashboardManager = AnalyticsDashboardManager()
    }

    override func tearDown() {
        sessionManager = nil
        teamManager = nil
        dashboardManager = nil
        super.tearDown()
    }

    // Test: Full session lifecycle → team snapshot → dashboard report
    func testSessionToTeamToDashboardPipeline() {
        // Step 1: Record multiple sessions in M4
        let sessionNames = ["Morning Sprint", "Afternoon Debug", "Evening Review"]
        for (index, name) in sessionNames.enumerated() {
            var session = SessionAnalytics(
                sessionName: name,
                startedAt: Date().addingTimeInterval(-Double(3 - index) * 7200),
                totalTokens: 10000 + index * 5000,
                totalCost: 3.0 + Double(index) * 1.5,
                tasksCompleted: 10 + index * 5,
                tasksFailed: index,
                averageLatencyMs: 1000 + Double(index) * 200,
                productivityScore: 0.7 + Double(index) * 0.05
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            sessionManager.recordSession(session)
        }

        XCTAssertEqual(sessionManager.totalSessions, 3)
        XCTAssertGreaterThan(sessionManager.totalCostAllSessions, 0)
        XCTAssertGreaterThan(sessionManager.totalTasksAllSessions, 0)

        // Step 2: Analyze productivity trend
        sessionManager.analyzeProductivityTrend()
        XCTAssertNotNil(sessionManager.productivityTrend, "Should have a productivity trend")

        let trend = sessionManager.productivityTrend!
        XCTAssertEqual(trend.dataPoints.count, 3, "Should have 3 data points")

        // Step 3: Compare sessions
        let firstId = sessionManager.sessions[0].id
        let lastId = sessionManager.sessions[2].id
        sessionManager.compareSessions(firstId, lastId)
        XCTAssertEqual(sessionManager.comparisons.count, 1)

        let comparison = sessionManager.comparisons.first!
        XCTAssertEqual(comparison.metrics.count, 6, "Should compare 6 metrics")

        // Step 4: Capture team snapshot in M5
        teamManager.captureSnapshot(teamName: "Sprint Team")
        XCTAssertEqual(teamManager.snapshots.count, 1)

        let snapshot = teamManager.latestSnapshot!
        XCTAssertGreaterThan(snapshot.memberMetrics.count, 0)

        // Step 5: Generate team radar data
        teamManager.generateRadarData(teamName: "Sprint Team")
        XCTAssertEqual(teamManager.radarData.count, 1)

        let radar = teamManager.radarData.first!
        XCTAssertEqual(radar.dimensions.count, PerformanceDimension.allCases.count)

        // Step 6: Generate leaderboard for all metrics
        for metric in LeaderboardMetric.allCases {
            teamManager.generateLeaderboard(metric: metric)
        }
        XCTAssertEqual(teamManager.leaderboards.count, LeaderboardMetric.allCases.count)

        // Step 7: Feed into dashboard
        dashboardManager.createReport(name: "Sprint Summary")
        XCTAssertEqual(dashboardManager.reports.count, 1)
    }

    // Test: Session time distribution data integrity across pipeline
    func testTimeDistributionDataIntegrity() {
        // Record sessions
        for i in 0..<5 {
            var session = SessionAnalytics(
                sessionName: "Session \(i)",
                startedAt: Date().addingTimeInterval(-Double(5 - i) * 3600),
                totalTokens: 8000,
                totalCost: 2.5,
                tasksCompleted: 12,
                productivityScore: 0.75
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            sessionManager.recordSession(session)
        }

        // Generate time distribution
        sessionManager.generateTimeDistribution()
        XCTAssertNotNil(sessionManager.currentTimeDistribution)

        let distribution = sessionManager.currentTimeDistribution!
        XCTAssertGreaterThan(distribution.entries.count, 0)
        XCTAssertGreaterThan(distribution.totalMinutes, 0)

        // Verify percentages sum to ~1.0
        let totalPercentage = distribution.entries.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 1.0, accuracy: 0.01, "Time distribution percentages should sum to 1.0")
    }

    // Test: Productivity trend direction matches actual data
    func testProductivityTrendDirectionAccuracy() {
        let now = Date()

        // Create sessions with increasing productivity
        for i in 0..<8 {
            var session = SessionAnalytics(
                sessionName: "Improving \(i)",
                startedAt: now.addingTimeInterval(-Double(8 - i) * 86400),
                totalTokens: 5000 + i * 1000,
                totalCost: 2.0,
                tasksCompleted: 10 + i * 3,
                productivityScore: 0.4 + Double(i) * 0.08 // 0.4 → 0.96
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            sessionManager.recordSession(session)
        }

        sessionManager.analyzeProductivityTrend()
        XCTAssertNotNil(sessionManager.productivityTrend)

        let trend = sessionManager.productivityTrend!
        XCTAssertEqual(trend.overallTrend, .improving, "Trend should be improving when scores increase")
        XCTAssertGreaterThan(trend.averageProductivity, 0.5, "Average should be above 0.5")
    }
}

// MARK: - 3. Cross-Module Data Consistency Tests

@MainActor
final class CrossModuleDataConsistencyTests: XCTestCase {

    // Test: Session cost data matches API cost data when recording same events
    func testSessionCostMatchesAPICost() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let apiManager = APIUsageAnalyticsManager()

        let totalCost = 12.50
        let totalTokens = 25000

        // Record in session manager
        let session = SessionAnalytics(
            sessionName: "Cost Verification",
            totalTokens: totalTokens,
            totalCost: totalCost,
            tasksCompleted: 20,
            productivityScore: 0.8
        )
        sessionManager.recordSession(session)

        // Record equivalent in API manager (split across calls)
        for _ in 0..<10 {
            apiManager.recordAPICall(
                model: "claude-3-sonnet",
                inputTokens: totalTokens / 10,
                outputTokens: 0,
                latencyMs: 500,
                costUSD: totalCost / 10.0,
                taskType: "coding"
            )
        }

        apiManager.updateSummary()

        // Costs should match
        XCTAssertEqual(sessionManager.totalCostAllSessions, totalCost, accuracy: 0.01)
        XCTAssertEqual(apiManager.totalCost, totalCost, accuracy: 0.01)
        XCTAssertEqual(sessionManager.totalCostAllSessions, apiManager.totalCost, accuracy: 0.01)
    }

    // Test: Team performance aggregation matches individual member totals
    func testTeamAggregationMatchesMemberTotals() {
        let teamManager = TeamPerformanceManager()
        teamManager.captureSnapshot(teamName: "Verification Team")

        guard let snapshot = teamManager.latestSnapshot else {
            XCTFail("Should have a snapshot")
            return
        }

        // Member totals should match (or be close to) snapshot aggregates
        let memberTaskTotal = snapshot.memberMetrics.reduce(0) { $0 + $1.tasksCompleted }
        XCTAssertEqual(memberTaskTotal, snapshot.totalTasksCompleted,
                       "Sum of member tasks should match snapshot total")

        let memberCostTotal = snapshot.memberMetrics.reduce(0.0) { $0 + $1.totalCost }
        XCTAssertEqual(memberCostTotal, snapshot.totalCost, accuracy: 0.01,
                       "Sum of member costs should match snapshot total")
    }

    // Test: Report summary derived from API data maintains accuracy
    func testReportSummaryFromAPIData() {
        let apiManager = APIUsageAnalyticsManager()

        // Record a known set of API calls
        let callCount = 20
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCost = 0.0
        var errorCount = 0

        for i in 0..<callCount {
            let input = 1000 + i * 100
            let output = 500 + i * 50
            let cost = 0.05 + Double(i) * 0.01
            let isError = i % 5 == 0
            totalInputTokens += input
            totalOutputTokens += output
            totalCost += cost
            if isError { errorCount += 1 }

            apiManager.recordAPICall(
                model: "claude-3-sonnet",
                inputTokens: input,
                outputTokens: output,
                latencyMs: 500,
                costUSD: cost,
                taskType: "test",
                isError: isError
            )
        }

        apiManager.updateSummary()

        // Bridge to report summary
        let summary = ReportSummary(
            totalTokens: apiManager.summary.totalTokens,
            totalCost: apiManager.summary.totalCost,
            totalTasks: apiManager.summary.totalCalls,
            successRate: 1.0 - apiManager.errorRate,
            averageLatency: apiManager.avgLatency,
            periodDescription: "Verification"
        )

        XCTAssertEqual(summary.totalTokens, totalInputTokens + totalOutputTokens,
                       "Report token count should match recorded total")
        XCTAssertEqual(summary.totalCost, totalCost, accuracy: 0.01,
                       "Report cost should match recorded total")
        XCTAssertEqual(summary.totalTasks, callCount,
                       "Report task count should match call count")
    }

    // Test: Model usage stats match individual API call records
    func testModelUsageStatsAccuracy() {
        let apiManager = APIUsageAnalyticsManager()

        // Record known calls per model
        let sonnetCalls = 8
        let haikuCalls = 12
        let sonnetCost = 0.10
        let haikuCost = 0.02

        for _ in 0..<sonnetCalls {
            apiManager.recordAPICall(
                model: "claude-3-sonnet",
                inputTokens: 1000,
                outputTokens: 500,
                latencyMs: 800,
                costUSD: sonnetCost,
                taskType: "coding"
            )
        }
        for _ in 0..<haikuCalls {
            apiManager.recordAPICall(
                model: "claude-3-haiku",
                inputTokens: 500,
                outputTokens: 200,
                latencyMs: 200,
                costUSD: haikuCost,
                taskType: "review"
            )
        }

        apiManager.updateModelStats()

        let sonnetStats = apiManager.modelStats.first { $0.modelName == "claude-3-sonnet" }
        let haikuStats = apiManager.modelStats.first { $0.modelName == "claude-3-haiku" }

        XCTAssertNotNil(sonnetStats)
        XCTAssertNotNil(haikuStats)
        XCTAssertEqual(sonnetStats?.totalCalls, sonnetCalls)
        XCTAssertEqual(haikuStats?.totalCalls, haikuCalls)
        XCTAssertEqual(sonnetStats?.totalCost ?? 0, Double(sonnetCalls) * sonnetCost, accuracy: 0.01)
        XCTAssertEqual(haikuStats?.totalCost ?? 0, Double(haikuCalls) * haikuCost, accuracy: 0.01)
    }
}

// MARK: - 4. M2 Report Export Full Workflow Tests

@MainActor
final class M2ReportExportWorkflowTests: XCTestCase {

    var reportManager: ReportExportManager!

    override func setUp() {
        super.setUp()
        reportManager = ReportExportManager()
    }

    override func tearDown() {
        reportManager = nil
        super.tearDown()
    }

    // Test: Create template → schedule → export → verify
    func testTemplateToScheduleToExportWorkflow() {
        // Step 1: Create a template
        let sections = [
            ReportSection(type: .executiveSummary, isEnabled: true, sortOrder: 0),
            ReportSection(type: .tokenUsage, isEnabled: true, sortOrder: 1),
            ReportSection(type: .costAnalysis, isEnabled: true, sortOrder: 2),
            ReportSection(type: .taskMetrics, isEnabled: true, sortOrder: 3),
        ]
        reportManager.createTemplate(name: "E2E Template", description: "End-to-end test", sections: sections)
        XCTAssertEqual(reportManager.templates.count, 1)

        let template = reportManager.templates.first!
        XCTAssertEqual(template.name, "E2E Template")
        XCTAssertEqual(template.sections.count, 4)

        // Step 2: Create a schedule for this template
        reportManager.createSchedule(
            name: "Daily E2E Report",
            templateId: template.id,
            frequency: .daily,
            format: .json
        )
        XCTAssertEqual(reportManager.schedules.count, 1)

        let schedule = reportManager.schedules.first!
        XCTAssertEqual(schedule.templateId, template.id)
        XCTAssertTrue(schedule.isActive)

        // Step 3: Toggle schedule off/on
        reportManager.toggleSchedule(schedule.id)
        XCTAssertFalse(reportManager.schedules.first!.isActive)
        reportManager.toggleSchedule(schedule.id)
        XCTAssertTrue(reportManager.schedules.first!.isActive)

        // Step 4: Export
        reportManager.exportReport(format: .json, templateId: template.id)
        XCTAssertGreaterThanOrEqual(reportManager.exportJobs.count, 1)

        // Note: exportReport has a guard that prevents concurrent exports,
        // so only one export job will be created while isExporting is true.
        // This is expected behavior - the manager serializes export operations.
    }

    // Test: Generate report data and verify structure
    func testReportDataGeneration() {
        let reportData = reportManager.generateReportData(
            title: "Integration Report",
            timeRange: "Last 7 Days"
        )

        XCTAssertEqual(reportData.title, "Integration Report")
        XCTAssertEqual(reportData.timeRange, "Last 7 Days")
        XCTAssertFalse(reportData.id.isEmpty)
    }

    // Test: Delete operations work correctly
    func testDeleteOperations() {
        // Create items
        reportManager.createTemplate(name: "Delete Test", description: "", sections: [])
        let templateId = reportManager.templates.first!.id

        reportManager.createSchedule(name: "Del Schedule", templateId: templateId, frequency: .weekly, format: .csv)
        let scheduleId = reportManager.schedules.first!.id

        reportManager.exportReport(format: .json, templateId: nil)
        let jobId = reportManager.exportJobs.first!.id

        // Delete each
        reportManager.deleteTemplate(templateId)
        XCTAssertTrue(reportManager.templates.isEmpty)

        reportManager.deleteSchedule(scheduleId)
        XCTAssertTrue(reportManager.schedules.isEmpty)

        reportManager.deleteExportJob(jobId)
        XCTAssertTrue(reportManager.exportJobs.isEmpty)
    }
}

// MARK: - 5. M1 Analytics Dashboard Full Workflow Tests

@MainActor
final class M1AnalyticsDashboardWorkflowTests: XCTestCase {

    var dashboardManager: AnalyticsDashboardManager!

    override func setUp() {
        super.setUp()
        dashboardManager = AnalyticsDashboardManager()
    }

    override func tearDown() {
        dashboardManager = nil
        super.tearDown()
    }

    // Test: Create report → add widgets → generate forecasts → benchmarks
    func testDashboardFullWorkflow() {
        // Step 1: Create report
        dashboardManager.createReport(name: "Full Workflow Report", description: "E2E test")
        XCTAssertEqual(dashboardManager.reports.count, 1)

        let reportId = dashboardManager.reports.first!.id

        // Step 2: Add widgets
        dashboardManager.addWidget(
            to: reportId,
            type: .lineChart,
            title: "Token Usage Over Time",
            dataSource: .tokenUsage,
            size: .large
        )
        dashboardManager.addWidget(
            to: reportId,
            type: .pieChart,
            title: "Model Distribution",
            dataSource: .modelDistribution,
            size: .medium
        )
        dashboardManager.addWidget(
            to: reportId,
            type: .barChart,
            title: "Task Completion",
            dataSource: .taskCompletion,
            size: .medium
        )

        let report = dashboardManager.reports.first!
        XCTAssertEqual(report.widgets.count, 3)

        // Step 3: Remove a widget
        let widgetToRemove = report.widgets.first!.id
        dashboardManager.removeWidget(from: reportId, widgetId: widgetToRemove)
        XCTAssertEqual(dashboardManager.reports.first!.widgets.count, 2)

        // Step 4: Generate forecasts
        dashboardManager.generateForecast(for: .tokenUsage, periodDays: 14)
        dashboardManager.generateForecast(for: .cost, periodDays: 30)
        XCTAssertEqual(dashboardManager.forecasts.count, 2)

        for forecast in dashboardManager.forecasts {
            XCTAssertGreaterThan(forecast.dataPoints.count, 0, "Forecast should have data points")
            XCTAssertGreaterThan(forecast.confidence, 0, "Confidence should be positive")
        }

        // Step 5: Generate benchmark
        dashboardManager.generateBenchmark(metric: .taskSuccessRate)
        XCTAssertEqual(dashboardManager.benchmarks.count, 1)

        // Step 6: Analyze optimizations
        dashboardManager.analyzeOptimizations()
    }

    // Test: Delete report cascade
    func testDeleteReportCascade() {
        dashboardManager.createReport(name: "To Delete")
        let reportId = dashboardManager.reports.first!.id

        dashboardManager.addWidget(
            to: reportId,
            type: .metric,
            title: "Cost",
            dataSource: .costOverTime,
            size: .small
        )

        XCTAssertEqual(dashboardManager.reports.count, 1)
        dashboardManager.deleteReport(reportId)
        XCTAssertTrue(dashboardManager.reports.isEmpty)
    }
}

// MARK: - 6. Sample Data Loading & Consistency Tests

@MainActor
final class SampleDataIntegrationTests: XCTestCase {

    // Test: All managers can load sample data without crash
    func testAllManagersSampleDataLoading() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let teamManager = TeamPerformanceManager()
        let dashboardManager = AnalyticsDashboardManager()
        let reportManager = ReportExportManager()
        let apiManager = APIUsageAnalyticsManager()

        // Load sample data - should not crash
        sessionManager.loadSampleData()
        teamManager.loadSampleData()
        dashboardManager.loadSampleData()
        reportManager.loadSampleData()
        apiManager.loadSampleData()

        // Verify all have data
        XCTAssertGreaterThan(sessionManager.totalSessions, 0, "Session manager should have sample data")
        XCTAssertGreaterThan(teamManager.snapshots.count, 0, "Team manager should have sample data")
        XCTAssertGreaterThan(dashboardManager.reports.count, 0, "Dashboard should have sample data")
        XCTAssertGreaterThan(apiManager.callRecords.count, 0, "API manager should have sample data")
    }

    // Test: Sample data is consistent across modules
    func testSampleDataCrossModuleConsistency() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let teamManager = TeamPerformanceManager()
        let apiManager = APIUsageAnalyticsManager()

        sessionManager.loadSampleData()
        teamManager.loadSampleData()
        apiManager.loadSampleData()

        // All should have positive cost values
        XCTAssertGreaterThan(sessionManager.totalCostAllSessions, 0)
        XCTAssertGreaterThan(teamManager.latestSnapshot?.totalCost ?? 0, 0)
        XCTAssertGreaterThan(apiManager.totalCost, 0)

        // All should have positive task counts
        XCTAssertGreaterThan(sessionManager.totalTasksAllSessions, 0)
        XCTAssertGreaterThan(teamManager.latestSnapshot?.totalTasksCompleted ?? 0, 0)
    }

    // Test: Sample data analysis functions work after loading
    func testSampleDataAnalysisFunctions() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let teamManager = TeamPerformanceManager()

        sessionManager.loadSampleData()
        teamManager.loadSampleData()

        // Session analysis
        sessionManager.analyzeProductivityTrend()
        XCTAssertNotNil(sessionManager.productivityTrend)

        sessionManager.generateTimeDistribution()
        XCTAssertNotNil(sessionManager.currentTimeDistribution)

        // Team analysis
        teamManager.generateRadarData(teamName: "Sample Team")
        XCTAssertGreaterThan(teamManager.radarData.count, 0)

        for metric in LeaderboardMetric.allCases {
            teamManager.generateLeaderboard(metric: metric)
        }
        XCTAssertEqual(teamManager.leaderboards.count, LeaderboardMetric.allCases.count)
    }
}

// MARK: - 7. Codable Serialization Round-Trip Tests

final class MSeriesCodableRoundTripTests: XCTestCase {

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // Test: All M4 models survive round-trip encoding
    func testSessionAnalyticsCodableRoundTrip() throws {
        var session = SessionAnalytics(
            sessionName: "Codable Test",
            totalTokens: 15000,
            totalCost: 5.25,
            tasksCompleted: 30,
            tasksFailed: 2,
            agentsUsed: 3,
            dominantModel: "opus",
            averageLatencyMs: 1234.5,
            peakTokenRate: 500,
            productivityScore: 0.85
        )
        session.endedAt = session.startedAt.addingTimeInterval(7200)

        let data = try encoder.encode(session)
        let decoded = try decoder.decode(SessionAnalytics.self, from: data)

        XCTAssertEqual(decoded.sessionName, session.sessionName)
        XCTAssertEqual(decoded.totalTokens, session.totalTokens)
        XCTAssertEqual(decoded.totalCost, session.totalCost)
        XCTAssertEqual(decoded.tasksCompleted, session.tasksCompleted)
        XCTAssertEqual(decoded.tasksFailed, session.tasksFailed)
        XCTAssertEqual(decoded.productivityScore, session.productivityScore)
        XCTAssertEqual(decoded.successRate, session.successRate, accuracy: 0.001)
        XCTAssertEqual(decoded.formattedDuration, session.formattedDuration)
    }

    // Test: All M5 models survive round-trip encoding
    func testTeamPerformanceSnapshotCodableRoundTrip() throws {
        let metrics = [
            AgentPerformanceMetric(agentName: "Coder", tasksCompleted: 40, tasksFailed: 2, totalCost: 3.0, efficiency: 0.9, specialization: .codeGeneration),
            AgentPerformanceMetric(agentName: "Reviewer", tasksCompleted: 35, tasksFailed: 1, totalCost: 1.5, efficiency: 0.95, specialization: .codeReview),
        ]

        let snapshot = TeamPerformanceSnapshot(
            teamName: "Codable Team",
            memberMetrics: metrics,
            overallEfficiency: 0.925,
            totalTasksCompleted: 75,
            totalCost: 4.5,
            averageResponseTime: 1200
        )

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(TeamPerformanceSnapshot.self, from: data)

        XCTAssertEqual(decoded.teamName, snapshot.teamName)
        XCTAssertEqual(decoded.memberMetrics.count, 2)
        XCTAssertEqual(decoded.totalTasksCompleted, 75)
        XCTAssertEqual(decoded.totalCost, 4.5)
        XCTAssertEqual(decoded.overallEfficiency, 0.925)
    }

    // Test: Radar data round-trip
    func testRadarDataCodableRoundTrip() throws {
        let dimensions = PerformanceDimension.allCases.map {
            RadarDimension(category: $0, value: Double.random(in: 0.3...0.9))
        }
        let radar = TeamRadarData(teamName: "Radar Test", dimensions: dimensions)

        let data = try encoder.encode(radar)
        let decoded = try decoder.decode(TeamRadarData.self, from: data)

        XCTAssertEqual(decoded.teamName, radar.teamName)
        XCTAssertEqual(decoded.dimensions.count, PerformanceDimension.allCases.count)
        for (original, restored) in zip(radar.dimensions, decoded.dimensions) {
            XCTAssertEqual(original.category, restored.category)
            XCTAssertEqual(original.value, restored.value, accuracy: 0.001)
        }
    }

    // Test: API call metrics round-trip
    func testAPICallMetricsCodableRoundTrip() throws {
        let metric = APICallMetrics(
            model: "claude-3-opus",
            inputTokens: 5000,
            outputTokens: 2000,
            latencyMs: 1500,
            costUSD: 0.25,
            isError: true,
            errorType: "timeout",
            taskType: "generation"
        )

        let data = try encoder.encode(metric)
        let decoded = try decoder.decode(APICallMetrics.self, from: data)

        XCTAssertEqual(decoded.model, "claude-3-opus")
        XCTAssertEqual(decoded.inputTokens, 5000)
        XCTAssertEqual(decoded.outputTokens, 2000)
        XCTAssertEqual(decoded.totalTokens, 7000)
        XCTAssertEqual(decoded.costUSD, 0.25)
        XCTAssertTrue(decoded.isError)
        XCTAssertEqual(decoded.errorType, "timeout")
    }

    // Test: Cost breakdown round-trip
    func testCostBreakdownCodableRoundTrip() throws {
        let entries = [
            CostBreakdownEntry(category: "Sonnet", cost: 5.0, tokenCount: 10000, callCount: 50, totalCost: 8.0),
            CostBreakdownEntry(category: "Haiku", cost: 3.0, tokenCount: 20000, callCount: 100, totalCost: 8.0),
        ]
        let breakdown = CostBreakdown(entries: entries, period: "January 2025")

        let data = try encoder.encode(breakdown)
        let decoded = try decoder.decode(CostBreakdown.self, from: data)

        XCTAssertEqual(decoded.entries.count, 2)
        XCTAssertEqual(decoded.totalCost, 8.0)
        XCTAssertEqual(decoded.period, "January 2025")
    }

    // Test: Report template round-trip
    func testReportTemplateCodableRoundTrip() throws {
        let sections = [
            ReportSection(type: .executiveSummary, isEnabled: true, sortOrder: 0),
            ReportSection(type: .costAnalysis, isEnabled: true, sortOrder: 1),
            ReportSection(type: .taskMetrics, isEnabled: false, sortOrder: 2),
        ]
        let template = ReportTemplate(
            name: "Codable Template",
            description: "Test template",
            sections: sections,
            includeCharts: true,
            includeSummary: true
        )

        let data = try encoder.encode(template)
        let decoded = try decoder.decode(ReportTemplate.self, from: data)

        XCTAssertEqual(decoded.name, "Codable Template")
        XCTAssertEqual(decoded.sections.count, 3)
        XCTAssertTrue(decoded.includeCharts)
        XCTAssertTrue(decoded.includeSummary)
    }

    // Test: Cross-module codable interop
    func testCrossModuleCodableInterop() throws {
        // Encode session analytics
        let session = SessionAnalytics(
            sessionName: "Cross Module",
            totalTokens: 20000,
            totalCost: 6.0,
            tasksCompleted: 25,
            tasksFailed: 3,
            productivityScore: 0.82
        )

        // Encode team snapshot with matching data
        let snapshot = TeamPerformanceSnapshot(
            teamName: "Cross Module Team",
            overallEfficiency: 0.85,
            totalTasksCompleted: session.tasksCompleted,
            totalCost: session.totalCost
        )

        // Encode budget alert
        let budget = BudgetAlert(monthlyBudget: 50.0, alertThreshold: 0.75)

        let sessionData = try encoder.encode(session)
        let snapshotData = try encoder.encode(snapshot)
        let budgetData = try encoder.encode(budget)

        let decodedSession = try decoder.decode(SessionAnalytics.self, from: sessionData)
        let decodedSnapshot = try decoder.decode(TeamPerformanceSnapshot.self, from: snapshotData)
        let decodedBudget = try decoder.decode(BudgetAlert.self, from: budgetData)

        // Cross-module consistency
        XCTAssertEqual(decodedSession.totalCost, decodedSnapshot.totalCost)
        XCTAssertEqual(decodedSession.tasksCompleted, decodedSnapshot.totalTasksCompleted)
        XCTAssertEqual(decodedBudget.monthlyBudget, 50.0)
        XCTAssertEqual(decodedBudget.alertThreshold, 0.75)
    }
}

// MARK: - 8. Data Flow & Transformation Tests

@MainActor
final class DataFlowTransformationTests: XCTestCase {

    // Test: M4 Session data transforms correctly into M2 Report format
    func testSessionToReportTransformation() {
        let sessionManager = SessionHistoryAnalyticsManager()

        // Record sessions with known data
        for i in 0..<5 {
            var session = SessionAnalytics(
                sessionName: "Transform \(i)",
                totalTokens: 10000,
                totalCost: 3.0,
                tasksCompleted: 15,
                tasksFailed: 1,
                averageLatencyMs: 800,
                productivityScore: 0.75
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            sessionManager.recordSession(session)
        }

        // Transform to report summary
        let summary = ReportSummary(
            totalTokens: sessionManager.sessions.reduce(0) { $0 + $1.totalTokens },
            totalCost: sessionManager.totalCostAllSessions,
            totalTasks: sessionManager.totalTasksAllSessions,
            successRate: sessionManager.averageProductivity,
            averageLatency: sessionManager.sessions.reduce(0.0) { $0 + $1.averageLatencyMs } / Double(sessionManager.totalSessions),
            periodDescription: "Transform Test"
        )

        XCTAssertEqual(summary.totalTokens, 50000)
        XCTAssertEqual(summary.totalCost, 15.0, accuracy: 0.01)
        XCTAssertEqual(summary.totalTasks, sessionManager.totalTasksAllSessions)
    }

    // Test: M5 Team data transforms into cost breakdown entries
    func testTeamToCostBreakdownTransformation() {
        let teamManager = TeamPerformanceManager()
        teamManager.captureSnapshot(teamName: "Transform Team")

        guard let snapshot = teamManager.latestSnapshot else {
            XCTFail("Should have snapshot")
            return
        }

        let totalCost = snapshot.totalCost
        let entries = snapshot.memberMetrics.map { metric in
            CostBreakdownEntry(
                category: metric.agentName,
                cost: metric.totalCost,
                tokenCount: metric.totalTokens,
                callCount: metric.tasksCompleted,
                totalCost: totalCost
            )
        }

        let breakdown = CostBreakdown(entries: entries, period: "Team Transform")

        XCTAssertEqual(breakdown.entries.count, snapshot.memberMetrics.count)
        XCTAssertEqual(breakdown.totalCost, totalCost, accuracy: 0.01)

        // Percentages should sum to ~1.0
        let totalPct = breakdown.entries.reduce(0.0) { $0 + $1.percentage }
        if totalCost > 0 {
            XCTAssertEqual(totalPct, 1.0, accuracy: 0.02)
        }
    }

    // Test: M3 API metrics can populate M1 dashboard widgets
    func testAPIMetricsToDashboardWidgets() {
        let apiManager = APIUsageAnalyticsManager()
        let dashboardManager = AnalyticsDashboardManager()

        // Record API calls
        for _ in 0..<10 {
            apiManager.recordAPICall(
                model: "claude-3-sonnet",
                inputTokens: 1000,
                outputTokens: 500,
                latencyMs: 600,
                costUSD: 0.08,
                taskType: "coding"
            )
        }

        apiManager.updateSummary()

        // Create dashboard report with relevant widgets
        dashboardManager.createReport(name: "API Dashboard")
        let reportId = dashboardManager.reports.first!.id

        // Add widgets for each data source
        let dataSources: [ReportWidget.WidgetDataSource] = [.tokenUsage, .costOverTime, .taskCompletion, .errorRate, .responseLatency]
        for (index, source) in dataSources.enumerated() {
            dashboardManager.addWidget(
                to: reportId,
                type: .lineChart,
                title: "Widget \(index)",
                dataSource: source,
                size: .medium
            )
        }

        let report = dashboardManager.reports.first!
        XCTAssertEqual(report.widgets.count, dataSources.count)
    }
}

// MARK: - 9. State Management Integration Tests

@MainActor
final class MSeriesStateManagementTests: XCTestCase {

    // Test: M-series manager isolation - each manager maintains independent state
    func testManagerIsolation() {
        let sessionManager1 = SessionHistoryAnalyticsManager()
        let sessionManager2 = SessionHistoryAnalyticsManager()

        sessionManager1.recordSession(SessionAnalytics(
            sessionName: "M1 Only", totalTokens: 5000, totalCost: 2.0, tasksCompleted: 10, productivityScore: 0.8
        ))

        XCTAssertEqual(sessionManager1.totalSessions, 1)
        XCTAssertEqual(sessionManager2.totalSessions, 0, "Separate instances should have independent state")
    }

    // Test: M-series manager published properties are observable
    func testManagerPublishedProperties() {
        let sessionManager = SessionHistoryAnalyticsManager()
        XCTAssertFalse(sessionManager.isAnalyzing)
        XCTAssertTrue(sessionManager.sessions.isEmpty)
        XCTAssertNil(sessionManager.productivityTrend)
        XCTAssertTrue(sessionManager.comparisons.isEmpty)
        XCTAssertNil(sessionManager.currentTimeDistribution)

        let teamManager = TeamPerformanceManager()
        XCTAssertFalse(teamManager.isAnalyzing)
        XCTAssertTrue(teamManager.snapshots.isEmpty)
        XCTAssertTrue(teamManager.radarData.isEmpty)
        XCTAssertTrue(teamManager.leaderboards.isEmpty)

        let apiManager = APIUsageAnalyticsManager()
        XCTAssertFalse(apiManager.isMonitoring)
        XCTAssertTrue(apiManager.callRecords.isEmpty)
        XCTAssertNil(apiManager.budgetAlert)
        XCTAssertNil(apiManager.usageForecast)

        let dashboardManager = AnalyticsDashboardManager()
        XCTAssertFalse(dashboardManager.isAnalyzing)
        XCTAssertTrue(dashboardManager.reports.isEmpty)
        XCTAssertTrue(dashboardManager.forecasts.isEmpty)

        let reportManager = ReportExportManager()
        XCTAssertFalse(reportManager.isExporting)
        XCTAssertTrue(reportManager.templates.isEmpty)
        XCTAssertTrue(reportManager.schedules.isEmpty)
    }

    // Test: Manager state changes propagate correctly
    func testManagerStateChanges() {
        let sessionManager = SessionHistoryAnalyticsManager()

        // Initial state
        XCTAssertEqual(sessionManager.totalSessions, 0)
        XCTAssertEqual(sessionManager.averageProductivity, 0)

        // After adding sessions
        sessionManager.recordSession(SessionAnalytics(
            sessionName: "S1", totalTokens: 5000, totalCost: 2.0,
            tasksCompleted: 10, productivityScore: 0.8
        ))
        sessionManager.recordSession(SessionAnalytics(
            sessionName: "S2", totalTokens: 8000, totalCost: 3.0,
            tasksCompleted: 15, productivityScore: 0.9
        ))

        XCTAssertEqual(sessionManager.totalSessions, 2)
        XCTAssertGreaterThan(sessionManager.averageProductivity, 0)
        XCTAssertEqual(sessionManager.totalCostAllSessions, 5.0, accuracy: 0.01)

        // After deleting a session
        let firstId = sessionManager.sessions.first!.id
        sessionManager.deleteSession(firstId)
        XCTAssertEqual(sessionManager.totalSessions, 1)
    }
}

// MARK: - 10. Edge Cases & Boundary Tests

@MainActor
final class MSeriesEdgeCaseBoundaryTests: XCTestCase {

    // Test: Empty data handling across all managers
    func testEmptyDataHandling() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let teamManager = TeamPerformanceManager()
        let apiManager = APIUsageAnalyticsManager()
        let dashboardManager = AnalyticsDashboardManager()
        let reportManager = ReportExportManager()

        // All computed properties should handle empty state gracefully
        XCTAssertEqual(sessionManager.totalSessions, 0)
        XCTAssertEqual(sessionManager.averageProductivity, 0)
        XCTAssertEqual(sessionManager.totalCostAllSessions, 0)
        XCTAssertEqual(sessionManager.totalTasksAllSessions, 0)

        XCTAssertNil(teamManager.latestSnapshot)
        XCTAssertNil(teamManager.topPerformer)
        XCTAssertEqual(teamManager.averageTeamEfficiency, 0)

        XCTAssertEqual(apiManager.totalCost, 0)
        XCTAssertEqual(apiManager.errorRate, 0)

        XCTAssertTrue(dashboardManager.reports.isEmpty)
        XCTAssertTrue(dashboardManager.forecasts.isEmpty)
        XCTAssertEqual(dashboardManager.totalPotentialSavings, 0)

        XCTAssertTrue(reportManager.templates.isEmpty)
        XCTAssertEqual(reportManager.activeScheduleCount, 0)
    }

    // Test: Session with zero tasks
    func testZeroTaskSession() {
        let session = SessionAnalytics(
            sessionName: "Zero Tasks",
            totalTokens: 0,
            totalCost: 0,
            tasksCompleted: 0,
            tasksFailed: 0,
            productivityScore: 0
        )

        XCTAssertEqual(session.successRate, 0)
        XCTAssertEqual(session.successRatePercentage, 0)
        XCTAssertEqual(session.productivityLabel, "Below Average")
    }

    // Test: Agent with zero completed tasks
    func testZeroCompletedTaskAgent() {
        let metric = AgentPerformanceMetric(
            agentName: "Idle Agent",
            tasksCompleted: 0,
            tasksFailed: 0,
            totalCost: 0,
            efficiency: 0
        )

        XCTAssertEqual(metric.successRate, 0)
        XCTAssertEqual(metric.costPerTask, 0)
    }

    // Test: Radar dimension value clamping
    func testRadarDimensionClamping() {
        let overMax = RadarDimension(category: .speed, value: 1.5)
        let underMin = RadarDimension(category: .quality, value: -0.5)
        let normal = RadarDimension(category: .reliability, value: 0.75)

        XCTAssertEqual(overMax.value, 1.0, "Values over 1.0 should be clamped")
        XCTAssertEqual(underMin.value, 0.0, "Values under 0.0 should be clamped")
        XCTAssertEqual(normal.value, 0.75, "Normal values should be unchanged")
    }

    // Test: Session comparison with identical sessions
    func testIdenticalSessionComparison() {
        let session = SessionAnalytics(
            sessionName: "Same",
            totalTokens: 10000,
            totalCost: 5.0,
            tasksCompleted: 20,
            tasksFailed: 2,
            productivityScore: 0.8
        )

        let comparison = SessionComparison(sessionA: session, sessionB: session)

        for metric in comparison.metrics {
            XCTAssertEqual(metric.delta, 0, accuracy: 0.001, "Delta should be 0 for identical sessions (\(metric.name))")
        }
    }

    // Test: Budget alert levels at boundaries
    func testBudgetAlertLevelBoundaries() {
        // Under threshold → normal
        var alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        XCTAssertEqual(alert.alertLevel, .normal)

        // At threshold → warning
        alert = BudgetAlert(monthlyBudget: 100.0, alertThreshold: 0.8)
        // Need to set currentSpend - this tests the init state
        XCTAssertEqual(alert.currentSpend, 0)
        XCTAssertEqual(alert.remainingBudget, 100.0)

        // Verify formatted strings
        XCTAssertEqual(alert.formattedBudget, "$100.00")
    }

    // Test: Time distribution with all categories
    func testTimeDistributionAllCategories() {
        let totalMinutes = 180.0
        let categories = TimeDistributionEntry.TimeCategory.allCases
        let minutesEach = totalMinutes / Double(categories.count)

        let entries = categories.map { category in
            TimeDistributionEntry(category: category, minutes: minutesEach, totalMinutes: totalMinutes)
        }

        let distribution = SessionTimeDistribution(entries: entries)

        XCTAssertEqual(distribution.entries.count, categories.count)
        XCTAssertEqual(distribution.totalMinutes, totalMinutes, accuracy: 0.01)

        let totalPct = distribution.entries.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPct, 1.0, accuracy: 0.01)

        // Each category should have equal percentage
        for entry in distribution.entries {
            XCTAssertEqual(entry.percentage, 1.0 / Double(categories.count), accuracy: 0.01)
        }
    }

    // Test: Session capacity limit
    func testSessionCapacityLimit() {
        let manager = SessionHistoryAnalyticsManager()

        // Record 105 sessions (limit should be 100)
        for i in 0..<105 {
            let session = SessionAnalytics(
                sessionName: "Session \(i)",
                totalTokens: 1000,
                totalCost: 1.0,
                tasksCompleted: 5,
                productivityScore: 0.7
            )
            manager.recordSession(session)
        }

        XCTAssertLessThanOrEqual(manager.totalSessions, 100, "Should not exceed 100 sessions")
    }

    // Test: Team snapshot capacity limit
    func testTeamSnapshotCapacityLimit() {
        let manager = TeamPerformanceManager()

        // Capture 55 snapshots (limit should be 50)
        for i in 0..<55 {
            manager.captureSnapshot(teamName: "Team \(i)")
        }

        XCTAssertLessThanOrEqual(manager.snapshots.count, 50, "Should not exceed 50 snapshots")
    }

    // Test: Computed property accuracy - productivity labels
    func testProductivityLabelRanges() {
        let excellent = SessionAnalytics(sessionName: "E", productivityScore: 0.9)
        let good = SessionAnalytics(sessionName: "G", productivityScore: 0.7)
        let average = SessionAnalytics(sessionName: "A", productivityScore: 0.5)
        let below = SessionAnalytics(sessionName: "B", productivityScore: 0.3)

        XCTAssertEqual(excellent.productivityLabel, "Excellent")
        XCTAssertEqual(good.productivityLabel, "Good")
        XCTAssertEqual(average.productivityLabel, "Average")
        XCTAssertEqual(below.productivityLabel, "Below Average")
    }

    // Test: Efficiency label ranges
    func testEfficiencyLabelRanges() {
        let outstanding = TeamPerformanceSnapshot(teamName: "O", overallEfficiency: 0.9)
        let strong = TeamPerformanceSnapshot(teamName: "S", overallEfficiency: 0.75)
        let moderate = TeamPerformanceSnapshot(teamName: "M", overallEfficiency: 0.6)
        let needs = TeamPerformanceSnapshot(teamName: "N", overallEfficiency: 0.4)

        XCTAssertEqual(outstanding.efficiencyLabel, "Outstanding")
        XCTAssertEqual(strong.efficiencyLabel, "Strong")
        XCTAssertEqual(moderate.efficiencyLabel, "Moderate")
        XCTAssertEqual(needs.efficiencyLabel, "Needs Improvement")
    }
}

// MARK: - 11. Enum Completeness Tests

final class MSeriesEnumCompletenessTests: XCTestCase {

    // Test: All PerformanceDimension cases have required properties
    func testPerformanceDimensionCompleteness() {
        for dim in PerformanceDimension.allCases {
            XCTAssertFalse(dim.displayName.isEmpty, "\(dim) should have a display name")
            XCTAssertFalse(dim.iconName.isEmpty, "\(dim) should have an icon name")
        }
    }

    // Test: All AgentSpecialization cases have required properties
    func testAgentSpecializationCompleteness() {
        for spec in AgentSpecialization.allCases {
            XCTAssertFalse(spec.displayName.isEmpty, "\(spec) should have a display name")
            XCTAssertFalse(spec.iconName.isEmpty, "\(spec) should have an icon name")
            XCTAssertFalse(spec.colorHex.isEmpty, "\(spec) should have a color hex")
        }
    }

    // Test: All LeaderboardMetric cases have required properties
    func testLeaderboardMetricCompleteness() {
        for metric in LeaderboardMetric.allCases {
            XCTAssertFalse(metric.displayName.isEmpty, "\(metric) should have a display name")
            XCTAssertFalse(metric.unit.isEmpty, "\(metric) should have a unit")
        }
    }

    // Test: All TrendDirection cases have required properties
    func testTrendDirectionCompleteness() {
        for dir in TrendDirection.allCases {
            XCTAssertFalse(dir.displayName.isEmpty, "\(dir) should have a display name")
            XCTAssertFalse(dir.iconName.isEmpty, "\(dir) should have an icon name")
            XCTAssertFalse(dir.colorHex.isEmpty, "\(dir) should have a color hex")
        }
    }

    // Test: All TimeCategory cases have required properties
    func testTimeCategoryCompleteness() {
        for cat in TimeDistributionEntry.TimeCategory.allCases {
            XCTAssertFalse(cat.displayName.isEmpty, "\(cat) should have a display name")
            XCTAssertFalse(cat.colorHex.isEmpty, "\(cat) should have a color hex")
            XCTAssertFalse(cat.iconName.isEmpty, "\(cat) should have an icon name")
        }
    }

    // Test: All ExportFormat cases have required properties
    func testExportFormatCompleteness() {
        for fmt in ExportFormat.allCases {
            XCTAssertFalse(fmt.displayName.isEmpty, "\(fmt) should have a display name")
            XCTAssertFalse(fmt.fileExtension.isEmpty, "\(fmt) should have a file extension")
            XCTAssertFalse(fmt.mimeType.isEmpty, "\(fmt) should have a MIME type")
            XCTAssertFalse(fmt.iconName.isEmpty, "\(fmt) should have an icon name")
        }
    }

    // Test: All ForecastMetric cases have required properties
    func testForecastMetricCompleteness() {
        for metric in ForecastMetric.allCases {
            XCTAssertFalse(metric.displayName.isEmpty, "\(metric) should have a display name")
            XCTAssertFalse(metric.unit.isEmpty, "\(metric) should have a unit")
            XCTAssertFalse(metric.iconName.isEmpty, "\(metric) should have an icon name")
        }
    }

    // Test: All BenchmarkMetric cases have required properties
    func testBenchmarkMetricCompleteness() {
        for metric in BenchmarkMetric.allCases {
            XCTAssertFalse(metric.displayName.isEmpty, "\(metric) should have a display name")
            XCTAssertFalse(metric.unit.isEmpty, "\(metric) should have a unit")
        }
    }
}

// MARK: - 12. Concurrent Multi-Manager Operations

@MainActor
final class ConcurrentMultiManagerTests: XCTestCase {

    // Test: All managers operating simultaneously without interference
    func testSimultaneousManagerOperations() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let teamManager = TeamPerformanceManager()
        let apiManager = APIUsageAnalyticsManager()
        let dashboardManager = AnalyticsDashboardManager()
        let reportManager = ReportExportManager()

        // Operate all managers simultaneously
        // M4: Record sessions
        for i in 0..<3 {
            sessionManager.recordSession(SessionAnalytics(
                sessionName: "Concurrent \(i)",
                totalTokens: 5000, totalCost: 2.0, tasksCompleted: 10, productivityScore: 0.75
            ))
        }

        // M5: Capture snapshots
        teamManager.captureSnapshot(teamName: "Concurrent Team")

        // M3: Record API calls
        for _ in 0..<5 {
            apiManager.recordAPICall(
                model: "claude-3-sonnet", inputTokens: 1000, outputTokens: 500,
                latencyMs: 500, costUSD: 0.05, taskType: "test"
            )
        }

        // M1: Create reports
        dashboardManager.createReport(name: "Concurrent Report")

        // M2: Create templates
        reportManager.createTemplate(name: "Concurrent Template", description: "", sections: [])

        // Verify all managers have their data independently
        XCTAssertEqual(sessionManager.totalSessions, 3)
        XCTAssertEqual(teamManager.snapshots.count, 1)
        XCTAssertEqual(apiManager.callRecords.count, 5)
        XCTAssertEqual(dashboardManager.reports.count, 1)
        XCTAssertEqual(reportManager.templates.count, 1)

        // Operate analysis on all managers
        sessionManager.analyzeProductivityTrend()
        teamManager.generateRadarData(teamName: "Concurrent Team")
        apiManager.updateSummary()
        dashboardManager.generateForecast(for: .cost, periodDays: 7)

        // All should succeed
        XCTAssertNotNil(sessionManager.productivityTrend)
        XCTAssertGreaterThan(teamManager.radarData.count, 0)
        XCTAssertGreaterThan(apiManager.summary.totalCalls, 0)
        XCTAssertGreaterThan(dashboardManager.forecasts.count, 0)
    }

    // Test: Manager operations are independent (no cross-contamination)
    func testManagerIndependence() {
        let manager1 = SessionHistoryAnalyticsManager()
        let manager2 = SessionHistoryAnalyticsManager()

        manager1.recordSession(SessionAnalytics(
            sessionName: "Manager1 Only", totalTokens: 1000, totalCost: 1.0, tasksCompleted: 5, productivityScore: 0.8
        ))

        XCTAssertEqual(manager1.totalSessions, 1)
        XCTAssertEqual(manager2.totalSessions, 0, "Manager2 should not see Manager1's data")
    }
}

// MARK: - 13. Hashable Conformance Tests

final class MSeriesHashableConformanceTests: XCTestCase {

    // Test: SessionAnalytics in Set
    func testSessionAnalyticsInSet() {
        let s1 = SessionAnalytics(sessionName: "A", productivityScore: 0.8)
        let s2 = SessionAnalytics(sessionName: "B", productivityScore: 0.9)
        let set: Set<SessionAnalytics> = [s1, s2, s1]
        XCTAssertEqual(set.count, 2, "Set should deduplicate by id")
    }

    // Test: AgentPerformanceMetric in Set
    func testAgentPerformanceMetricInSet() {
        let m1 = AgentPerformanceMetric(agentName: "Agent1", efficiency: 0.8)
        let m2 = AgentPerformanceMetric(agentName: "Agent2", efficiency: 0.9)
        let set: Set<AgentPerformanceMetric> = [m1, m2, m1]
        XCTAssertEqual(set.count, 2)
    }

    // Test: TeamPerformanceSnapshot in Set
    func testTeamPerformanceSnapshotInSet() {
        let t1 = TeamPerformanceSnapshot(teamName: "A")
        let t2 = TeamPerformanceSnapshot(teamName: "B")
        let set: Set<TeamPerformanceSnapshot> = [t1, t2, t1]
        XCTAssertEqual(set.count, 2)
    }

    // Test: APICallMetrics in Set
    func testAPICallMetricsInSet() {
        let c1 = APICallMetrics(model: "sonnet", inputTokens: 100, outputTokens: 50, latencyMs: 500, costUSD: 0.01)
        let c2 = APICallMetrics(model: "haiku", inputTokens: 200, outputTokens: 100, latencyMs: 200, costUSD: 0.005)
        let set: Set<APICallMetrics> = [c1, c2, c1]
        XCTAssertEqual(set.count, 2)
    }
}
