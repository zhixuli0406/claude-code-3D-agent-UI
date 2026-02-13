import XCTest
@testable import AgentCommand

// MARK: - M4: Session History Analytics Models Tests

final class SessionAnalyticsTests: XCTestCase {

    // MARK: - SessionAnalytics

    func testSessionAnalyticsInit() {
        let session = SessionAnalytics(
            sessionName: "Test Session",
            totalTokens: 10000,
            totalCost: 5.0,
            tasksCompleted: 20,
            tasksFailed: 2,
            agentsUsed: 3,
            dominantModel: "opus",
            averageLatencyMs: 1500,
            peakTokenRate: 500,
            productivityScore: 0.85
        )

        XCTAssertEqual(session.sessionName, "Test Session")
        XCTAssertEqual(session.totalTokens, 10000)
        XCTAssertEqual(session.totalCost, 5.0)
        XCTAssertEqual(session.tasksCompleted, 20)
        XCTAssertEqual(session.tasksFailed, 2)
        XCTAssertEqual(session.agentsUsed, 3)
        XCTAssertEqual(session.dominantModel, "opus")
        XCTAssertEqual(session.averageLatencyMs, 1500)
        XCTAssertEqual(session.peakTokenRate, 500)
        XCTAssertEqual(session.productivityScore, 0.85)
        XCTAssertFalse(session.id.isEmpty)
    }

    func testSessionAnalyticsSuccessRate() {
        let session = SessionAnalytics(
            sessionName: "SR Test",
            tasksCompleted: 18,
            tasksFailed: 2
        )
        XCTAssertEqual(session.successRate, 0.9, accuracy: 0.001)
        XCTAssertEqual(session.successRatePercentage, 90)
    }

    func testSessionAnalyticsSuccessRateNoTasks() {
        let session = SessionAnalytics(sessionName: "Empty")
        XCTAssertEqual(session.successRate, 0)
    }

    func testSessionAnalyticsDuration() {
        var session = SessionAnalytics(sessionName: "Duration Test")
        XCTAssertNil(session.duration)
        XCTAssertEqual(session.formattedDuration, "In Progress")

        session.endedAt = session.startedAt.addingTimeInterval(7200) // 2 hours
        XCTAssertEqual(session.duration!, 7200, accuracy: 1.0)
        XCTAssertEqual(session.formattedDuration, "2h 0m")
    }

    func testSessionAnalyticsDurationMinutesOnly() {
        var session = SessionAnalytics(sessionName: "Short")
        session.endedAt = session.startedAt.addingTimeInterval(1500) // 25 minutes
        XCTAssertEqual(session.formattedDuration, "25m")
    }

    func testSessionAnalyticsFormattedCost() {
        let session = SessionAnalytics(sessionName: "Cost", totalCost: 12.345)
        XCTAssertEqual(session.formattedCost, "$12.35")
    }

    func testSessionAnalyticsProductivityLabel() {
        let excellent = SessionAnalytics(sessionName: "A", productivityScore: 0.9)
        XCTAssertEqual(excellent.productivityLabel, "Excellent")
        XCTAssertEqual(excellent.productivityColorHex, "#4CAF50")

        let good = SessionAnalytics(sessionName: "B", productivityScore: 0.7)
        XCTAssertEqual(good.productivityLabel, "Good")

        let avg = SessionAnalytics(sessionName: "C", productivityScore: 0.5)
        XCTAssertEqual(avg.productivityLabel, "Average")

        let below = SessionAnalytics(sessionName: "D", productivityScore: 0.3)
        XCTAssertEqual(below.productivityLabel, "Below Average")
    }

    func testSessionAnalyticsCodableRoundTrip() throws {
        var session = SessionAnalytics(
            sessionName: "Codable Test",
            totalTokens: 5000,
            totalCost: 2.50,
            tasksCompleted: 10,
            productivityScore: 0.75
        )
        session.endedAt = session.startedAt.addingTimeInterval(3600)

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(SessionAnalytics.self, from: data)

        XCTAssertEqual(decoded.sessionName, "Codable Test")
        XCTAssertEqual(decoded.totalTokens, 5000)
        XCTAssertEqual(decoded.totalCost, 2.50)
        XCTAssertEqual(decoded.tasksCompleted, 10)
        XCTAssertEqual(decoded.productivityScore, 0.75)
        XCTAssertNotNil(decoded.endedAt)
    }

    // MARK: - ProductivityTrend

