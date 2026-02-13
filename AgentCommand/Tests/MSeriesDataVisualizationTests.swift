import XCTest
import SceneKit
@testable import AgentCommand

// MARK: - M-Series Data Visualization Tests
//
// Tests for chart data models, 3D visualization builders,
// and data transformation logic used by M4/M5 chart panels.

// MARK: - Chart Data Model Tests

final class BarChartDataPointTests: XCTestCase {

    func testBarChartDataPointDefaults() {
        let point = BarChartDataPoint(label: "Test", value: 42.0)
        XCTAssertEqual(point.label, "Test")
        XCTAssertEqual(point.value, 42.0)
        XCTAssertEqual(point.formattedValue, "42")
        XCTAssertNil(point.color)
    }

    func testBarChartDataPointCustomFormat() {
        let point = BarChartDataPoint(label: "Cost", value: 12.5, formattedValue: "$12.50")
        XCTAssertEqual(point.formattedValue, "$12.50")
    }

    func testBarChartDataPointWithColor() {
        let point = BarChartDataPoint(label: "X", value: 10, color: .red)
        XCTAssertNotNil(point.color)
    }
}

final class LineChartDataPointTests: XCTestCase {

    func testLineChartDataPointDefaults() {
        let point = LineChartDataPoint(value: 0.75)
        XCTAssertEqual(point.label, "")
        XCTAssertEqual(point.value, 0.75)
        XCTAssertNil(point.color)
    }

    func testLineChartDataPointWithLabel() {
        let point = LineChartDataPoint(label: "01/15", value: 0.85, color: .green)
        XCTAssertEqual(point.label, "01/15")
        XCTAssertNotNil(point.color)
    }
}

final class PieSliceTests: XCTestCase {

    func testPieSliceProperties() {
        let slice = PieSlice(label: "Coding", value: 40.0, color: .green)
        XCTAssertEqual(slice.label, "Coding")
        XCTAssertEqual(slice.value, 40.0)
    }

    func testPieSliceTotalPercentage() {
        let slices = [
            PieSlice(label: "A", value: 50, color: .red),
            PieSlice(label: "B", value: 30, color: .blue),
            PieSlice(label: "C", value: 20, color: .green),
        ]
        let total = slices.reduce(0.0) { $0 + $1.value }
        XCTAssertEqual(total, 100.0)
    }
}

final class RadarChartDimensionTests: XCTestCase {

    func testRadarDimensionClamp() {
        let dim = RadarChartDimension(label: "Speed", value: 1.5)
        XCTAssertEqual(dim.value, 1.0) // Clamped to max 1.0

        let dimNeg = RadarChartDimension(label: "Quality", value: -0.5)
        XCTAssertEqual(dimNeg.value, 0.0) // Clamped to min 0.0
    }

    func testRadarDimensionShortLabel() {
        let dim = RadarChartDimension(label: "Throughput", value: 0.8)
        XCTAssertEqual(dim.shortLabel, "THR")

        let custom = RadarChartDimension(label: "Speed", shortLabel: "SPD", value: 0.9)
        XCTAssertEqual(custom.shortLabel, "SPD")
    }
}

final class StatTrendTests: XCTestCase {

    func testStatTrendImproving() {
        let trend = StatTrend(direction: .improving, percentageChange: 0.15)
        XCTAssertEqual(trend.displayText, "+15%")
        XCTAssertEqual(trend.colorHex, "#4CAF50")
    }

    func testStatTrendDeclining() {
        let trend = StatTrend(direction: .declining, percentageChange: -0.08)
        XCTAssertEqual(trend.displayText, "-8%")
        XCTAssertEqual(trend.colorHex, "#F44336")
    }

    func testStatTrendStable() {
        let trend = StatTrend(direction: .stable, percentageChange: 0.02)
        XCTAssertEqual(trend.displayText, "~2%")
        XCTAssertEqual(trend.colorHex, "#FF9800")
    }
}

// MARK: - 3D Visualization Builder Tests

final class SessionHistoryVisualizationBuilderTests: XCTestCase {

    func testBuildCreatesRootNode() {
        let parentNode = SCNNode()
        let sessions = createSampleSessions(count: 5)

        SessionHistoryVisualizationBuilder.build(
            sessions: sessions,
            trend: nil,
            parentNode: parentNode
        )

        let root = parentNode.childNode(withName: "sessionHistoryVisualization", recursively: true)
        XCTAssertNotNil(root, "Root node should be created")
    }

