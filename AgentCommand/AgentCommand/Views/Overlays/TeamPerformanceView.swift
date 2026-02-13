import SwiftUI

// MARK: - M5: Team Performance Detail View (Sheet)

struct TeamPerformanceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var selectedLeaderboardMetric: LeaderboardMetric = .tasksCompleted

    private var manager: TeamPerformanceManager {
        appState.teamPerformanceManager
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#FF5722").opacity(0.3))

            TabView(selection: $selectedTab) {
                overviewTab.tag(0)
                membersTab.tag(1)
                radarTab.tag(2)
                leaderboardTab.tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if manager.snapshots.isEmpty {
                manager.loadSampleData()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "person.3.sequence.fill")
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.tpTeamPerformance))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Picker("", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text(localization.localized(.tpMembers)).tag(1)
                Text(localization.localized(.tpRadar)).tag(2)
                Text(localization.localized(.tpLeaderboard)).tag(3)
            }
            .pickerStyle(.segmented)
            .frame(width: 350)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button("Capture Snapshot") {
                    manager.captureSnapshot(teamName: "Alpha Team")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#FF5722"))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if manager.snapshots.isEmpty {
                emptyState(localization.localized(.tpNoSnapshots), icon: "person.3.sequence.fill")
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Latest snapshot summary
                        if let latest = manager.latestSnapshot {
                            latestSnapshotCard(latest)
                        }

                        // Snapshot history
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Snapshot History")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ForEach(manager.snapshots) { snapshot in
                                snapshotRow(snapshot)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func latestSnapshotCard(_ snapshot: TeamPerformanceSnapshot) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(snapshot.teamName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(snapshot.efficiencyLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: snapshot.efficiencyColorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: snapshot.efficiencyColorHex).opacity(0.15))
                    .cornerRadius(4)
                Spacer()
                Text(snapshot.capturedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(snapshot.efficiencyPercentage)%")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: snapshot.efficiencyColorHex))
                    Text(localization.localized(.tpEfficiency))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text("\(snapshot.totalTasksCompleted)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Tasks")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text(snapshot.formattedCost)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF9800"))
                    Text("Cost")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text("\(snapshot.memberMetrics.count)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#2196F3"))
                    Text(localization.localized(.tpMembers))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if let topPerformer = manager.topPerformer {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color(hex: "#FFD700"))
                        .font(.system(size: 12))
                    Text(localization.localized(.tpTopPerformer))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text(topPerformer.agentName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("(\(topPerformer.efficiencyPercentage)%)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#4CAF50"))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF5722").opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func snapshotRow(_ snapshot: TeamPerformanceSnapshot) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: snapshot.efficiencyColorHex))
                .frame(width: 8, height: 8)
            Text(snapshot.teamName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            Text("\(snapshot.efficiencyPercentage)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: snapshot.efficiencyColorHex))
            Spacer()
            Text("\(snapshot.totalTasksCompleted) tasks")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
            Text(snapshot.formattedCost)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Text(snapshot.capturedAt, style: .relative)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
            Button(action: { manager.deleteSnapshot(snapshot.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
        .padding(.horizontal)
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        VStack(spacing: 0) {
            if let snapshot = manager.latestSnapshot {
                if snapshot.memberMetrics.isEmpty {
                    emptyState(localization.localized(.tpNoData), icon: "person")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(snapshot.memberMetrics) { member in
                                memberCard(member)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                emptyState(localization.localized(.tpNoSnapshots), icon: "person.3")
            }
        }
    }

    private func memberCard(_ member: AgentPerformanceMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: member.specialization.iconName)
                    .foregroundColor(Color(hex: member.specialization.colorHex))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.agentName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(member.role)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(member.specialization.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: member.specialization.colorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: member.specialization.colorHex).opacity(0.15))
                    .cornerRadius(4)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(member.efficiencyPercentage)%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: member.efficiency > 0.8 ? "#4CAF50" : (member.efficiency > 0.6 ? "#FF9800" : "#F44336")))
                    Text(localization.localized(.tpEfficiency))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Efficiency bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: member.efficiency > 0.8 ? "#4CAF50" : (member.efficiency > 0.6 ? "#FF9800" : "#F44336")).opacity(0.6))
                        .frame(width: max(4, geo.size.width * CGFloat(member.efficiency)))
                }
            }
            .frame(height: 6)

            HStack(spacing: 16) {
                Label("\(member.tasksCompleted) completed", systemImage: "checkmark.circle")
                    .foregroundColor(Color(hex: "#4CAF50"))
                if member.tasksFailed > 0 {
                    Label("\(member.tasksFailed) failed", systemImage: "xmark.circle")
                        .foregroundColor(Color(hex: "#F44336"))
                }
                Label("Success: \(member.successRatePercentage)%", systemImage: "chart.bar")
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Label(member.formattedCostPerTask + "/task", systemImage: "dollarsign.circle")
                    .foregroundColor(Color(hex: "#FF9800"))
                Label(String(format: "%.0fms", member.averageLatencyMs), systemImage: "clock")
                    .foregroundColor(.white.opacity(0.5))
            }
            .font(.system(size: 10))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: member.specialization.colorHex).opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Radar Tab

    private var radarTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button("Generate Radar") {
                    manager.generateRadarData(teamName: manager.latestSnapshot?.teamName ?? "Alpha Team")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if manager.radarData.isEmpty {
                emptyState("No radar data.\nCapture a snapshot first.", icon: "hexagon")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(manager.radarData) { radar in
                            radarCard(radar)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func radarCard(_ radar: TeamRadarData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(radar.teamName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Avg: \(Int(radar.averageScore * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF5722"))
            }

            // Radar visualization (bar-based)
            ForEach(radar.dimensions) { dimension in
                HStack(spacing: 8) {
                    Image(systemName: dimension.category.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF5722"))
                        .frame(width: 20)

                    Text(dimension.name)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 100, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#FF5722").opacity(0.6))
                                .frame(width: max(4, geo.size.width * CGFloat(dimension.value)))
                        }
                    }
                    .frame(height: 12)

                    Text("\(dimension.percentage)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: dimension.value > 0.7 ? "#4CAF50" : (dimension.value > 0.4 ? "#FF9800" : "#F44336")))
                        .frame(width: 40, alignment: .trailing)
                }
            }

            HStack {
                Spacer()
                Text(radar.generatedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF5722").opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Metric", selection: $selectedLeaderboardMetric) {
                    ForEach(LeaderboardMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .frame(width: 180)

                Button("Generate") {
                    manager.generateLeaderboard(metric: selectedLeaderboardMetric)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#FF5722"))

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if manager.leaderboards.isEmpty {
                emptyState("No leaderboards.\nCapture a snapshot first.", icon: "trophy")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.leaderboards) { leaderboard in
                            leaderboardCard(leaderboard)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func leaderboardCard(_ leaderboard: TeamLeaderboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Color(hex: "#FFD700"))
                Text(leaderboard.metric.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(leaderboard.metric.unit)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            ForEach(leaderboard.entries) { entry in
                HStack(spacing: 8) {
                    Text("#\(entry.rank)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(rankColor(entry.rank))
                        .frame(width: 30)

                    if entry.rank <= 3 {
                        Image(systemName: entry.rank == 1 ? "crown.fill" : "medal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(rankColor(entry.rank))
                    }

                    Text(entry.agentName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: entry.trend.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: entry.trend.colorHex))

                    Text(entry.formattedScore)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(leaderboard.metric.unit)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.rank <= 3 ? rankColor(entry.rank).opacity(0.05) : Color.clear)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF5722").opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .white.opacity(0.5)
        }
    }

    // MARK: - Empty State

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
