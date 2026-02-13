import SwiftUI

// MARK: - M5: Team Performance Chart Panel

/// Expanded data visualization panel for Team Performance
/// Provides radar charts, member efficiency bars, leaderboard, and comparison stats
struct TeamPerformanceChartPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#FF5722").opacity(0.3))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    statsGrid
                    radarSection
                    memberEfficiencySection
                    leaderboardSection
                    specializationSection
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .frame(width: panelWidth)
        .frame(maxHeight: 500)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF5722").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.tpTeamPerformance))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Text("Charts")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            if appState.teamPerformanceManager.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let manager = appState.teamPerformanceManager

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            if let snapshot = manager.latestSnapshot {
                MiniStatCard(
                    icon: "gauge.with.dots.needle.67percent",
                    label: localization.localized(.tpEfficiency),
                    value: "\(snapshot.efficiencyPercentage)%",
                    color: Color(hex: snapshot.efficiencyColorHex),
                    subtitle: snapshot.efficiencyLabel
                )
                MiniStatCard(
                    icon: "checkmark.circle",
                    label: localization.localized(.shTotalTasks),
                    value: "\(snapshot.totalTasksCompleted)",
                    color: Color(hex: "#4CAF50")
                )
                MiniStatCard(
                    icon: "dollarsign.circle",
                    label: localization.localized(.auTotalCost),
                    value: snapshot.formattedCost,
                    color: .white
                )
                MiniStatCard(
                    icon: "person.3",
                    label: localization.localized(.tpMembers),
                    value: "\(snapshot.memberMetrics.count)",
                    color: Color(hex: "#FF5722")
                )
            } else {
                noDataPlaceholder(localization.localized(.tpNoData))
            }
        }
    }

    // MARK: - Radar Chart

    private var radarSection: some View {
        let manager = appState.teamPerformanceManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "hexagon", title: localization.localized(.tpRadar))

            if let radar = manager.radarData.first {
                HStack {
                    Spacer()
                    MiniRadarChart(
                        dimensions: radar.dimensions.map { dim in
                            RadarChartDimension(
                                label: dim.name,
                                shortLabel: abbreviate(dim.category),
                                value: dim.value
                            )
                        },
                        accentColor: Color(hex: "#FF5722"),
                        chartSize: 100,
                        gridLevels: 3,
                        showLabels: true
                    )
                    Spacer()
                }

                HStack {
                    Spacer()
                    Text("Avg: \(Int(radar.averageScore * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF5722").opacity(0.8))
                    Spacer()
                }
            } else {
                noDataPlaceholder("No radar data")
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    // MARK: - Member Efficiency

    private var memberEfficiencySection: some View {
        let manager = appState.teamPerformanceManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "person.crop.rectangle.stack", title: localization.localized(.tpMembers))

            if let snapshot = manager.latestSnapshot {
                let sorted = snapshot.memberMetrics.sorted { $0.efficiency > $1.efficiency }

                MiniBarChart(
                    data: sorted.map { metric in
                        BarChartDataPoint(
                            label: String(metric.agentName.prefix(6)),
                            value: metric.efficiency * 100,
                            color: Color(hex: metric.specialization.colorHex),
                            formattedValue: "\(metric.efficiencyPercentage)%"
                        )
                    },
                    maxBarHeight: 35,
                    barSpacing: 3,
                    orientation: .horizontal
                )

                // Efficiency progress rings
                HStack(spacing: 8) {
                    ForEach(sorted.prefix(4)) { metric in
                        VStack(spacing: 2) {
                            MiniProgressRing(
                                progress: metric.efficiency,
                                color: Color(hex: metric.specialization.colorHex),
                                size: 28,
                                lineWidth: 3
                            )
                            Text(String(metric.agentName.prefix(4)))
                                .font(.system(size: 6))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                noDataPlaceholder(localization.localized(.tpNoData))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        let manager = appState.teamPerformanceManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "trophy.fill", title: localization.localized(.tpLeaderboard))

            if let leaderboard = manager.leaderboards.first {
                ForEach(leaderboard.entries.prefix(5)) { entry in
                    leaderboardRow(entry, metric: leaderboard.metric)
                }
            } else {
                noDataPlaceholder("No leaderboard data")
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    private func leaderboardRow(_ entry: LeaderboardEntry, metric: LeaderboardMetric) -> some View {
        HStack(spacing: 4) {
            // Rank badge
            Text("#\(entry.rank)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(rankColor(entry.rank))
                .frame(width: 18)

            // Trend
            Image(systemName: entry.trend.iconName)
                .font(.system(size: 6))
                .foregroundColor(Color(hex: entry.trend.colorHex))

            Text(entry.agentName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text(entry.formattedScore)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Text(metric.unit)
                .font(.system(size: 6))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // MARK: - Specialization Distribution

    private var specializationSection: some View {
        let manager = appState.teamPerformanceManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "brain.head.profile", title: localization.localized(.tpSpecialization))

            if let snapshot = manager.latestSnapshot {
                let specGroups = Dictionary(grouping: snapshot.memberMetrics, by: \.specialization)
                let slices = specGroups.map { spec, members in
                    PieSlice(
                        label: spec.displayName,
                        value: Double(members.count),
                        color: Color(hex: spec.colorHex)
                    )
                }.sorted { $0.value > $1.value }

                if !slices.isEmpty {
                    MiniPieChart(
                        slices: slices,
                        chartSize: 50,
                        showLegend: true
                    )
                }
            } else {
                noDataPlaceholder(localization.localized(.tpNoData))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "#FF5722").opacity(0.7))
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }

    private func noDataPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8))
            .foregroundColor(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func abbreviate(_ dimension: PerformanceDimension) -> String {
        switch dimension {
        case .speed: return "SPD"
        case .quality: return "QAL"
        case .costEfficiency: return "CST"
        case .reliability: return "REL"
        case .collaboration: return "COL"
        case .throughput: return "THR"
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .white.opacity(0.4)
        }
    }
}