    func testBuildCreatesSessionHub() {
        let parentNode = SCNNode()
        SessionHistoryVisualizationBuilder.build(
            sessions: createSampleSessions(count: 3),
            trend: nil,
            parentNode: parentNode
        )

        let hub = parentNode.childNode(withName: "sessionHub", recursively: true)
        XCTAssertNotNil(hub, "Analytics hub should be created")
        XCTAssertTrue(hub?.geometry is SCNSphere)
    }

    func testBuildCreatesSessionNodes() {
        let parentNode = SCNNode()
        let sessions = createSampleSessions(count: 5)

        SessionHistoryVisualizationBuilder.build(
            sessions: sessions,
            trend: nil,
            parentNode: parentNode
        )

        // Check that session nodes were created
        for session in sessions.prefix(5) {
            let node = parentNode.childNode(withName: "session_\(session.id)", recursively: true)
            XCTAssertNotNil(node, "Session node should exist for \(session.sessionName)")
        }
    }

    func testBuildWithTrendCreatesTrendLine() {
        let parentNode = SCNNode()
        let trend = createSampleTrend()

        SessionHistoryVisualizationBuilder.build(
            sessions: createSampleSessions(count: 3),
            trend: trend,
            parentNode: parentNode
        )

        // The root node should have more child nodes when trend is provided
        let root = parentNode.childNode(withName: "sessionHistoryVisualization", recursively: false)
        XCTAssertNotNil(root)
        XCTAssertGreaterThan(root?.childNodes.count ?? 0, 3, "Should have hub + sessions + trend dots")
    }

    func testBuildWithTimeDistribution() {
        let parentNode = SCNNode()
        let distribution = createSampleTimeDistribution()

        SessionHistoryVisualizationBuilder.build(
            sessions: createSampleSessions(count: 3),
            trend: nil,
            timeDistribution: distribution,
            parentNode: parentNode
        )

        // Should create time distribution nodes
        let codingNode = parentNode.childNode(withName: "timeDist_coding", recursively: true)
        XCTAssertNotNil(codingNode, "Time distribution node for coding should exist")
    }

    func testBuildCreatesTaskBarChart() {
        let parentNode = SCNNode()
        let sessions = createSampleSessions(count: 5)

        SessionHistoryVisualizationBuilder.build(
            sessions: sessions,
            trend: nil,
            parentNode: parentNode
        )

        // Check for bar chart nodes
        let barNode = parentNode.childNode(withName: "taskBar_\(sessions[0].id)", recursively: true)
        XCTAssertNotNil(barNode, "Task bar chart nodes should be created")
    }

    func testRemoveVisualization() {
        let parentNode = SCNNode()
        SessionHistoryVisualizationBuilder.build(
            sessions: createSampleSessions(count: 3),
            trend: nil,
            parentNode: parentNode
        )

        let before = parentNode.childNode(withName: "sessionHistoryVisualization", recursively: true)
        XCTAssertNotNil(before)

        SessionHistoryVisualizationBuilder.remove(from: parentNode)

        let after = parentNode.childNode(withName: "sessionHistoryVisualization", recursively: true)
        XCTAssertNil(after, "Visualization should be removed")
    }

    func testBuildWithEmptySessionsDoesNotCrash() {
        let parentNode = SCNNode()
        SessionHistoryVisualizationBuilder.build(
            sessions: [],
            trend: nil,
            parentNode: parentNode
        )

        let root = parentNode.childNode(withName: "sessionHistoryVisualization", recursively: true)
        XCTAssertNotNil(root, "Root should still be created even with empty data")
    }

    // MARK: - Helpers

    private func createSampleSessions(count: Int) -> [SessionAnalytics] {
        (0..<count).map { i in
            var session = SessionAnalytics(
                sessionName: "Session \(i)",
                startedAt: Date().addingTimeInterval(-Double(count - i) * 86400),
                totalTokens: Int.random(in: 5000...30000),
                totalCost: Double.random(in: 1.0...5.0),
                tasksCompleted: Int.random(in: 5...25),
                tasksFailed: Int.random(in: 0...3),
                productivityScore: Double.random(in: 0.4...0.95)
            )
            session.endedAt = session.startedAt.addingTimeInterval(3600)
            return session
        }
    }

