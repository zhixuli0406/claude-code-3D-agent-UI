import XCTest
@testable import AgentCommand

// MARK: - M5: Team Performance Models Tests

final class TeamPerformanceModelsTests: XCTestCase {

    // MARK: - TeamPerformanceSnapshot

    func testSnapshotInit() {
        let snapshot = TeamPerformanceSnapshot(
            teamName: "Alpha",
            overallEfficiency: 0.85,
            totalTasksCompleted: 100,
            totalCost: 15.0,
            averageResponseTime: 1500
        )

        XCTAssertEqual(snapshot.teamName, "Alpha")
        XCTAssertEqual(snapshot.overallEfficiency, 0.85)
        XCTAssertEqual(snapshot.totalTasksCompleted, 100)
        XCTAssertEqual(snapshot.totalCost, 15.0)
        XCTAssertEqual(snapshot.averageResponseTime, 1500)
        XCTAssertFalse(snapshot.id.isEmpty)
    }

    func testSnapshotEfficiencyLabels() {
        let outstanding = TeamPerformanceSnapshot(teamName: "A", overallEfficiency: 0.9)
        XCTAssertEqual(outstanding.efficiencyLabel, "Outstanding")
        XCTAssertEqual(outstanding.efficiencyColorHex, "#4CAF50")

        let strong = TeamPerformanceSnapshot(teamName: "B", overallEfficiency: 0.75)
        XCTAssertEqual(strong.efficiencyLabel, "Strong")

        let moderate = TeamPerformanceSnapshot(teamName: "C", overallEfficiency: 0.6)
        XCTAssertEqual(moderate.efficiencyLabel, "Moderate")

        let needsImprovement = TeamPerformanceSnapshot(teamName: "D", overallEfficiency: 0.4)
        XCTAssertEqual(needsImprovement.efficiencyLabel, "Needs Improvement")
    }

    func testSnapshotFormattedCost() {
        let snapshot = TeamPerformanceSnapshot(teamName: "Test", totalCost: 42.567)
        XCTAssertEqual(snapshot.formattedCost, "$42.57")
    }

    func testSnapshotEfficiencyPercentage() {
        let snapshot = TeamPerformanceSnapshot(teamName: "Test", overallEfficiency: 0.78)
        XCTAssertEqual(snapshot.efficiencyPercentage, 78)
    }

    func testSnapshotCodableRoundTrip() throws {
        let metrics = [
            AgentPerformanceMetric(agentName: "Dev-1", tasksCompleted: 10, efficiency: 0.9)
        ]
        let snapshot = TeamPerformanceSnapshot(
            teamName: "Test Team",
            memberMetrics: metrics,
            overallEfficiency: 0.85,
            totalTasksCompleted: 10,
            totalCost: 5.0
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TeamPerformanceSnapshot.self, from: data)

        XCTAssertEqual(decoded.teamName, "Test Team")
        XCTAssertEqual(decoded.memberMetrics.count, 1)
        XCTAssertEqual(decoded.overallEfficiency, 0.85)
    }

    // MARK: - AgentPerformanceMetric

    func testAgentMetricInit() {
        let metric = AgentPerformanceMetric(
            agentName: "Developer-1",
            role: "developer",
            tasksCompleted: 42,
            tasksFailed: 3,
            averageLatencyMs: 1850,
            totalTokens: 45000,
            totalCost: 2.80,
            efficiency: 0.88,
            specialization: .codeGeneration
        )

        XCTAssertEqual(metric.agentName, "Developer-1")
        XCTAssertEqual(metric.role, "developer")
        XCTAssertEqual(metric.tasksCompleted, 42)
        XCTAssertEqual(metric.tasksFailed, 3)
        XCTAssertEqual(metric.specialization, .codeGeneration)
    }

    func testAgentMetricSuccessRate() {
        let metric = AgentPerformanceMetric(
            agentName: "Test",
            tasksCompleted: 9,
            tasksFailed: 1
        )
        XCTAssertEqual(metric.successRate, 0.9, accuracy: 0.001)
        XCTAssertEqual(metric.successRatePercentage, 90)
    }

    func testAgentMetricSuccessRateNoTasks() {
        let metric = AgentPerformanceMetric(agentName: "Empty")
        XCTAssertEqual(metric.successRate, 0)
    }

    func testAgentMetricCostPerTask() {
        let metric = AgentPerformanceMetric(
            agentName: "Test",
            tasksCompleted: 10,
            totalCost: 5.0
        )
        XCTAssertEqual(metric.costPerTask, 0.5, accuracy: 0.001)
        XCTAssertEqual(metric.formattedCostPerTask, "$0.500")
    }

    func testAgentMetricCostPerTaskZero() {
        let metric = AgentPerformanceMetric(agentName: "Empty")
        XCTAssertEqual(metric.costPerTask, 0)
    }

