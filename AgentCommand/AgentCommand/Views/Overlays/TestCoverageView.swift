import SwiftUI

/// Modal sheet for test coverage detail view (I2)
struct TestCoverageView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .frame(width: 700, height: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#8BC34A"))
            Text(localization.localized(.testCoverage))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.testCoverageManager.isRunningTests {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(localization.localized(.testRunTests))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            } else if let report = appState.testCoverageManager.currentReport {
                Text("\(Int(report.overallCoverage * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(coverageColor(report.overallCoverage))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(coverageColor(report.overallCoverage).opacity(0.1))
                    .cornerRadius(4)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: localization.localized(.testOverallCoverage), icon: "chart.bar.fill", index: 0)
            tabButton(title: localization.localized(.testResults), icon: "list.bullet.clipboard", index: 1)
            tabButton(title: localization.localized(.testCoverageTrend), icon: "chart.line.uptrend.xyaxis", index: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color(hex: "#8BC34A") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#8BC34A").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: coverageMapTab
        case 1: testResultsTab
        case 2: trendsTab
        default: coverageMapTab
        }
    }

    // MARK: - Coverage Map Tab

    private var coverageMapTab: some View {
        VStack(spacing: 0) {
            if let report = appState.testCoverageManager.currentReport {
                // Summary row
                HStack(spacing: 16) {
                    statBadge(icon: "chart.bar.fill", value: "\(Int(report.overallCoverage * 100))%", label: localization.localized(.testOverallCoverage))
                    statBadge(icon: "checkmark.circle", value: "\(report.passedTests)", label: localization.localized(.testPassed))
                    statBadge(icon: "xmark.circle", value: "\(report.failedTests)", label: localization.localized(.testFailed))
                    statBadge(icon: "minus.circle", value: "\(report.skippedTests)", label: localization.localized(.testSkipped))
                    statBadge(icon: "number", value: "\(report.totalTests)", label: localization.localized(.testTotal))
                }
                .padding(16)

                Divider().background(Color.white.opacity(0.1))

                // File coverage heatmap
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(report.fileCoverages.sorted(by: { $0.coverage < $1.coverage })) { file in
                            fileCoverageRow(file)
                        }
                    }
                    .padding(12)
                }
            } else {
                emptyState
            }
        }
    }

    private func fileCoverageRow(_ file: FileCoverage) -> some View {
        HStack(spacing: 8) {
            // Coverage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: file.coverageColor))
                        .frame(width: geo.size.width * file.coverage)
                }
            }
            .frame(width: 60, height: 6)

            Text(file.fileName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)

            Text(file.moduleGroup)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.05))
                .cornerRadius(3)

            Spacer()

            Text("\(file.coveredLines)/\(file.totalLines)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            Text("\(Int(file.coverage * 100))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: file.coverageColor))
                .frame(width: 36, alignment: .trailing)

            if !file.uncoveredRanges.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: "#FF9800"))
                    .help(localization.localized(.testUncovered))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: file.coverageColor).opacity(0.03))
        )
    }

    // MARK: - Test Results Tab

    private var testResultsTab: some View {
        VStack(spacing: 0) {
            if appState.testCoverageManager.testCases.isEmpty {
                emptyState
            } else {
                // Test result summary
                if let report = appState.testCoverageManager.currentReport {
                    HStack(spacing: 12) {
                        testResultBadge(count: report.passedTests, color: "#4CAF50", label: localization.localized(.testPassed))
                        testResultBadge(count: report.failedTests, color: "#F44336", label: localization.localized(.testFailed))
                        testResultBadge(count: report.skippedTests, color: "#9E9E9E", label: localization.localized(.testSkipped))
                        Spacer()

                        // Run tests button
                        Button(action: { appState.testCoverageManager.runTests() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text(localization.localized(.testRunTests))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#8BC34A").opacity(0.5))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.testCoverageManager.isRunningTests)
                    }
                    .padding(16)

                    Divider().background(Color.white.opacity(0.1))
                }

                // Test case list
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.testCoverageManager.testCases) { testCase in
                            testCaseRow(testCase)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func testCaseRow(_ testCase: TestCase) -> some View {
        HStack(spacing: 8) {
            Image(systemName: testCase.result.iconName)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: testCase.result.hexColor))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(testCase.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 6) {
                    Text(testCase.suiteName)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))

                    if testCase.duration > 0 {
                        Text(String(format: "%.2fs", testCase.duration))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }

                if let error = testCase.errorMessage {
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#F44336").opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: testCase.result.hexColor).opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: testCase.result.hexColor).opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func testResultBadge(count: Int, color: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        VStack(spacing: 0) {
            if appState.testCoverageManager.coverageTrends.isEmpty {
                emptyState
            } else {
                // Coverage trend visualization
                VStack(spacing: 12) {
                    HStack {
                        Text(localization.localized(.testCoverageTrend))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        if let latest = appState.testCoverageManager.coverageTrends.last {
                            Text("\(Int(latest.coverage * 100))%")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(coverageColor(latest.coverage))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Simple trend chart
                    trendChart
                        .frame(height: 150)
                        .padding(.horizontal, 16)

                    Divider().background(Color.white.opacity(0.1))

                    // Trend data list
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(appState.testCoverageManager.coverageTrends.reversed()) { trend in
                                HStack(spacing: 8) {
                                    Text(formatDate(trend.date))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 80, alignment: .leading)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.white.opacity(0.05))
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(coverageColor(trend.coverage))
                                                .frame(width: geo.size.width * trend.coverage)
                                        }
                                    }
                                    .frame(height: 6)

                                    Text("\(Int(trend.coverage * 100))%")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(coverageColor(trend.coverage))
                                        .frame(width: 36, alignment: .trailing)

                                    Text("\(trend.testCount) tests")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                        .frame(width: 60, alignment: .trailing)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }

    private var trendChart: some View {
        GeometryReader { geo in
            let trends = appState.testCoverageManager.coverageTrends
            let count = trends.count
            guard count > 1 else {
                return AnyView(EmptyView())
            }

            let stepX = geo.size.width / CGFloat(count - 1)
            let points = trends.enumerated().map { index, trend in
                CGPoint(
                    x: CGFloat(index) * stepX,
                    y: geo.size.height * (1 - trend.coverage)
                )
            }

            return AnyView(
                ZStack {
                    // Grid lines
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                        Path { path in
                            let y = geo.size.height * (1 - level)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    }

                    // Line
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color(hex: "#8BC34A"), lineWidth: 2)

                    // Area fill
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#8BC34A").opacity(0.2), Color(hex: "#8BC34A").opacity(0.02)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Data points
                    ForEach(0..<points.count, id: \.self) { i in
                        Circle()
                            .fill(Color(hex: "#8BC34A"))
                            .frame(width: 4, height: 4)
                            .position(points[i])
                    }
                }
            )
        }
    }

    // MARK: - Shared Components

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#8BC34A"))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.15))
            Text(localization.localized(.testNoData))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
        }
    }

    private func coverageColor(_ coverage: Double) -> Color {
        if coverage >= 0.8 { return Color(hex: "#4CAF50") }
        if coverage >= 0.5 { return Color(hex: "#FF9800") }
        return Color(hex: "#F44336")
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86400))d ago"
    }
}
