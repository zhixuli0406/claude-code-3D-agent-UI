import Foundation
import Combine

// MARK: - M5: Team Performance Manager

@MainActor
class TeamPerformanceManager: ObservableObject {
    @Published var snapshots: [TeamPerformanceSnapshot] = []
    @Published var radarData: [TeamRadarData] = []
    @Published var leaderboards: [TeamLeaderboard] = []
    @Published var isAnalyzing: Bool = false

    private static let maxSnapshots = 50
    private static let maxLeaderboards = 10

    weak var appState: AppState?

    // MARK: - Snapshot Management

    /// Capture a performance snapshot from current agents
    func captureSnapshot(teamName: String) {
        isAnalyzing = true

        var memberMetrics: [AgentPerformanceMetric] = []

        if let appState = appState {
            for agent in appState.agents.prefix(8) {
                let tasksForAgent = appState.tasks.filter { $0.assignedAgentId == agent.id }
                let completed = tasksForAgent.filter { $0.status == .completed }.count
                let failed = tasksForAgent.filter { $0.status == .failed }.count
                let tokens = Int.random(in: 5000...50000)
                let cost = Double(tokens) * 0.00002
                let latency = Double.random(in: 500...3000)
                let efficiency = completed > 0 ? min(1.0, Double(completed) / max(1, Double(completed + failed)) * (1.0 - latency / 10000)) : 0.3

                let spec = detectSpecialization(from: tasksForAgent)

                memberMetrics.append(AgentPerformanceMetric(
                    agentName: agent.name,
                    role: agent.role.rawValue,
                    tasksCompleted: completed,
                    tasksFailed: failed,
                    averageLatencyMs: latency,
                    totalTokens: tokens,
                    totalCost: cost,
                    efficiency: efficiency,
                    specialization: spec
                ))
            }
        }

        if memberMetrics.isEmpty {
            memberMetrics = generateSampleMetrics()
        }

        let totalCompleted = memberMetrics.reduce(0) { $0 + $1.tasksCompleted }
        let totalCostVal = memberMetrics.reduce(0.0) { $0 + $1.totalCost }
        let avgResponse = memberMetrics.isEmpty ? 0 : memberMetrics.reduce(0.0) { $0 + $1.averageLatencyMs } / Double(memberMetrics.count)
        let avgEfficiency = memberMetrics.isEmpty ? 0 : memberMetrics.reduce(0.0) { $0 + $1.efficiency } / Double(memberMetrics.count)

        let snapshot = TeamPerformanceSnapshot(
            teamName: teamName,
            memberMetrics: memberMetrics,
            overallEfficiency: avgEfficiency,
            totalTasksCompleted: totalCompleted,
            totalCost: totalCostVal,
            averageResponseTime: avgResponse
        )

        snapshots.insert(snapshot, at: 0)
        if snapshots.count > Self.maxSnapshots {
            snapshots = Array(snapshots.prefix(Self.maxSnapshots))
        }

        isAnalyzing = false
    }

    /// Delete a snapshot
    func deleteSnapshot(_ snapshotId: String) {
        snapshots.removeAll { $0.id == snapshotId }
    }

    // MARK: - Radar Analysis

    /// Generate radar chart data for a team
    func generateRadarData(teamName: String) {
        guard let snapshot = snapshots.first(where: { $0.teamName == teamName }) ?? snapshots.first else { return }

        let members = snapshot.memberMetrics
        guard !members.isEmpty else { return }

        let avgLatency = members.reduce(0.0) { $0 + $1.averageLatencyMs } / Double(members.count)
        let avgSuccessRate = members.reduce(0.0) { $0 + $1.successRate } / Double(members.count)
        let avgEfficiency = members.reduce(0.0) { $0 + $1.efficiency } / Double(members.count)
        let totalTasks = members.reduce(0) { $0 + $1.tasksCompleted }
        let avgCostPerTask = members.reduce(0.0) { $0 + $1.costPerTask } / Double(members.count)

        let dimensions = [
            RadarDimension(category: .speed, value: min(1.0, max(0, 1.0 - avgLatency / 5000))),
            RadarDimension(category: .quality, value: avgSuccessRate),
            RadarDimension(category: .costEfficiency, value: min(1.0, max(0, 1.0 - avgCostPerTask / 0.2))),
            RadarDimension(category: .reliability, value: avgEfficiency),
            RadarDimension(category: .collaboration, value: min(1.0, Double(members.count) / 6.0)),
            RadarDimension(category: .throughput, value: min(1.0, Double(totalTasks) / 100.0)),
        ]

        let radar = TeamRadarData(teamName: teamName, dimensions: dimensions)

        if let existingIdx = radarData.firstIndex(where: { $0.teamName == teamName }) {
            radarData[existingIdx] = radar
        } else {
            radarData.append(radar)
        }
    }

    // MARK: - Leaderboard