    private func createSampleTrend() -> ProductivityTrend {
        let points = (0..<10).map { i in
            ProductivityDataPoint(
                date: Date().addingTimeInterval(-Double(9 - i) * 86400),
                productivity: Double.random(in: 0.5...0.9)
            )
        }
        return ProductivityTrend(dataPoints: points, overallTrend: .improving, averageProductivity: 0.72)
    }

    private func createSampleTimeDistribution() -> SessionTimeDistribution {
        let total = 120.0
        let entries = [
            TimeDistributionEntry(category: .coding, minutes: 50, totalMinutes: total),
            TimeDistributionEntry(category: .reviewing, minutes: 25, totalMinutes: total),
            TimeDistributionEntry(category: .debugging, minutes: 20, totalMinutes: total),
            TimeDistributionEntry(category: .testing, minutes: 15, totalMinutes: total),
            TimeDistributionEntry(category: .planning, minutes: 5, totalMinutes: total),
            TimeDistributionEntry(category: .idle, minutes: 5, totalMinutes: total),
        ]
        return SessionTimeDistribution(entries: entries)
    }
}

final class TeamPerformanceVisualizationBuilderTests: XCTestCase {

    func testBuildCreatesRootNode() {
        let parentNode = SCNNode()
        let snapshot = createSampleSnapshot()

        TeamPerformanceVisualizationBuilder.build(
            snapshot: snapshot,
            radarData: nil,
            parentNode: parentNode
        )

        let root = parentNode.childNode(withName: "teamPerformanceVisualization", recursively: true)
        XCTAssertNotNil(root, "Root node should be created")
    }

    func testBuildCreatesPerformanceHub() {
        let parentNode = SCNNode()
        TeamPerformanceVisualizationBuilder.build(
            snapshot: createSampleSnapshot(),
            radarData: nil,
            parentNode: parentNode
        )

        let hub = parentNode.childNode(withName: "performanceHub", recursively: true)
        XCTAssertNotNil(hub, "Performance hub should be created")
        XCTAssertTrue(hub?.geometry is SCNBox)
    }

    func testBuildCreatesEfficiencyRing() {
        let parentNode = SCNNode()
        TeamPerformanceVisualizationBuilder.build(
            snapshot: createSampleSnapshot(),
            radarData: nil,
            parentNode: parentNode
        )

        let ring = parentNode.childNode(withName: "efficiencyRing", recursively: true)
        XCTAssertNotNil(ring, "Efficiency ring should be created")
        XCTAssertTrue(ring?.geometry is SCNTorus)
    }

    func testBuildCreatesMemberColumns() {
        let parentNode = SCNNode()
        let snapshot = createSampleSnapshot()

        TeamPerformanceVisualizationBuilder.build(
            snapshot: snapshot,
            radarData: nil,
            parentNode: parentNode
        )

        for metric in snapshot.memberMetrics.prefix(6) {
            let node = parentNode.childNode(withName: "member_\(metric.agentName)", recursively: true)
            XCTAssertNotNil(node, "Member column should exist for \(metric.agentName)")
        }
    }

    func testBuildWithRadarCreatesRadarDots() {
        let parentNode = SCNNode()
        let radar = createSampleRadarData()

        TeamPerformanceVisualizationBuilder.build(
            snapshot: createSampleSnapshot(),
            radarData: radar,
            parentNode: parentNode
        )

        for dimension in PerformanceDimension.allCases {
            let node = parentNode.childNode(withName: "radar_\(dimension.rawValue)", recursively: true)
            XCTAssertNotNil(node, "Radar dot should exist for \(dimension.displayName)")
        }
    }

    func testBuildWithLeaderboardCreatesPodium() {
        let parentNode = SCNNode()
        let leaderboard = createSampleLeaderboard()

        TeamPerformanceVisualizationBuilder.build(
            snapshot: createSampleSnapshot(),
            radarData: nil,
            leaderboard: leaderboard,
            parentNode: parentNode
        )

        // Check podium nodes exist for top 3
        for rank in 1...3 {
            let node = parentNode.childNode(withName: "podium_\(rank)", recursively: true)
            XCTAssertNotNil(node, "Podium node should exist for rank \(rank)")
        }
    }

