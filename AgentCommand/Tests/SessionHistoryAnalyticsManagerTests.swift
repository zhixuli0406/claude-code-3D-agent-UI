import XCTest
@testable import AgentCommand

// MARK: - M4: Session History Analytics Manager Tests

@MainActor
final class SessionHistoryAnalyticsManagerTests: XCTestCase {

    private var manager: SessionHistoryAnalyticsManager!

    override func setUp() {
        super.setUp()
        manager = SessionHistoryAnalyticsManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Session Recording

    func testRecordSession() {
        let session = SessionAnalytics(
            sessionName: "Test",
            totalTokens: 5000,
            totalCost: 2.0,
            tasksCompleted: 10
        )
        manager.recordSession(session)
        XCTAssertEqual(manager.sessions.count, 1)
        XCTAssertEqual(manager.sessions.first?.sessionName, "Test")
    }

    func testStartSession() {
        let session = manager.startSession(name: "New Session")
        XCTAssertEqual(manager.sessions.count, 1)
        XCTAssertEqual(session.sessionName, "New Session")
        XCTAssertNil(session.endedAt)
    }

    func testEndSession() {
        let session = manager.startSession(name: "To End")
        manager.endSession(session.id)
        XCTAssertNotNil(manager.sessions.first?.endedAt)
    }

    func testDeleteSession() {
        let session = manager.startSession(name: "To Delete")
        XCTAssertEqual(manager.sessions.count, 1)
        manager.deleteSession(session.id)
        XCTAssertEqual(manager.sessions.count, 0)
    }

    func testSessionInsertionOrder() {
        let s1 = SessionAnalytics(sessionName: "First")
        let s2 = SessionAnalytics(sessionName: "Second")
        manager.recordSession(s1)
        manager.recordSession(s2)
        XCTAssertEqual(manager.sessions.first?.sessionName, "Second")
    }

    func testMaxSessionsCap() {
        for i in 0..<110 {
            manager.recordSession(SessionAnalytics(sessionName: "Session \(i)"))
        }
        XCTAssertLessThanOrEqual(manager.sessions.count, 100)
    }

    // MARK: - Productivity Analysis

    func testAnalyzeProductivityTrendWithFewSessions() {
        manager.recordSession(SessionAnalytics(sessionName: "Only One", productivityScore: 0.8))
        manager.analyzeProductivityTrend()
        // Needs at least 2 sessions
        XCTAssertNil(manager.productivityTrend)
    }

    func testAnalyzeProductivityTrendImproving() {
        // First half: low productivity, second half: high productivity
        let now = Date()
        for i in 0..<10 {
            var session = SessionAnalytics(
                sessionName: "S\(i)",
                startedAt: now.addingTimeInterval(Double(i) * 86400),
                productivityScore: i < 5 ? 0.4 : 0.9
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            manager.recordSession(session)
        }

        manager.analyzeProductivityTrend()
        XCTAssertNotNil(manager.productivityTrend)

        let trend = manager.productivityTrend!
        XCTAssertEqual(trend.dataPoints.count, 10)
        XCTAssertGreaterThan(trend.averageProductivity, 0)
    }

    func testAnalyzeProductivityTrendDeclining() {
        let now = Date()
        for i in 0..<10 {
            var session = SessionAnalytics(
                sessionName: "S\(i)",
                startedAt: now.addingTimeInterval(Double(i) * 86400),
                productivityScore: i < 5 ? 0.9 : 0.3
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            manager.recordSession(session)
        }

        manager.analyzeProductivityTrend()
        XCTAssertNotNil(manager.productivityTrend)
    }

    // MARK: - Session Comparison

    func testCompareSessions() {
        let s1 = SessionAnalytics(sessionName: "A", totalTokens: 5000, totalCost: 2.0, tasksCompleted: 10)
        let s2 = SessionAnalytics(sessionName: "B", totalTokens: 8000, totalCost: 3.5, tasksCompleted: 15)
        manager.recordSession(s1)
        manager.recordSession(s2)

        manager.compareSessions(s1.id, s2.id)
        XCTAssertEqual(manager.comparisons.count, 1)

        let comparison = manager.comparisons.first!
        XCTAssertEqual(comparison.sessionAName, "A")
        XCTAssertEqual(comparison.sessionBName, "B")
        XCTAssertEqual(comparison.metrics.count, 6)
    }

    func testCompareSessionsInvalidId() {
        manager.compareSessions("nonexistent1", "nonexistent2")
        XCTAssertEqual(manager.comparisons.count, 0)
    }

    func testCompareSessionsReplaceExisting() {
        let s1 = SessionAnalytics(sessionName: "A", tasksCompleted: 5)
        let s2 = SessionAnalytics(sessionName: "B", tasksCompleted: 10)
        manager.recordSession(s1)
        manager.recordSession(s2)

        manager.compareSessions(s1.id, s2.id)
        manager.compareSessions(s1.id, s2.id)
        XCTAssertEqual(manager.comparisons.count, 1) // Should replace, not duplicate
    }

    func testDeleteComparison() {
        let s1 = SessionAnalytics(sessionName: "A")
        let s2 = SessionAnalytics(sessionName: "B")
        manager.recordSession(s1)
        manager.recordSession(s2)
        manager.compareSessions(s1.id, s2.id)
        XCTAssertEqual(manager.comparisons.count, 1)

        let comparisonId = manager.comparisons.first!.id
        manager.deleteComparison(comparisonId)
        XCTAssertEqual(manager.comparisons.count, 0)
    }

    func testDeleteSessionRemovesComparisons() {
        let s1 = SessionAnalytics(sessionName: "A")
        let s2 = SessionAnalytics(sessionName: "B")
        manager.recordSession(s1)
        manager.recordSession(s2)
        manager.compareSessions(s1.id, s2.id)
        XCTAssertEqual(manager.comparisons.count, 1)

        manager.deleteSession(s1.id)
        XCTAssertEqual(manager.comparisons.count, 0)
    }

    // MARK: - Time Distribution

    func testGenerateTimeDistribution() {
        let now = Date()
        for i in 0..<5 {
            var session = SessionAnalytics(sessionName: "S\(i)")
            session.endedAt = now.addingTimeInterval(Double(i + 1) * 3600)
            manager.recordSession(session)
        }
        manager.generateTimeDistribution()
        XCTAssertNotNil(manager.currentTimeDistribution)
        XCTAssertEqual(manager.currentTimeDistribution?.entries.count, 6) // All 6 categories
    }

    func testTimeDistributionEmpty() {
        manager.generateTimeDistribution()
        XCTAssertNil(manager.currentTimeDistribution) // No sessions = no data
    }

    // MARK: - Sample Data

    func testLoadSampleData() {
        manager.loadSampleData()
        XCTAssertEqual(manager.sessions.count, 12)
        XCTAssertNotNil(manager.productivityTrend)
        XCTAssertNotNil(manager.currentTimeDistribution)
        XCTAssertGreaterThanOrEqual(manager.comparisons.count, 1)
    }

    // MARK: - Computed Properties

    func testComputedProperties() {
        manager.recordSession(SessionAnalytics(
            sessionName: "A",
            totalTokens: 5000,
            totalCost: 2.0,
            tasksCompleted: 10,
            productivityScore: 0.8
        ))
        manager.recordSession(SessionAnalytics(
            sessionName: "B",
            totalTokens: 3000,
            totalCost: 1.5,
            tasksCompleted: 8,
            productivityScore: 0.6
        ))

        XCTAssertEqual(manager.totalSessions, 2)
        XCTAssertEqual(manager.averageProductivity, 0.7, accuracy: 0.001)
        XCTAssertEqual(manager.totalCostAllSessions, 3.5, accuracy: 0.001)
        XCTAssertEqual(manager.totalTasksAllSessions, 18)
    }

    func testComputedPropertiesEmpty() {
        XCTAssertEqual(manager.totalSessions, 0)
        XCTAssertEqual(manager.averageProductivity, 0)
        XCTAssertEqual(manager.totalCostAllSessions, 0)
        XCTAssertEqual(manager.totalTasksAllSessions, 0)
    }

    // MARK: - IsAnalyzing State

    func testIsAnalyzingToggle() {
        XCTAssertFalse(manager.isAnalyzing)
        manager.analyzeProductivityTrend()
        XCTAssertFalse(manager.isAnalyzing) // Should be false after analysis
    }
}
