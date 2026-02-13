import SwiftUI

// MARK: - I3: Code Quality Overlay (right-side floating panel)

struct CodeQualityOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#FF5722").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF5722").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.codeQuality))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.codeQualityManager.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let stats = appState.codeQualityManager.stats

            // Issue counts
            HStack(spacing: 8) {
                issueBadge(count: stats.errorCount, color: "#F44336", label: localization.localized(.cqErrors))
                issueBadge(count: stats.warningCount, color: "#FF9800", label: localization.localized(.cqWarnings))
                issueBadge(count: stats.infoCount, color: "#2196F3", label: localization.localized(.cqInfo))
                Spacer()
            }

            // Average complexity
            HStack {
                Text(localization.localized(.cqComplexity))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.1f", stats.avgComplexity))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.avgComplexity <= 10 ? "#4CAF50" : stats.avgComplexity <= 20 ? "#FF9800" : "#F44336"))
            }

            // Tech debt
            HStack {
                Text(localization.localized(.cqTechDebt))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.0fh", stats.totalTechDebt))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: stats.totalTechDebt <= 10 ? "#4CAF50" : stats.totalTechDebt <= 30 ? "#FF9800" : "#F44336"))
            }

            // Top issues
            let topIssues = appState.codeQualityManager.lintIssues.prefix(2)
            if !topIssues.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                ForEach(Array(topIssues)) { issue in
                    HStack(spacing: 4) {
                        Image(systemName: issue.severity.iconName)
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: issue.severity.hexColor))
                        Text(issue.message)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func issueBadge(count: Int, color: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
