import XCTest
@testable import AgentCommand

// MARK: - M4/M5 Integration Tests
//
// These tests verify cross-module interactions:
// - M4 (Session History) ↔ M5 (Team Performance)
// - M4 (Session Analytics) ↔ M1 (Analytics Dashboard)
// - M5 (Team Metrics) ↔ M3 (API Usage Analytics)

// MARK: - Session + Team Performance Integration

final class SessionTeamIntegrationTests: XCTestCase {

    // MARK: - Session Comparison + Productivity Trend Consistency

    func testSessionComparisonMetricsMatchSource() {
        let sessionA = SessionAnalytics(
            sessionName: "Session A",
            totalTokens: 10000,
            totalCost: 5.0,
            tasksCompleted: 20,
            tasksFailed: 2,
            averageLatencyMs: 1500,
            productivityScore: 0.8
        )
        let sessionB = SessionAnalytics(
            sessionName: "Session B",
            totalTokens: 15000,
            totalCost: 7.5,
            tasksCompleted: 30,
            tasksFailed: 1,
            averageLatencyMs: 1200,
            productivityScore: 0.9
        )

        let comparison = SessionComparison(sessionA: sessionA, sessionB: sessionB)

        // Tasks Completed metric
        let taskMetric = comparison.metrics.first { $0.name == "Tasks Completed" }
        XCTAssertNotNil(taskMetric)
        XCTAssertEqual(taskMetric?.valueA, 20)
        XCTAssertEqual(taskMetric?.valueB, 30)
        XCTAssertEqual(taskMetric?.delta, 10)

        // Cost metric
        let costMetric = comparison.metrics.first { $0.name == "Cost" }
        XCTAssertNotNil(costMetric)
        XCTAssertEqual(costMetric?.valueA, 5.0)
        XCTAssertEqual(costMetric?.valueB, 7.5)
    }

    func testProductivityTrendDataPointsAreChronological() {
        let now = Date()
        let sessions = (0..<10).map { i in
            var s = SessionAnalytics(
                sessionName: "S\(i)",
                startedAt: now.addingTimeInterval(Double(i) * 86400),
                productivityScore: Double.random(in: 0.5...0.9)
            )
            s.endedAt = s.startedAt.addingTimeInterval(3600)
            return s
        }

        let dataPoints = sessions.map {
            ProductivityDataPoint(date: $0.startedAt, productivity: $0.productivityScore)
        }

        for i in 1..<dataPoints.count {
            XCTAssertGreaterThan(dataPoints[i].date, dataPoints[i-1].date)
        }
    }

    // MARK: - Team Performance Snapshot Consistency

    func testSnapshotMemberMetricsConsistency() {
        let metrics = [
            AgentPerformanceMetric(agentName: "Dev-1", tasksCompleted: 42, tasksFailed: 3, totalCost: 2.80, efficiency: 0.88),
            AgentPerformanceMetric(agentName: "Rev-1", tasksCompleted: 35, tasksFailed: 2, totalCost: 1.40, efficiency: 0.92),
            AgentPerformanceMetric(agentName: "Test-1", tasksCompleted: 28, tasksFailed: 4, totalCost: 1.90, efficiency: 0.78),
        ]

        let totalCompleted = metrics.reduce(0) { $0 + $1.tasksCompleted }
        let totalCost = metrics.reduce(0.0) { $0 + $1.totalCost }
        let avgEfficiency = metrics.reduce(0.0) { $0 + $1.efficiency } / 3.0

        let snapshot = TeamPerformanceSnapshot(
            teamName: "Test",
            memberMetrics: metrics,
            overallEfficiency: avgEfficiency,
            totalTasksCompleted: totalCompleted,
            totalCost: totalCost
        )

        XCTAssertEqual(snapshot.totalTasksCompleted, 105)
        XCTAssertEqual(snapshot.totalCost, 6.10, accuracy: 0.01)
        XCTAssertEqual(snapshot.overallEfficiency, 0.86, accuracy: 0.01)
    }

    // MARK: - Radar Data Dimension Coverage

