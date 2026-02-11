import SwiftUI

/// B3 - Agent Stats Dashboard with stats overview, leaderboard, performance charts, and heatmap
struct AgentStatsDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DashboardTab = .overview

    enum DashboardTab: String, CaseIterable {
        case overview, leaderboard, charts, heatmap

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .leaderboard: return "list.number"
            case .charts: return "chart.line.uptrend.xyaxis"
            case .heatmap: return "square.grid.3x3.fill"
            }
        }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .leaderboard: return "Leaderboard"
            case .charts: return "Charts"
            case .heatmap: return "Heatmap"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            tabBar
            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                switch selectedTab {
                case .overview:
                    overviewTab
                case .leaderboard:
                    leaderboardTab
                case .charts:
                    chartsTab
                case .heatmap:
                    heatmapTab
                }
            }
        }
        .frame(width: 520, height: 580)
        .background(Color(hex: "#0D1117"))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .foregroundColor(.cyan)
                .font(.title2)
            Text(localization.localized(.statsDashboard))
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .cyan : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? Color.cyan.opacity(0.1)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        let allStats = appState.statsManager.stats

        return VStack(spacing: 16) {
            if allStats.isEmpty {
                emptyState
            } else {
                // Global summary cards
                globalSummaryCards(allStats)

                // Per-agent summary
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.localized(.agentStats))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    ForEach(Array(allStats.keys.sorted()), id: \.self) { name in
                        if let stats = allStats[name] {
                            agentOverviewCard(name: name, stats: stats)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func globalSummaryCards(_ allStats: [String: AgentStats]) -> some View {
        let totalCompleted = allStats.values.reduce(0) { $0 + $1.totalTasksCompleted }
        let totalFailed = allStats.values.reduce(0) { $0 + $1.totalTasksFailed }
        let totalAll = totalCompleted + totalFailed
        let globalSuccessRate = totalAll > 0 ? Double(totalCompleted) / Double(totalAll) : 0
        let totalWork = allStats.values.reduce(0.0) { $0 + $1.totalWorkTime }
        let avgDuration = totalCompleted > 0 ? totalWork / Double(totalCompleted) : 0

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(
                icon: "checkmark.circle.fill",
                title: localization.localized(.totalCompleted),
                value: "\(totalCompleted)",
                color: .green
            )
            StatCard(
                icon: "percent",
                title: localization.localized(.successRateLabel),
                value: String(format: "%.0f%%", globalSuccessRate * 100),
                color: globalSuccessRate >= 0.8 ? .green : (globalSuccessRate >= 0.5 ? .yellow : .red)
            )
            StatCard(
                icon: "clock.fill",
                title: localization.localized(.avgTime),
                value: formatDuration(avgDuration),
                color: .blue
            )
            StatCard(
                icon: "bolt.fill",
                title: localization.localized(.totalXPLabel),
                value: "\(allStats.values.reduce(0) { $0 + $1.totalXP })",
                color: .yellow
            )
        }
    }

    private func agentOverviewCard(name: String, stats: AgentStats) -> some View {
        VStack(spacing: 6) {
            HStack {
                // Level badge
                Text("Lv.\(stats.level)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(levelColor(stats.level))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(levelColor(stats.level).opacity(0.15))
                    )

                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text(String(format: "%.0f pts", stats.productivityScore))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 16) {
                miniStat(icon: "checkmark.circle", value: "\(stats.totalTasksCompleted)", color: .green)
                miniStat(icon: "xmark.circle", value: "\(stats.totalTasksFailed)", color: .red)
                miniStat(icon: "percent", value: String(format: "%.0f%%", stats.successRate * 100), color: .blue)
                miniStat(icon: "clock", value: formatDuration(stats.averageTaskDuration), color: .orange)
                miniStat(icon: "flame", value: "\(stats.bestStreak)", color: .yellow)
            }
            .font(.system(size: 10))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundColor(color.opacity(0.7))
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        let allStats = appState.statsManager.stats
        let sorted = allStats.sorted { $0.value.productivityScore > $1.value.productivityScore }

        return VStack(spacing: 12) {
            if sorted.isEmpty {
                emptyState
            } else {
                ForEach(Array(sorted.enumerated()), id: \.element.key) { index, entry in
                    leaderboardRow(rank: index + 1, name: entry.key, stats: entry.value)
                }
            }
        }
        .padding()
    }

    private func leaderboardRow(rank: Int, name: String, stats: AgentStats) -> some View {
        HStack(spacing: 12) {
            // Rank medal
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(rank <= 3 ? rankMedal(rank) : "#\(rank)")
                    .font(.system(size: rank <= 3 ? 16 : 11, weight: .bold))
                    .foregroundColor(rankColor(rank))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Lv.\(stats.level)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(levelColor(stats.level))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(levelColor(stats.level).opacity(0.15))
                        )
                }

                HStack(spacing: 12) {
                    Text("\(stats.totalTasksCompleted) tasks")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%% success", stats.successRate * 100))
                        .foregroundColor(.secondary)
                    Text(formatDuration(stats.averageTaskDuration) + " avg")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 10))
            }

            Spacer()

            // Productivity score
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", stats.productivityScore))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                Text("pts")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rank == 1 ? Color.yellow.opacity(0.06) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            rank == 1 ? Color.yellow.opacity(0.2) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Charts Tab

    private var chartsTab: some View {
        let allStats = appState.statsManager.stats

        return VStack(spacing: 20) {
            if allStats.isEmpty {
                emptyState
            } else {
                // Aggregate daily records across all agents
                let aggregated = aggregateDailyRecords(allStats)

                if aggregated.isEmpty {
                    Text(localization.localized(.noChartData))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    // Task completion chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.dailyTasks))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        DailyBarChart(records: aggregated)
                            .frame(height: 150)
                    }

                    // XP earned chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.dailyXP))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        DailyXPChart(records: aggregated)
                            .frame(height: 120)
                    }
                }
            }
        }
        .padding()
    }

    private func aggregateDailyRecords(_ allStats: [String: AgentStats]) -> [DailyRecord] {
        var byDate: [String: DailyRecord] = [:]
        for stats in allStats.values {
            for record in stats.dailyRecords {
                if var existing = byDate[record.date] {
                    existing.tasksCompleted += record.tasksCompleted
                    existing.tasksFailed += record.tasksFailed
                    existing.totalDuration += record.totalDuration
                    existing.xpEarned += record.xpEarned
                    byDate[record.date] = existing
                } else {
                    byDate[record.date] = record
                }
            }
        }
        return byDate.values.sorted { $0.date < $1.date }
    }

    // MARK: - Heatmap Tab

    private var heatmapTab: some View {
        let allStats = appState.statsManager.stats

        return VStack(spacing: 16) {
            if allStats.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.localized(.activeHoursTitle))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(localization.localized(.activeHoursDesc))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Aggregate hours across all agents
                    let aggregatedHours = aggregateHours(allStats)
                    HeatmapView(hourlyData: aggregatedHours)
                        .frame(height: 200)
                }

                // Per-agent heatmap breakdown
                ForEach(Array(allStats.keys.sorted()), id: \.self) { name in
                    if let stats = allStats[name], !stats.activeHours.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            HeatmapView(hourlyData: stats.activeHours)
                                .frame(height: 50)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func aggregateHours(_ allStats: [String: AgentStats]) -> [Int: Int] {
        var combined: [Int: Int] = [:]
        for stats in allStats.values {
            for (hour, count) in stats.activeHours {
                combined[hour, default: 0] += count
            }
        }
        return combined
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text(localization.localized(.noStatsYet))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1fm", seconds / 60)
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 1: return .gray
        case 2...4: return .green
        case 5...9: return .blue
        default: return .yellow
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }

    private func rankMedal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Daily Bar Chart (Tasks completed/failed per day)

struct DailyBarChart: View {
    let records: [DailyRecord]

    var body: some View {
        let maxVal = max(records.map { $0.tasksCompleted + $0.tasksFailed }.max() ?? 1, 1)

        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(records.suffix(14).enumerated()), id: \.offset) { _, record in
                    VStack(spacing: 2) {
                        // Completed bar
                        let completedHeight = CGFloat(record.tasksCompleted) / CGFloat(maxVal) * (geo.size.height - 20)
                        let failedHeight = CGFloat(record.tasksFailed) / CGFloat(maxVal) * (geo.size.height - 20)

                        VStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.7))
                                .frame(height: max(failedHeight, record.tasksFailed > 0 ? 2 : 0))

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green.opacity(0.7))
                                .frame(height: max(completedHeight, record.tasksCompleted > 0 ? 2 : 0))
                        }

                        // Date label
                        Text(shortDate(record.date))
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-45))
                            .frame(height: 16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func shortDate(_ dateString: String) -> String {
        // "yyyy-MM-dd" -> "MM/dd"
        let parts = dateString.split(separator: "-")
        guard parts.count == 3 else { return dateString }
        return "\(parts[1])/\(parts[2])"
    }
}

