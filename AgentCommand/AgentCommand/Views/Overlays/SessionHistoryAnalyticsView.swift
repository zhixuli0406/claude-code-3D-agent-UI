import SwiftUI

// MARK: - M4: Session History Analytics Detail View (Sheet)

struct SessionHistoryAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var selectedSessionA: String?
    @State private var selectedSessionB: String?

    private var manager: SessionHistoryAnalyticsManager {
        appState.sessionHistoryAnalyticsManager
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#9C27B0").opacity(0.3))

            TabView(selection: $selectedTab) {
                sessionsTab.tag(0)
                trendsTab.tag(1)
                comparisonTab.tag(2)
                timeDistributionTab.tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if manager.sessions.isEmpty {
                manager.loadSampleData()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .foregroundColor(Color(hex: "#9C27B0"))
            Text(localization.localized(.shSessionAnalytics))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.shTotalSessions)).tag(0)
                Text(localization.localized(.shTrend)).tag(1)
                Text(localization.localized(.shComparisons)).tag(2)
                Text(localization.localized(.shTimeDistribution)).tag(3)
            }
            .pickerStyle(.segmented)
            .frame(width: 380)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Sessions Tab

    private var sessionsTab: some View {
        VStack(spacing: 8) {
            // Summary bar
            HStack(spacing: 16) {
                statBadge(localization.localized(.shTotalSessions), value: "\(manager.totalSessions)", color: "#9C27B0")
                statBadge(localization.localized(.shProductivity), value: "\(Int(manager.averageProductivity * 100))%", color: "#4CAF50")
                statBadge(localization.localized(.shTotalTasks), value: "\(manager.totalTasksAllSessions)", color: "#2196F3")
                statBadge("Total Cost", value: String(format: "$%.2f", manager.totalCostAllSessions), color: "#FF9800")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if manager.sessions.isEmpty {
                emptyState(localization.localized(.shNoSessions), icon: "clock")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(manager.sessions) { session in
                            sessionCard(session)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func statBadge(_ title: String, value: String, color: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: color).opacity(0.1))
        )
    }

    private func sessionCard(_ session: SessionAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(hex: session.productivityColorHex))
                    .frame(width: 8, height: 8)
                Text(session.sessionName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(session.productivityLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: session.productivityColorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: session.productivityColorHex).opacity(0.15))
                    .cornerRadius(4)
                Spacer()
                Text(session.formattedDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Button(action: { manager.deleteSession(session.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 16) {
                Label("\(session.tasksCompleted) tasks", systemImage: "checkmark.circle")
                    .foregroundColor(Color(hex: "#4CAF50"))
                if session.tasksFailed > 0 {
                    Label("\(session.tasksFailed) failed", systemImage: "xmark.circle")
                        .foregroundColor(Color(hex: "#F44336"))
                }
                Label(session.formattedCost, systemImage: "dollarsign.circle")
                    .foregroundColor(Color(hex: "#FF9800"))
                Label("\(session.totalTokens) tokens", systemImage: "textformat.abc")
                    .foregroundColor(.white.opacity(0.5))
                Label(session.dominantModel, systemImage: "cpu")
                    .foregroundColor(.white.opacity(0.5))
            }
            .font(.system(size: 10))

            HStack(spacing: 8) {
                Text("Productivity: \(Int(session.productivityScore * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: session.productivityColorHex))
                Text("Success: \(session.successRatePercentage)%")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Text("Agents: \(session.agentsUsed)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(session.startedAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#9C27B0").opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button("Analyze Trend") {
                    manager.analyzeProductivityTrend()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let trend = manager.productivityTrend {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Trend summary
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Image(systemName: trend.overallTrend.iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: trend.overallTrend.colorHex))
                                Text(trend.overallTrend.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: trend.overallTrend.colorHex))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: trend.overallTrend.colorHex).opacity(0.1))
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Average Productivity")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(trend.averagePercentage)%")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)

                        // Chart
                        trendChart(trend)
                            .padding(.horizontal)

                        // Data points
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Points")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            ForEach(trend.dataPoints.suffix(10)) { point in
                                HStack {
                                    Text(point.date, style: .date)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()

                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(hex: "#9C27B0").opacity(0.5))
                                            .frame(width: max(4, geo.size.width * CGFloat(point.productivity)))
                                    }
                                    .frame(width: 100, height: 8)

                                    Text("\(Int(point.productivity * 100))%")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 40, alignment: .trailing)

                                    Text("\(point.tasksCompleted) tasks")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            } else {
                emptyState(localization.localized(.shNoTrend), icon: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private func trendChart(_ trend: ProductivityTrend) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(trend.dataPoints) { point in
                VStack(spacing: 2) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#9C27B0").opacity(0.7))
                        .frame(height: max(4, CGFloat(point.productivity) * 80))
                }
                .frame(height: 90)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Comparison Tab

    private var comparisonTab: some View {
        VStack(spacing: 8) {
            // Comparison selector
            HStack(spacing: 8) {
                Picker("Session A", selection: Binding(
                    get: { selectedSessionA ?? "" },
                    set: { selectedSessionA = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Select...").tag("")
                    ForEach(manager.sessions) { session in
                        Text(session.sessionName).tag(session.id)
                    }
                }
                .frame(width: 160)

                Text("vs")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Picker("Session B", selection: Binding(
                    get: { selectedSessionB ?? "" },
                    set: { selectedSessionB = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Select...").tag("")
                    ForEach(manager.sessions) { session in
                        Text(session.sessionName).tag(session.id)
                    }
                }
                .frame(width: 160)

                Button("Compare") {
                    if let a = selectedSessionA, let b = selectedSessionB, a != b {
                        manager.compareSessions(a, b)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#9C27B0"))
                .disabled(selectedSessionA == nil || selectedSessionB == nil || selectedSessionA == selectedSessionB)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if manager.comparisons.isEmpty {
                emptyState("No comparisons yet. Select two sessions to compare.", icon: "arrow.left.arrow.right")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.comparisons) { comparison in
                            comparisonCard(comparison)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func comparisonCard(_ comparison: SessionComparison) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comparison.sessionAName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9C27B0"))
                Text("vs")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Text(comparison.sessionBName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#2196F3"))
                Spacer()
                Button(action: { manager.deleteComparison(comparison.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.borderless)
            }

            ForEach(comparison.metrics) { metric in
                HStack {
                    Text(metric.name)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 110, alignment: .leading)

                    Text(String(format: "%.1f", metric.valueA))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#9C27B0"))
                        .frame(width: 60, alignment: .trailing)

                    Text(String(format: "%.1f", metric.valueB))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#2196F3"))
                        .frame(width: 60, alignment: .trailing)

                    Text(metric.deltaDisplay)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: metric.delta >= 0 ? "#4CAF50" : "#F44336"))
                        .frame(width: 50, alignment: .trailing)

                    Text(metric.unit)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 40, alignment: .leading)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#9C27B0").opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Time Distribution Tab

    private var timeDistributionTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button("Generate Distribution") {
                    manager.generateTimeDistribution()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let distribution = manager.currentTimeDistribution {
                ScrollView {
                    VStack(spacing: 16) {
                        // Total time
                        Text(String(format: "Total: %.0f minutes", distribution.totalMinutes))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        // Bar chart
                        HStack(alignment: .bottom, spacing: 16) {
                            ForEach(distribution.entries) { entry in
                                VStack(spacing: 4) {
                                    Text("\(entry.percentageDisplay)%")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: entry.category.colorHex))

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: entry.category.colorHex).opacity(0.7))
                                        .frame(width: 50, height: max(8, CGFloat(entry.percentage) * 200))

                                    Image(systemName: entry.category.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: entry.category.colorHex))
                                    Text(entry.category.displayName)
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                        )

                        // Detailed list
                        ForEach(distribution.entries) { entry in
                            HStack(spacing: 8) {
                                Image(systemName: entry.category.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: entry.category.colorHex))
                                    .frame(width: 24)

                                Text(entry.category.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 80, alignment: .leading)

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: entry.category.colorHex).opacity(0.5))
                                        .frame(width: max(4, geo.size.width * CGFloat(entry.percentage)))
                                }
                                .frame(height: 12)

                                Text(String(format: "%.0f min", entry.minutes))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 60, alignment: .trailing)

                                Text("\(entry.percentageDisplay)%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: entry.category.colorHex))
                                    .frame(width: 35, alignment: .trailing)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            } else {
                emptyState("No time distribution data.\nGenerate from session history.", icon: "clock")
            }
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
