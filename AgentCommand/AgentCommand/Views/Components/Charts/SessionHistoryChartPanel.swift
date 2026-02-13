import SwiftUI

// MARK: - M4: Session History Analytics Chart Panel

/// Expanded data visualization panel for Session History Analytics
/// Provides productivity trend charts, time distribution, session comparisons, and stat cards
struct SessionHistoryChartPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#9C27B0").opacity(0.3))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    statsGrid
                    productivityTrendSection
                    timeDistributionSection
                    sessionComparisonSection
                    sessionBarChartSection
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
                        .stroke(Color(hex: "#9C27B0").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#9C27B0"))
            Text(localization.localized(.shSessionAnalytics))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Text("Charts")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            if appState.sessionHistoryAnalyticsManager.isAnalyzing {
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
        let manager = appState.sessionHistoryAnalyticsManager

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            MiniStatCard(
                icon: "number.circle",
                label: localization.localized(.shTotalSessions),
                value: "\(manager.totalSessions)",
                color: Color(hex: "#9C27B0")
            )
            MiniStatCard(
                icon: "gauge.with.dots.needle.67percent",
                label: localization.localized(.shProductivity),
                value: "\(Int(manager.averageProductivity * 100))%",
                color: Color(hex: productivityColorHex(manager.averageProductivity)),
                trend: trendFromManager(manager)
            )
            MiniStatCard(
                icon: "checkmark.circle",
                label: localization.localized(.shTotalTasks),
                value: "\(manager.totalTasksAllSessions)",
                color: Color(hex: "#4CAF50")
            )
            MiniStatCard(
                icon: "dollarsign.circle",
                label: localization.localized(.auTotalCost),
                value: String(format: "$%.2f", manager.totalCostAllSessions),
                color: .white
            )
        }
    }

    // MARK: - Productivity Trend Chart

    private var productivityTrendSection: some View {
        let manager = appState.sessionHistoryAnalyticsManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "chart.line.uptrend.xyaxis", title: localization.localized(.shTrend))

            if let trend = manager.productivityTrend, !trend.dataPoints.isEmpty {
                MiniLineChart(
                    dataPoints: trend.dataPoints.map { point in
                        LineChartDataPoint(
                            label: shortDate(point.date),
                            value: point.productivity,
                            color: Color(hex: trend.overallTrend.colorHex)
                        )
                    },
                    lineColor: Color(hex: trend.overallTrend.colorHex),
                    fillGradient: true,
                    showDots: trend.dataPoints.count <= 14,
                    chartHeight: 50
                )

                HStack(spacing: 6) {
                    Image(systemName: trend.overallTrend.iconName)
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: trend.overallTrend.colorHex))
                    Text(trend.overallTrend.displayName)
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: trend.overallTrend.colorHex))
                    Spacer()
                    Text("\(trend.averagePercentage)% avg")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                noDataPlaceholder(localization.localized(.shNoTrend))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    // MARK: - Time Distribution (Pie Chart)

    private var timeDistributionSection: some View {
        let manager = appState.sessionHistoryAnalyticsManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "clock.badge.checkmark", title: localization.localized(.shTimeDistribution))

            if let dist = manager.currentTimeDistribution, !dist.entries.isEmpty {
                MiniPieChart(
                    slices: dist.entries.map { entry in
                        PieSlice(
                            label: entry.category.displayName,
                            value: entry.minutes,
                            color: Color(hex: entry.category.colorHex)
                        )
                    },
                    chartSize: 55,
                    showLegend: true
                )
            } else {
                noDataPlaceholder("No time distribution data")
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    // MARK: - Session Comparison

    private var sessionComparisonSection: some View {
        let manager = appState.sessionHistoryAnalyticsManager

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "arrow.left.arrow.right", title: localization.localized(.shComparisons))

            if let comparison = manager.comparisons.first {
                ForEach(comparison.metrics) { metric in
                    ComparisonBar(
                        label: metric.name,
                        valueA: metric.valueA,
                        valueB: metric.valueB,
                        labelA: String(comparison.sessionAName.prefix(6)),
                        labelB: String(comparison.sessionBName.prefix(6)),
                        unit: metric.unit
                    )
                }
            } else if manager.sessions.count < 2 {
                noDataPlaceholder("Need 2+ sessions to compare")
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
    }

    // MARK: - Session Bar Chart

    private var sessionBarChartSection: some View {
        let manager = appState.sessionHistoryAnalyticsManager
        let sessions = Array(manager.sessions.prefix(10))

        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "chart.bar.fill", title: "Session Tasks")

            if !sessions.isEmpty {
                MiniBarChart(
                    data: sessions.map { session in
                        BarChartDataPoint(
                            label: String(session.sessionName.suffix(3)),
                            value: Double(session.tasksCompleted),
                            color: Color(hex: session.productivityColorHex),
                            formattedValue: "\(session.tasksCompleted)"
                        )
                    },
                    maxBarHeight: 35,
                    barSpacing: 3,
                    showLabels: true
                )
                .frame(height: 55)
            } else {
                noDataPlaceholder(localization.localized(.shNoSessions))
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
                .foregroundColor(Color(hex: "#9C27B0").opacity(0.7))
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

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    private func productivityColorHex(_ score: Double) -> String {
        switch score {
        case 0.8...1.0: return "#4CAF50"
        case 0.6..<0.8: return "#8BC34A"
        case 0.4..<0.6: return "#FF9800"
        default: return "#F44336"
        }
    }

    private func trendFromManager(_ manager: SessionHistoryAnalyticsManager) -> StatTrend? {
        guard let trend = manager.productivityTrend else { return nil }
        return StatTrend(direction: trend.overallTrend, percentageChange: trend.averageProductivity - 0.5)
    }
}