    func testRadarDataCoversAllDimensions() {
        let dimensions = PerformanceDimension.allCases.map {
            RadarDimension(category: $0, value: Double.random(in: 0.3...1.0))
        }
        let radar = TeamRadarData(teamName: "Full", dimensions: dimensions)

        let categories = Set(radar.dimensions.map(\.category))
        XCTAssertEqual(categories, Set(PerformanceDimension.allCases))
    }

    // MARK: - Leaderboard + Agent Metrics Consistency

    func testLeaderboardReflectsAgentMetrics() {
        let metrics = [
            AgentPerformanceMetric(agentName: "High", tasksCompleted: 50, efficiency: 0.95),
            AgentPerformanceMetric(agentName: "Mid", tasksCompleted: 30, efficiency: 0.75),
            AgentPerformanceMetric(agentName: "Low", tasksCompleted: 10, efficiency: 0.50),
        ]

        let entries = metrics.enumerated().map { index, metric in
            LeaderboardEntry(agentName: metric.agentName, score: Double(metric.tasksCompleted), rank: index + 1)
        }

        let board = TeamLeaderboard(metric: .tasksCompleted, entries: entries)

        // Board should be sorted by score descending
        XCTAssertEqual(board.entries.first?.agentName, "High")
        XCTAssertEqual(board.entries.last?.agentName, "Low")
    }

    // MARK: - Cross-Module Data: Session → Report Data

    func testSessionAnalyticsToReportData() {
        let session = SessionAnalytics(
            sessionName: "Full Session",
            totalTokens: 25000,
            totalCost: 8.50,
            tasksCompleted: 40,
            tasksFailed: 5,
            averageLatencyMs: 1800,
            productivityScore: 0.82
        )

        // Create report-compatible data from session
        let summary = ReportSummary(
            totalTokens: session.totalTokens,
            totalCost: session.totalCost,
            totalTasks: session.tasksCompleted + session.tasksFailed,
            successRate: session.successRate,
            averageLatency: session.averageLatencyMs,
            periodDescription: session.sessionName
        )

        XCTAssertEqual(summary.totalTokens, 25000)
        XCTAssertEqual(summary.totalCost, 8.50)
        XCTAssertEqual(summary.totalTasks, 45)
        XCTAssertEqual(summary.successRate, session.successRate, accuracy: 0.001)
    }

    // MARK: - Cross-Module Data: Team Performance → Cost Breakdown

    func testTeamMetricsToCostBreakdown() {
        let metrics = [
            AgentPerformanceMetric(agentName: "Dev-1", tasksCompleted: 42, totalCost: 2.80),
            AgentPerformanceMetric(agentName: "Rev-1", tasksCompleted: 35, totalCost: 1.40),
            AgentPerformanceMetric(agentName: "Test-1", tasksCompleted: 28, totalCost: 1.90),
        ]

        let totalCost = metrics.reduce(0.0) { $0 + $1.totalCost }
        let entries = metrics.map { metric in
            CostBreakdownEntry(
                category: metric.agentName,
                cost: metric.totalCost,
                tokenCount: metric.totalTokens,
                callCount: metric.tasksCompleted,
                totalCost: totalCost
            )
        }

        let breakdown = CostBreakdown(entries: entries, period: "Team Analysis")
        let totalPercentage = breakdown.entries.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 1.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.totalCost, 6.10, accuracy: 0.01)
    }

    // MARK: - Codable Interop

    func testSessionAndTeamDataCodableInterop() throws {
        let session = SessionAnalytics(
            sessionName: "Codable Test",
            totalTokens: 5000,
            totalCost: 2.50,
            tasksCompleted: 10,
            productivityScore: 0.75
        )

        let snapshot = TeamPerformanceSnapshot(
            teamName: "Codable Team",
            overallEfficiency: 0.85,
            totalTasksCompleted: session.tasksCompleted,
            totalCost: session.totalCost
        )

        let sessionData = try JSONEncoder().encode(session)
        let snapshotData = try JSONEncoder().encode(snapshot)

        let decodedSession = try JSONDecoder().decode(SessionAnalytics.self, from: sessionData)
        let decodedSnapshot = try JSONDecoder().decode(TeamPerformanceSnapshot.self, from: snapshotData)

        XCTAssertEqual(decodedSession.totalCost, decodedSnapshot.totalCost)
        XCTAssertEqual(decodedSession.tasksCompleted, decodedSnapshot.totalTasksCompleted)
    }

    // MARK: - Time Distribution Percentages Sum

    func testTimeDistributionPercentagesSum() {
        let totalMinutes = 120.0
        let entries: [TimeDistributionEntry] = [
            TimeDistributionEntry(category: .coding, minutes: 50, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .reviewing, minutes: 25, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .debugging, minutes: 20, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .testing, minutes: 15, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .planning, minutes: 5, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .idle, minutes: 5, totalMinutes: totalMinutes),
        ]

        let totalPercentage = entries.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 1.0, accuracy: 0.01)
    }
}