    // MARK: - AgentSpecialization

    func testAgentSpecializationAllCases() {
        XCTAssertEqual(AgentSpecialization.allCases.count, 7)
        for spec in AgentSpecialization.allCases {
            XCTAssertFalse(spec.displayName.isEmpty)
            XCTAssertFalse(spec.iconName.isEmpty)
            XCTAssertFalse(spec.colorHex.isEmpty)
        }
    }

    // MARK: - TeamRadarData

    func testRadarDataInit() {
        let dimensions = PerformanceDimension.allCases.map {
            RadarDimension(category: $0, value: 0.8)
        }
        let radar = TeamRadarData(teamName: "Alpha", dimensions: dimensions)

        XCTAssertEqual(radar.teamName, "Alpha")
        XCTAssertEqual(radar.dimensions.count, PerformanceDimension.allCases.count)
        XCTAssertEqual(radar.averageScore, 0.8, accuracy: 0.001)
    }

    func testRadarDataEmptyDimensions() {
        let radar = TeamRadarData(teamName: "Empty", dimensions: [])
        XCTAssertEqual(radar.averageScore, 0)
    }

    func testRadarDimensionClamping() {
        let overMax = RadarDimension(category: .speed, value: 1.5)
        XCTAssertEqual(overMax.value, 1.0)

        let underMin = RadarDimension(category: .quality, value: -0.5)
        XCTAssertEqual(underMin.value, 0)
    }

    func testRadarDimensionPercentage() {
        let dim = RadarDimension(category: .throughput, value: 0.72)
        XCTAssertEqual(dim.percentage, 72)
    }

    // MARK: - PerformanceDimension

    func testPerformanceDimensionAllCases() {
        XCTAssertEqual(PerformanceDimension.allCases.count, 6)
        for dim in PerformanceDimension.allCases {
            XCTAssertFalse(dim.displayName.isEmpty)
            XCTAssertFalse(dim.iconName.isEmpty)
        }
    }

    // MARK: - TeamLeaderboard

    func testLeaderboardInit() {
        let entries = [
            LeaderboardEntry(agentName: "B", score: 50, rank: 2),
            LeaderboardEntry(agentName: "A", score: 100, rank: 1),
            LeaderboardEntry(agentName: "C", score: 25, rank: 3),
        ]
        let leaderboard = TeamLeaderboard(metric: .tasksCompleted, entries: entries)

        XCTAssertEqual(leaderboard.metric, .tasksCompleted)
        // Should be sorted by score descending
        XCTAssertEqual(leaderboard.entries.first?.agentName, "A")
        XCTAssertEqual(leaderboard.entries.last?.agentName, "C")
    }

    func testLeaderboardEntryFormattedScore() {
        let entry = LeaderboardEntry(agentName: "Test", score: 95.67, rank: 1)
        XCTAssertEqual(entry.formattedScore, "95.7")
    }

    // MARK: - LeaderboardMetric

    func testLeaderboardMetricAllCases() {
        XCTAssertEqual(LeaderboardMetric.allCases.count, 5)
        for metric in LeaderboardMetric.allCases {
            XCTAssertFalse(metric.displayName.isEmpty)
            XCTAssertFalse(metric.unit.isEmpty)
        }
    }

    // MARK: - Codable Round Trips

    func testTeamRadarDataCodable() throws {
        let dimensions = [
            RadarDimension(category: .speed, value: 0.9),
            RadarDimension(category: .quality, value: 0.85),
        ]
        let radar = TeamRadarData(teamName: "Codable", dimensions: dimensions)

        let data = try JSONEncoder().encode(radar)
        let decoded = try JSONDecoder().decode(TeamRadarData.self, from: data)

        XCTAssertEqual(decoded.teamName, "Codable")
        XCTAssertEqual(decoded.dimensions.count, 2)
    }

    func testLeaderboardCodable() throws {
        let entries = [
            LeaderboardEntry(agentName: "A", score: 100, rank: 1, trend: .improving),
        ]
        let board = TeamLeaderboard(metric: .successRate, entries: entries)

        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(TeamLeaderboard.self, from: data)

        XCTAssertEqual(decoded.metric, .successRate)
        XCTAssertEqual(decoded.entries.count, 1)
    }

    // MARK: - Hashable Conformance

    func testSnapshotHashable() {
        let a = TeamPerformanceSnapshot(teamName: "A")
        let b = TeamPerformanceSnapshot(teamName: "B")
        let set: Set<TeamPerformanceSnapshot> = [a, b]
        XCTAssertEqual(set.count, 2)
    }

    func testAgentMetricHashable() {
        let a = AgentPerformanceMetric(agentName: "A")
        let b = AgentPerformanceMetric(agentName: "B")
        let set: Set<AgentPerformanceMetric> = [a, b]
        XCTAssertEqual(set.count, 2)
    }
}