    func testBuildCreatesSpecializationOrbit() {
        let parentNode = SCNNode()
        TeamPerformanceVisualizationBuilder.build(
            snapshot: createSampleSnapshot(),
            radarData: nil,
            parentNode: parentNode
        )

        // At least one specialization node should exist
        let specNode = parentNode.childNode(withName: "spec_codeGeneration", recursively: true)
        XCTAssertNotNil(specNode, "Specialization orbit node should be created")
    }

    func testRemoveVisualization() {
        let parentNode = SCNNode()
        TeamPerformanceVisualizationBuilder.build(
            snapshot: createSampleSnapshot(),
            radarData: nil,
            parentNode: parentNode
        )

        TeamPerformanceVisualizationBuilder.remove(from: parentNode)

        let root = parentNode.childNode(withName: "teamPerformanceVisualization", recursively: true)
        XCTAssertNil(root, "Visualization should be removed")
    }

    func testBuildWithNilSnapshotCreatesMinimalStructure() {
        let parentNode = SCNNode()
        TeamPerformanceVisualizationBuilder.build(
            snapshot: nil,
            radarData: nil,
            parentNode: parentNode
        )

        let root = parentNode.childNode(withName: "teamPerformanceVisualization", recursively: true)
        XCTAssertNotNil(root, "Root should still be created with nil snapshot")

        // Hub should not exist
        let hub = parentNode.childNode(withName: "performanceHub", recursively: true)
        XCTAssertNil(hub, "Hub should not be created when snapshot is nil")
    }

    // MARK: - Helpers

    private func createSampleSnapshot() -> TeamPerformanceSnapshot {
        let metrics = [
            AgentPerformanceMetric(agentName: "Dev-1", tasksCompleted: 42, tasksFailed: 3, totalCost: 2.80, efficiency: 0.88, specialization: .codeGeneration),
            AgentPerformanceMetric(agentName: "Rev-1", tasksCompleted: 35, tasksFailed: 2, totalCost: 1.40, efficiency: 0.92, specialization: .codeReview),
            AgentPerformanceMetric(agentName: "Test-1", tasksCompleted: 28, tasksFailed: 4, totalCost: 1.90, efficiency: 0.78, specialization: .testing),
            AgentPerformanceMetric(agentName: "Arch-1", tasksCompleted: 18, tasksFailed: 1, totalCost: 3.50, efficiency: 0.95, specialization: .architecture),
        ]
        return TeamPerformanceSnapshot(
            teamName: "Test Team",
            memberMetrics: metrics,
            overallEfficiency: 0.88,
            totalTasksCompleted: 123,
            totalCost: 9.60
        )
    }

    private func createSampleRadarData() -> TeamRadarData {
        let dimensions = PerformanceDimension.allCases.map {
            RadarDimension(category: $0, value: Double.random(in: 0.4...0.95))
        }
        return TeamRadarData(teamName: "Test Team", dimensions: dimensions)
    }

    private func createSampleLeaderboard() -> TeamLeaderboard {
        let entries = [
            LeaderboardEntry(agentName: "Arch-1", score: 95.0, rank: 1, trend: .improving),
            LeaderboardEntry(agentName: "Rev-1", score: 92.0, rank: 2, trend: .stable),
            LeaderboardEntry(agentName: "Dev-1", score: 88.0, rank: 3, trend: .improving),
        ]
        return TeamLeaderboard(metric: .successRate, entries: entries)
    }
}

// MARK: - Data Transformation Tests

final class DataVisualizationTransformTests: XCTestCase {

    func testSessionToBarChartDataPoints() {
        let sessions = (0..<5).map { i in
            SessionAnalytics(
                sessionName: "S\(i)",
                tasksCompleted: (i + 1) * 5,
                productivityScore: Double(i + 1) * 0.15
            )
        }

        let barData = sessions.map { session in
            BarChartDataPoint(
                label: String(session.sessionName.suffix(2)),
                value: Double(session.tasksCompleted),
                formattedValue: "\(session.tasksCompleted)"
            )
        }

        XCTAssertEqual(barData.count, 5)
        XCTAssertEqual(barData[0].value, 5.0)
        XCTAssertEqual(barData[4].value, 25.0)
    }

    func testProductivityTrendToLineData() {
        let points = (0..<7).map { i in
            ProductivityDataPoint(
                date: Date().addingTimeInterval(-Double(6 - i) * 86400),
                productivity: 0.5 + Double(i) * 0.05
            )
        }

        let lineData = points.map { point in
            LineChartDataPoint(value: point.productivity)
        }

        XCTAssertEqual(lineData.count, 7)
        XCTAssertEqual(lineData[0].value, 0.5)
        XCTAssertEqual(lineData[6].value, 0.8, accuracy: 0.001)
    }