    func testProductivityTrendInit() {
        let dataPoints = [
            ProductivityDataPoint(date: Date(), productivity: 0.7),
            ProductivityDataPoint(date: Date(), productivity: 0.8),
        ]
        let trend = ProductivityTrend(
            dataPoints: dataPoints,
            overallTrend: .improving,
            averageProductivity: 0.75
        )
        XCTAssertEqual(trend.dataPoints.count, 2)
        XCTAssertEqual(trend.overallTrend, .improving)
        XCTAssertEqual(trend.averageProductivity, 0.75)
        XCTAssertEqual(trend.averagePercentage, 75)
    }

    // MARK: - TrendDirection

    func testTrendDirectionProperties() {
        XCTAssertEqual(TrendDirection.improving.displayName, "Improving")
        XCTAssertEqual(TrendDirection.stable.displayName, "Stable")
        XCTAssertEqual(TrendDirection.declining.displayName, "Declining")

        XCTAssertFalse(TrendDirection.improving.iconName.isEmpty)
        XCTAssertFalse(TrendDirection.improving.colorHex.isEmpty)
    }

    func testTrendDirectionAllCases() {
        XCTAssertEqual(TrendDirection.allCases.count, 3)
    }

    // MARK: - SessionComparison

    func testSessionComparison() {
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
        XCTAssertEqual(comparison.sessionAName, "Session A")
        XCTAssertEqual(comparison.sessionBName, "Session B")
        XCTAssertEqual(comparison.metrics.count, 6)
    }

    func testComparisonMetricDelta() {
        let metric = ComparisonMetric(name: "Tasks", valueA: 20, valueB: 30, unit: "tasks")
        XCTAssertEqual(metric.delta, 10)
        XCTAssertEqual(metric.deltaPercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(metric.deltaDisplay, "+50%")
    }

    func testComparisonMetricNegativeDelta() {
        let metric = ComparisonMetric(name: "Cost", valueA: 10, valueB: 5, unit: "USD")
        XCTAssertEqual(metric.delta, -5)
        XCTAssertEqual(metric.deltaDisplay, "-50%")
    }

    func testComparisonMetricZeroDivision() {
        let metric = ComparisonMetric(name: "Zero", valueA: 0, valueB: 5, unit: "x")
        XCTAssertEqual(metric.deltaPercentage, 0)
    }

    // MARK: - SessionTimeDistribution

    func testTimeDistribution() {
        let entries = [
            TimeDistributionEntry(category: .coding, minutes: 60, totalMinutes: 100),
            TimeDistributionEntry(category: .reviewing, minutes: 20, totalMinutes: 100),
            TimeDistributionEntry(category: .debugging, minutes: 20, totalMinutes: 100),
        ]
        let dist = SessionTimeDistribution(entries: entries)
        XCTAssertEqual(dist.entries.count, 3)
        XCTAssertEqual(dist.totalMinutes, 100)
    }

    func testTimeDistributionPercentage() {
        let entry = TimeDistributionEntry(category: .coding, minutes: 45, totalMinutes: 100)
        XCTAssertEqual(entry.percentage, 0.45, accuracy: 0.001)
        XCTAssertEqual(entry.percentageDisplay, 45)
    }

    func testTimeDistributionZeroTotal() {
        let entry = TimeDistributionEntry(category: .idle, minutes: 0, totalMinutes: 0)
        XCTAssertEqual(entry.percentage, 0)
    }

    // MARK: - TimeCategory

    func testTimeCategoryAllCases() {
        XCTAssertEqual(TimeDistributionEntry.TimeCategory.allCases.count, 6)
        for category in TimeDistributionEntry.TimeCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.colorHex.isEmpty)
            XCTAssertFalse(category.iconName.isEmpty)
        }
    }

    // MARK: - ProductivityDataPoint

    func testProductivityDataPointCodable() throws {
        let point = ProductivityDataPoint(
            date: Date(),
            productivity: 0.85,
            tasksCompleted: 15,
            tokensUsed: 8000,
            cost: 1.50
        )

        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(ProductivityDataPoint.self, from: data)

        XCTAssertEqual(decoded.productivity, 0.85)
        XCTAssertEqual(decoded.tasksCompleted, 15)
        XCTAssertEqual(decoded.tokensUsed, 8000)
        XCTAssertEqual(decoded.cost, 1.50)
    }

    // MARK: - Hashable Conformance

    func testSessionAnalyticsHashable() {
        let sessionA = SessionAnalytics(sessionName: "A")
        let sessionB = SessionAnalytics(sessionName: "B")
        let set: Set<SessionAnalytics> = [sessionA, sessionB]
        XCTAssertEqual(set.count, 2)
    }
}