    /// Generate a leaderboard for a specific metric
    func generateLeaderboard(metric: LeaderboardMetric) {
        isAnalyzing = true

        guard let snapshot = snapshots.first else {
            isAnalyzing = false
            return
        }

        let sortedMembers: [(String, Double)]

        switch metric {
        case .tasksCompleted:
            sortedMembers = snapshot.memberMetrics.map { ($0.agentName, Double($0.tasksCompleted)) }
                .sorted { $0.1 > $1.1 }
        case .successRate:
            sortedMembers = snapshot.memberMetrics.map { ($0.agentName, $0.successRate * 100) }
                .sorted { $0.1 > $1.1 }
        case .costEfficiency:
            sortedMembers = snapshot.memberMetrics
                .filter { $0.totalCost > 0 }
                .map { ($0.agentName, Double($0.tasksCompleted) / $0.totalCost) }
                .sorted { $0.1 > $1.1 }
        case .speed:
            sortedMembers = snapshot.memberMetrics.map { ($0.agentName, 10000.0 - $0.averageLatencyMs) }
                .sorted { $0.1 > $1.1 }
        case .tokensUsed:
            sortedMembers = snapshot.memberMetrics.map { ($0.agentName, Double($0.totalTokens)) }
                .sorted { $0.1 > $1.1 }
        }

        let entries = sortedMembers.enumerated().map { index, pair in
            LeaderboardEntry(
                agentName: pair.0,
                score: pair.1,
                rank: index + 1,
                trend: [TrendDirection.improving, .stable, .declining].randomElement() ?? .stable
            )
        }

        let leaderboard = TeamLeaderboard(metric: metric, entries: entries)

        if let existingIdx = leaderboards.firstIndex(where: { $0.metric == metric }) {
            leaderboards[existingIdx] = leaderboard
        } else {
            leaderboards.append(leaderboard)
        }

        if leaderboards.count > Self.maxLeaderboards {
            leaderboards = Array(leaderboards.prefix(Self.maxLeaderboards))
        }

        isAnalyzing = false
    }

    // MARK: - Sample Data

    func loadSampleData() {
        let sampleMetrics = generateSampleMetrics()

        let totalCompleted = sampleMetrics.reduce(0) { $0 + $1.tasksCompleted }
        let totalCostVal = sampleMetrics.reduce(0.0) { $0 + $1.totalCost }
        let avgResponse = sampleMetrics.reduce(0.0) { $0 + $1.averageLatencyMs } / Double(sampleMetrics.count)
        let avgEfficiency = sampleMetrics.reduce(0.0) { $0 + $1.efficiency } / Double(sampleMetrics.count)

        let snapshot = TeamPerformanceSnapshot(
            teamName: "Alpha Team",
            memberMetrics: sampleMetrics,
            overallEfficiency: avgEfficiency,
            totalTasksCompleted: totalCompleted,
            totalCost: totalCostVal,
            averageResponseTime: avgResponse
        )
        snapshots = [snapshot]

        generateRadarData(teamName: "Alpha Team")

        for metric in [LeaderboardMetric.tasksCompleted, .successRate, .costEfficiency] {
            generateLeaderboard(metric: metric)
        }
    }

    // MARK: - Computed Properties

    var latestSnapshot: TeamPerformanceSnapshot? { snapshots.first }

    var topPerformer: AgentPerformanceMetric? {
        snapshots.first?.memberMetrics.max(by: { $0.efficiency < $1.efficiency })
    }

    var averageTeamEfficiency: Double {
        guard !snapshots.isEmpty else { return 0 }
        return snapshots.reduce(0.0) { $0 + $1.overallEfficiency } / Double(snapshots.count)
    }

    // MARK: - Private Helpers

    private func generateSampleMetrics() -> [AgentPerformanceMetric] {
        [
            AgentPerformanceMetric(agentName: "Developer-1", role: "developer", tasksCompleted: 42, tasksFailed: 3, averageLatencyMs: 1850, totalTokens: 45000, totalCost: 2.80, efficiency: 0.88, specialization: .codeGeneration),
            AgentPerformanceMetric(agentName: "Reviewer-1", role: "reviewer", tasksCompleted: 35, tasksFailed: 2, averageLatencyMs: 1200, totalTokens: 28000, totalCost: 1.40, efficiency: 0.92, specialization: .codeReview),
            AgentPerformanceMetric(agentName: "Tester-1", role: "tester", tasksCompleted: 28, tasksFailed: 4, averageLatencyMs: 2100, totalTokens: 32000, totalCost: 1.90, efficiency: 0.78, specialization: .testing),
            AgentPerformanceMetric(agentName: "Architect-1", role: "architect", tasksCompleted: 18, tasksFailed: 1, averageLatencyMs: 3200, totalTokens: 52000, totalCost: 3.50, efficiency: 0.95, specialization: .architecture),
            AgentPerformanceMetric(agentName: "Debugger-1", role: "developer", tasksCompleted: 22, tasksFailed: 5, averageLatencyMs: 2800, totalTokens: 38000, totalCost: 2.20, efficiency: 0.72, specialization: .debugging),
        ]
    }

    private func detectSpecialization(from tasks: [AgentTask]) -> AgentSpecialization {
        // Simple heuristic based on task names
        let taskNames = tasks.map { $0.title.lowercased() }
        if taskNames.contains(where: { $0.contains("test") }) { return .testing }
        if taskNames.contains(where: { $0.contains("review") }) { return .codeReview }
        if taskNames.contains(where: { $0.contains("debug") || $0.contains("fix") }) { return .debugging }
        if taskNames.contains(where: { $0.contains("doc") }) { return .documentation }
        if taskNames.contains(where: { $0.contains("architect") || $0.contains("design") }) { return .architecture }
        return .codeGeneration
    }
}