    func testTimeDistributionToPieSlices() {
        let totalMinutes = 100.0
        let entries = [
            TimeDistributionEntry(category: .coding, minutes: 40, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .reviewing, minutes: 20, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .debugging, minutes: 15, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .testing, minutes: 10, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .planning, minutes: 10, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .idle, minutes: 5, totalMinutes: totalMinutes),
        ]

        let slices = entries.map { entry in
            PieSlice(label: entry.category.displayName, value: entry.minutes, color: .white)
        }

        XCTAssertEqual(slices.count, 6)
        let totalValue = slices.reduce(0.0) { $0 + $1.value }
        XCTAssertEqual(totalValue, totalMinutes, accuracy: 0.01)
    }

    func testTeamRadarToChartDimensions() {
        let radar = TeamRadarData(teamName: "Test", dimensions: [
            RadarDimension(category: .speed, value: 0.8),
            RadarDimension(category: .quality, value: 0.9),
            RadarDimension(category: .costEfficiency, value: 0.7),
            RadarDimension(category: .reliability, value: 0.85),
            RadarDimension(category: .collaboration, value: 0.6),
            RadarDimension(category: .throughput, value: 0.75),
        ])

        let chartDims = radar.dimensions.map { dim in
            RadarChartDimension(label: dim.name, value: dim.value)
        }

        XCTAssertEqual(chartDims.count, 6)
        XCTAssertEqual(chartDims[0].value, 0.8)
        XCTAssertEqual(chartDims[1].value, 0.9)
    }

    func testMemberMetricsToBarChart() {
        let metrics = [
            AgentPerformanceMetric(agentName: "Dev-1", efficiency: 0.88),
            AgentPerformanceMetric(agentName: "Rev-1", efficiency: 0.92),
            AgentPerformanceMetric(agentName: "Test-1", efficiency: 0.78),
        ]

        let sorted = metrics.sorted { $0.efficiency > $1.efficiency }
        let barData = sorted.map { metric in
            BarChartDataPoint(
                label: String(metric.agentName.prefix(6)),
                value: metric.efficiency * 100,
                formattedValue: "\(metric.efficiencyPercentage)%"
            )
        }

        XCTAssertEqual(barData[0].label, "Rev-1")
        XCTAssertEqual(barData[0].value, 92.0, accuracy: 0.1)
        XCTAssertEqual(barData[2].label, "Test-1")
    }

    func testSpecializationDistributionToPieSlices() {
        let metrics = [
            AgentPerformanceMetric(agentName: "A", specialization: .codeGeneration),
            AgentPerformanceMetric(agentName: "B", specialization: .codeGeneration),
            AgentPerformanceMetric(agentName: "C", specialization: .codeReview),
            AgentPerformanceMetric(agentName: "D", specialization: .testing),
        ]

        let groups = Dictionary(grouping: metrics, by: \.specialization)
        let slices = groups.map { spec, members in
            PieSlice(label: spec.displayName, value: Double(members.count), color: .white)
        }.sorted { $0.value > $1.value }

        XCTAssertEqual(slices[0].label, "Code Generation")
        XCTAssertEqual(slices[0].value, 2.0)
    }
}

// MARK: - AppState Chart Toggle Tests

@MainActor
final class AppStateChartToggleTests: XCTestCase {

    func testSessionHistoryChartsToggle() {
        let appState = AppState()
        XCTAssertFalse(appState.isSessionHistoryChartsVisible)

        appState.toggleSessionHistoryCharts()
        XCTAssertTrue(appState.isSessionHistoryChartsVisible)

        appState.toggleSessionHistoryCharts()
        XCTAssertFalse(appState.isSessionHistoryChartsVisible)
    }

    func testTeamPerformanceChartsToggle() {
        let appState = AppState()
        XCTAssertFalse(appState.isTeamPerformanceChartsVisible)

        appState.toggleTeamPerformanceCharts()
        XCTAssertTrue(appState.isTeamPerformanceChartsVisible)

        appState.toggleTeamPerformanceCharts()
        XCTAssertFalse(appState.isTeamPerformanceChartsVisible)
    }
}
