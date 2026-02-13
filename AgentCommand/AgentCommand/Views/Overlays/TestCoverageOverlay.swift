import SwiftUI

// MARK: - I2: Test Coverage Overlay (right-side floating panel)

struct TestCoverageOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#8BC34A").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#8BC34A").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#8BC34A"))
            Text(localization.localized(.testCoverage))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.testCoverageManager.isRunningTests {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            if let report = appState.testCoverageManager.currentReport {
                // Overall coverage
                HStack {
                    Text(localization.localized(.testOverallCoverage))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(report.overallCoverage * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(coverageColor(report.overallCoverage))
                }

                // Coverage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(coverageColor(report.overallCoverage))
                            .frame(width: geo.size.width * report.overallCoverage)
                    }
                }
                .frame(height: 4)

                // Test results
                HStack(spacing: 8) {
                    testBadge(count: report.passedTests, color: "#4CAF50", icon: "checkmark")
                    testBadge(count: report.failedTests, color: "#F44336", icon: "xmark")
                    testBadge(count: report.skippedTests, color: "#9E9E9E", icon: "minus")
                    Spacer()
                    Text("\(report.totalTests) \(localization.localized(.testTotal))")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Low coverage files
                let lowCoverage = report.fileCoverages.filter { $0.coverage < 0.5 }.prefix(2)
                if !lowCoverage.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    ForEach(Array(lowCoverage)) { file in
                        HStack {
                            Text(file.fileName)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(file.coverage * 100))%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: file.coverageColor))
                        }
                    }
                }
            } else {
                Text(localization.localized(.testNoData))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func testBadge(count: Int, color: String, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 7))
                .foregroundColor(Color(hex: color))
            Text("\(count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: color))
        }
    }

    private func coverageColor(_ coverage: Double) -> Color {
        if coverage >= 0.8 { return Color(hex: "#4CAF50") }
        if coverage >= 0.5 { return Color(hex: "#FF9800") }
        return Color(hex: "#F44336")
    }
}