// MARK: - Daily XP Chart

struct DailyXPChart: View {
    let records: [DailyRecord]

    var body: some View {
        let maxXP = max(records.map(\.xpEarned).max() ?? 1, 1)
        let displayRecords = Array(records.suffix(14))

        GeometryReader { geo in
            let stepX = displayRecords.count > 1 ? geo.size.width / CGFloat(displayRecords.count - 1) : geo.size.width
            let chartHeight = geo.size.height - 16

            ZStack(alignment: .bottomLeading) {
                // Grid lines
                ForEach(0..<4, id: \.self) { i in
                    let y = chartHeight * CGFloat(i) / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                }

                // Line chart
                if displayRecords.count > 1 {
                    Path { path in
                        for (i, record) in displayRecords.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = chartHeight - (CGFloat(record.xpEarned) / CGFloat(maxXP) * chartHeight)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2
                    )

                    // Area fill
                    Path { path in
                        for (i, record) in displayRecords.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = chartHeight - (CGFloat(record.xpEarned) / CGFloat(maxXP) * chartHeight)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: chartHeight))
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(displayRecords.count - 1) * stepX, y: chartHeight))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.2), Color.yellow.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Data points
                    ForEach(Array(displayRecords.enumerated()), id: \.offset) { i, record in
                        let x = CGFloat(i) * stepX
                        let y = chartHeight - (CGFloat(record.xpEarned) / CGFloat(maxXP) * chartHeight)
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 4, height: 4)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

// MARK: - Heatmap View (24 hours)

struct HeatmapView: View {
    let hourlyData: [Int: Int]

    var body: some View {
        let maxVal = max(hourlyData.values.max() ?? 1, 1)

        VStack(spacing: 4) {
            // 24-hour grid: 6 columns x 4 rows
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 6), spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = hourlyData[hour] ?? 0
                    let intensity = Double(count) / Double(maxVal)

                    VStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatColor(intensity: intensity))
                            .frame(height: 24)
                            .overlay(
                                Text("\(count)")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(intensity > 0.5 ? .white : .white.opacity(0.4))
                            )

                        Text(hourLabel(hour))
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(intensity: intensity))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func heatColor(intensity: Double) -> Color {
        if intensity == 0 {
            return Color.white.opacity(0.05)
        }
        return Color.green.opacity(0.2 + intensity * 0.7)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}
