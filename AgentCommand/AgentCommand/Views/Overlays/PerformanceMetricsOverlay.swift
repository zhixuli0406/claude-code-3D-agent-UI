import SwiftUI

/// Floating performance metrics panel showing real-time token usage, cost, duration, and resource usage (D5)
struct PerformanceMetricsOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            sessionMetrics
            if !appState.metricsManager.processResourceUsage.isEmpty {
                resourceMetrics
            }
            if !activeTaskMetrics.isEmpty {
                activeTasksList
            }
            recentCompletedList
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 10))
                .foregroundColor(.green)
            Text(localization.localized(.performanceMetrics).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            // Live indicator
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(appState.metricsManager.activeTaskCount > 0 ? 1.0 : 0.3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    // MARK: - Session Metrics

    private var sessionMetrics: some View {
        VStack(spacing: 6) {
            // Cost row
            metricRow(
                icon: "dollarsign.circle",
                label: localization.localized(.sessionCost),
                value: formatCost(appState.metricsManager.sessionTotalCost),
                color: costColor(appState.metricsManager.sessionTotalCost)
            )

            // Token usage row
            metricRow(
                icon: "text.word.spacing",
                label: localization.localized(.tokenUsage),
                value: formatTokens(appState.metricsManager.sessionTotalTokens),
                color: .cyan
            )

            // Task count row
            metricRow(
                icon: "number.circle",
                label: localization.localized(.tasksRun),
                value: "\(appState.metricsManager.sessionTaskCount)",
                color: .blue
            )

            // Average duration row
            metricRow(
                icon: "clock",
                label: localization.localized(.avgDuration),
                value: formatDurationMs(appState.metricsManager.averageTaskDurationMs),
                color: .orange
            )
        }
        .padding(8)
    }

    // MARK: - Resource Metrics

    private var resourceMetrics: some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
                Text(localization.localized(.resourceUsage).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            HStack(spacing: 12) {
                // CPU
                VStack(spacing: 2) {
                    Text(String(format: "%.1f%%", appState.metricsManager.totalResourceCPU))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(cpuColor(appState.metricsManager.totalResourceCPU))
                    Text("CPU")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Memory
                VStack(spacing: 2) {
                    Text(String(format: "%.0fMB", appState.metricsManager.totalResourceMemoryMB))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(memoryColor(appState.metricsManager.totalResourceMemoryMB))
                    Text("MEM")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Active processes
                VStack(spacing: 2) {
                    Text("\(appState.metricsManager.processResourceUsage.count)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("PROC")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Active Tasks

    private var activeTaskMetrics: [TaskMetrics] {
        appState.metricsManager.taskMetrics.values
            .filter { $0.status == .running }
            .sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
    }

    private var activeTasksList: some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.green)
                Text(localization.localized(.activeTasks).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            ForEach(activeTaskMetrics.prefix(3), id: \.taskId) { metrics in
                activeTaskCard(metrics)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
    }

    private func activeTaskCard(_ metrics: TaskMetrics) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(metrics.prompt.prefix(30)))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 8) {
                // Elapsed time
                if let start = metrics.startTime {
                    let elapsed = Date().timeIntervalSince(start)
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 7))
                        Text(formatDurationSeconds(elapsed))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                }

                // Tool calls
                HStack(spacing: 2) {
                    Image(systemName: "wrench")
                        .font(.system(size: 7))
                    Text("\(metrics.toolCallCount)")
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(.cyan)

                // Estimated tokens
                HStack(spacing: 2) {
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 7))
                    Text(formatTokens(metrics.estimatedTokens))
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.green.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Recent Completed

    private var recentCompletedList: some View {
        let recent = Array(appState.metricsManager.completedTaskMetrics.prefix(3))

        return Group {
            if !recent.isEmpty {
                VStack(spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                        Text(localization.localized(.recentTasks).uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                    ForEach(recent, id: \.taskId) { metrics in
                        completedTaskCard(metrics)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func completedTaskCard(_ metrics: TaskMetrics) -> some View {
        HStack(spacing: 6) {
            // Status indicator
            Circle()
                .fill(metrics.status == .completed ? Color.green : Color.red)
                .frame(width: 5, height: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(String(metrics.prompt.prefix(25)))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if metrics.costUSD > 0 {
                        Text(formatCost(metrics.costUSD))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(costColor(metrics.costUSD))
                    }
                    if metrics.durationMs > 0 {
                        Text(formatDurationMs(metrics.durationMs))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Metric Row Helper

    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Formatters

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else if cost < 1.0 {
            return String(format: "$%.3f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens < 1000 {
            return "\(tokens)"
        } else if tokens < 1_000_000 {
            return String(format: "%.1fK", Double(tokens) / 1000.0)
        } else {
            return String(format: "%.2fM", Double(tokens) / 1_000_000.0)
        }
    }

    private func formatDurationMs(_ ms: Int) -> String {
        if ms <= 0 { return "--" }
        let seconds = Double(ms) / 1000.0
        return formatDurationSeconds(seconds)
    }

    private func formatDurationSeconds(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            let m = Int(seconds / 60)
            let s = Int(seconds) % 60
            return "\(m)m\(s)s"
        } else {
            let h = Int(seconds / 3600)
            let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h\(m)m"
        }
    }

    // MARK: - Color Helpers

    private func costColor(_ cost: Double) -> Color {
        if cost < 0.10 { return .green }
        if cost < 1.00 { return .yellow }
        return .red
    }

    private func cpuColor(_ cpu: Double) -> Color {
        if cpu < 50 { return .green }
        if cpu < 80 { return .yellow }
        return .red
    }

    private func memoryColor(_ mb: Double) -> Color {
        if mb < 256 { return .green }
        if mb < 512 { return .yellow }
        return .red
    }
}
