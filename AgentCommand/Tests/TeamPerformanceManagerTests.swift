import XCTest
@testable import AgentCommand

// MARK: - M5: Team Performance Manager Tests

@MainActor
final class TeamPerformanceManagerTests: XCTestCase {

    private var manager: TeamPerformanceManager!

    override func setUp() {
        super.setUp()
        manager = TeamPerformanceManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Snapshot Management

    func testCaptureSnapshot() {
        manager.captureSnapshot(teamName: "Alpha Team")
        XCTAssertEqual(manager.snapshots.count, 1)
        XCTAssertEqual(manager.snapshots.first?.teamName, "Alpha Team")
        XCTAssertGreaterThan(manager.snapshots.first?.memberMetrics.count ?? 0, 0)
    }

    func testCaptureSnapshotGeneratesSampleMetricsWhenNoAppState() {
        manager.captureSnapshot(teamName: "Test")
        let snapshot = manager.snapshots.first
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.memberMetrics.count, 5) // Sample metrics count
    }

    func testDeleteSnapshot() {
        manager.captureSnapshot(teamName: "To Delete")
        XCTAssertEqual(manager.snapshots.count, 1)
        let id = manager.snapshots.first!.id
        manager.deleteSnapshot(id)
        XCTAssertEqual(manager.snapshots.count, 0)
    }

    func testMaxSnapshotsCap() {
        for i in 0..<55 {
            manager.captureSnapshot(teamName: "Team \(i)")
        }
        XCTAssertLessThanOrEqual(manager.snapshots.count, 50)
    }

    func testSnapshotInsertionOrder() {
        manager.captureSnapshot(teamName: "First")
        manager.captureSnapshot(teamName: "Second")
        XCTAssertEqual(manager.snapshots.first?.teamName, "Second")
    }

    // MARK: - Radar Analysis

    func testGenerateRadarData() {
        manager.captureSnapshot(teamName: "Alpha")
        manager.generateRadarData(teamName: "Alpha")
        XCTAssertEqual(manager.radarData.count, 1)

        let radar = manager.radarData.first!
        XCTAssertEqual(radar.teamName, "Alpha")
        XCTAssertEqual(radar.dimensions.count, 6) // All PerformanceDimension cases
    }

    func testGenerateRadarDataReplaceExisting() {
        manager.captureSnapshot(teamName: "Alpha")
        manager.generateRadarData(teamName: "Alpha")
        manager.generateRadarData(teamName: "Alpha")
        XCTAssertEqual(manager.radarData.count, 1) // Should replace, not duplicate
    }

    func testGenerateRadarDataNoSnapshot() {
        manager.generateRadarData(teamName: "Nonexistent")
        XCTAssertEqual(manager.radarData.count, 0)
    }

    func testRadarDimensionValues() {
        manager.captureSnapshot(teamName: "Alpha")
        manager.generateRadarData(teamName: "Alpha")

        let radar = manager.radarData.first!
        for dim in radar.dimensions {
            XCTAssertGreaterThanOrEqual(dim.value, 0)
            XCTAssertLessThanOrEqual(dim.value, 1.0)
        }
    }

    // MARK: - Leaderboard

    func testGenerateLeaderboard() {
        manager.captureSnapshot(teamName: "Alpha")
        manager.generateLeaderboard(metric: .tasksCompleted)
        XCTAssertEqual(manager.leaderboards.count, 1)

        let board = manager.leaderboards.first!
        XCTAssertEqual(board.metric, .tasksCompleted)
        XCTAssertGreaterThan(board.entries.count, 0)
    }

    func testGenerateLeaderboardAllMetrics() {
        manager.captureSnapshot(teamName: "Alpha")
        for metric in LeaderboardMetric.allCases {
            manager.generateLeaderboard(metric: metric)
        }
        XCTAssertEqual(manager.leaderboards.count, LeaderboardMetric.allCases.count)
    }

    func testGenerateLeaderboardReplaceExisting() {
        manager.captureSnapshot(teamName: "Alpha")
        manager.generateLeaderboard(metric: .successRate)
        manager.generateLeaderboard(metric: .successRate)
        XCTAssertEqual(manager.leaderboards.count, 1) // Should replace
    }

    func testGenerateLeaderboardNoSnapshot() {
        manager.generateLeaderboard(metric: .tasksCompleted)
        XCTAssertEqual(manager.leaderboards.count, 0)
    }

    func testLeaderboardSorting() {
        manager.captureSnapshot(teamName: "Alpha")
        manager.generateLeaderboard(metric: .tasksCompleted)

        let board = manager.leaderboards.first!
        // Entries should be sorted by score descending
        for i in 1..<board.entries.count {
            XCTAssertGreaterThanOrEqual(board.entries[i-1].score, board.entries[i].score)
        }
    }

    // MARK: - Sample Data

    func testLoadSampleData() {
        manager.loadSampleData()
        XCTAssertEqual(manager.snapshots.count, 1)
        XCTAssertEqual(manager.snapshots.first?.teamName, "Alpha Team")
        XCTAssertGreaterThanOrEqual(manager.radarData.count, 1)
        XCTAssertGreaterThanOrEqual(manager.leaderboards.count, 3)
    }

    func testSampleDataMemberMetrics() {
        manager.loadSampleData()
        let snapshot = manager.snapshots.first!
        XCTAssertEqual(snapshot.memberMetrics.count, 5)

        for metric in snapshot.memberMetrics {
            XCTAssertFalse(metric.agentName.isEmpty)
            XCTAssertGreaterThan(metric.tasksCompleted, 0)
            XCTAssertGreaterThan(metric.totalCost, 0)
        }
    }

    // MARK: - Computed Properties

    func testLatestSnapshot() {
        manager.captureSnapshot(teamName: "First")
        manager.captureSnapshot(teamName: "Second")
        XCTAssertEqual(manager.latestSnapshot?.teamName, "Second")
    }

    func testTopPerformer() {
        manager.loadSampleData()
        let top = manager.topPerformer
        XCTAssertNotNil(top)
        // Top performer should have the highest efficiency
        let maxEfficiency = manager.snapshots.first!.memberMetrics.max(by: { $0.efficiency < $1.efficiency })?.efficiency ?? 0
        XCTAssertEqual(top?.efficiency, maxEfficiency)
    }

    func testAverageTeamEfficiency() {
        manager.captureSnapshot(teamName: "A")
        manager.captureSnapshot(teamName: "B")
        let avg = manager.averageTeamEfficiency
        XCTAssertGreaterThan(avg, 0)
        XCTAssertLessThanOrEqual(avg, 1.0)
    }

    func testAverageTeamEfficiencyEmpty() {
        XCTAssertEqual(manager.averageTeamEfficiency, 0)
    }

    // MARK: - IsAnalyzing State

    func testIsAnalyzingDuringCapture() {
        XCTAssertFalse(manager.isAnalyzing)
        manager.captureSnapshot(teamName: "Test")
        XCTAssertFalse(manager.isAnalyzing) // Should be false after capture
    }

    func testIsAnalyzingDuringLeaderboard() {
        manager.captureSnapshot(teamName: "Test")
        XCTAssertFalse(manager.isAnalyzing)
        manager.generateLeaderboard(metric: .speed)
        XCTAssertFalse(manager.isAnalyzing) // Should be false after generation
    }
}