// MARK: - Service-Level M4/M5 Integration Tests

@MainActor
final class M4M5ServiceIntegrationTests: XCTestCase {

    // MARK: - SessionHistoryAnalyticsManager Full Workflow

    func testSessionManagerFullWorkflow() {
        let manager = SessionHistoryAnalyticsManager()

        // Start multiple sessions
        for i in 0..<5 {
            var session = SessionAnalytics(
                sessionName: "Session \(i)",
                startedAt: Date().addingTimeInterval(-Double(4 - i) * 86400),
                totalTokens: Int.random(in: 5000...20000),
                totalCost: Double.random(in: 1.0...5.0),
                tasksCompleted: Int.random(in: 5...20),
                productivityScore: Double.random(in: 0.5...0.95)
            )
            session.endedAt = session.startedAt.addingTimeInterval(Double.random(in: 3600...7200))
            manager.recordSession(session)
        }

        XCTAssertEqual(manager.totalSessions, 5)
        XCTAssertGreaterThan(manager.totalCostAllSessions, 0)
        XCTAssertGreaterThan(manager.totalTasksAllSessions, 0)

        // Analyze trend
        manager.analyzeProductivityTrend()
        XCTAssertNotNil(manager.productivityTrend)

        // Compare first two sessions
        let s1 = manager.sessions[0]
        let s2 = manager.sessions[1]
        manager.compareSessions(s1.id, s2.id)
        XCTAssertEqual(manager.comparisons.count, 1)

        // Generate time distribution
        manager.generateTimeDistribution()
        XCTAssertNotNil(manager.currentTimeDistribution)
    }

    // MARK: - TeamPerformanceManager Full Workflow

    func testTeamManagerFullWorkflow() {
        let manager = TeamPerformanceManager()

        // Capture snapshot
        manager.captureSnapshot(teamName: "Integration Team")
        XCTAssertEqual(manager.snapshots.count, 1)

        let snapshot = manager.latestSnapshot!
        XCTAssertGreaterThan(snapshot.memberMetrics.count, 0)
        XCTAssertGreaterThan(snapshot.totalTasksCompleted, 0)
        XCTAssertGreaterThan(snapshot.totalCost, 0)

        // Generate radar
        manager.generateRadarData(teamName: "Integration Team")
        XCTAssertEqual(manager.radarData.count, 1)

        // Generate leaderboards
        for metric in LeaderboardMetric.allCases {
            manager.generateLeaderboard(metric: metric)
        }
        XCTAssertEqual(manager.leaderboards.count, LeaderboardMetric.allCases.count)

        // Top performer should exist
        XCTAssertNotNil(manager.topPerformer)
    }

    // MARK: - Cross-Manager Data Flow

    func testSessionToTeamDataFlow() {
        let sessionManager = SessionHistoryAnalyticsManager()
        let teamManager = TeamPerformanceManager()

        // Record sessions
        for i in 0..<3 {
            let session = SessionAnalytics(
                sessionName: "S\(i)",
                totalTokens: 10000,
                totalCost: 3.0,
                tasksCompleted: 15,
                productivityScore: 0.8
            )
            sessionManager.recordSession(session)
        }

        // Capture team snapshot
        teamManager.captureSnapshot(teamName: "Analysis Team")

        // Both should have data
        XCTAssertEqual(sessionManager.totalSessions, 3)
        XCTAssertEqual(teamManager.snapshots.count, 1)

        // Session total cost and team snapshot cost are independent but valid
        XCTAssertGreaterThan(sessionManager.totalCostAllSessions, 0)
        XCTAssertGreaterThan(teamManager.latestSnapshot?.totalCost ?? 0, 0)
    }
}
