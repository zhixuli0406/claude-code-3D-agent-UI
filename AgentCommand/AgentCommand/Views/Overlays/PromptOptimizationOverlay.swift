import SwiftUI

/// Floating overlay panel showing prompt quality score and quick suggestions (H4)
struct PromptOptimizationOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            scoreSection
            antiPatternSummary
            suggestionsSection
            statsRow
            actionButtons
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#E040FB").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#E040FB"))
            Text(localization.localized(.promptOptimization).uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            if let score = appState.promptOptimizationManager.lastScore {
                Text(score.gradeLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: score.gradeColorHex))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        VStack(spacing: 6) {
            if let score = appState.promptOptimizationManager.lastScore {
                // Overall score gauge
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: score.overallScore)
                            .stroke(Color(hex: score.gradeColorHex), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text("\(score.overallPercentage)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: score.gradeColorHex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        scoreBar(label: localization.localized(.promptClarity), value: score.clarity, color: "#00BCD4")
                        scoreBar(label: localization.localized(.promptSpecificity), value: score.specificity, color: "#4CAF50")
                        scoreBar(label: localization.localized(.promptContext), value: score.context, color: "#FF9800")
                        scoreBar(label: localization.localized(.promptActionability), value: score.actionability, color: "#E040FB")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                // Token & Cost estimate
                HStack(spacing: 12) {
                    metricPill(icon: "number", value: "\(score.estimatedTokens)", label: "tokens")
                    metricPill(icon: "dollarsign.circle", value: String(format: "$%.4f", score.estimatedCostUSD), label: localization.localized(.promptEstimatedCost))
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            } else {
                Text(localization.localized(.promptNoAnalysis))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        let suggestions = appState.promptOptimizationManager.suggestions
        return Group {
            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    ForEach(suggestions.prefix(3)) { suggestion in
                        HStack(spacing: 6) {
                            Image(systemName: suggestion.type.icon)
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: suggestion.impact.colorHex))
                                .frame(width: 14)
                            Text(suggestion.title)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                            Circle()
                                .fill(Color(hex: suggestion.impact.colorHex))
                                .frame(width: 5, height: 5)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Anti-Pattern Summary

    private var antiPatternSummary: some View {
        let aps = appState.promptOptimizationManager.detectedAntiPatterns
        return Group {
            if !aps.isEmpty {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.shield")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#F44336"))
                        Text(localization.localized(.promptIssuesDetected))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        let critical = aps.filter { $0.severity == .critical }.count
                        let warning = aps.filter { $0.severity == .warning }.count
                        if critical > 0 {
                            Text("\(critical)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#F44336"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#F44336").opacity(0.15))
                                .cornerRadius(2)
                        }
                        if warning > 0 {
                            Text("\(warning)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#FF9800"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#FF9800").opacity(0.15))
                                .cornerRadius(2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let manager = appState.promptOptimizationManager
        return VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 12) {
                statItem(label: localization.localized(.promptTotalAnalyzed), value: "\(manager.totalPromptsAnalyzed)")
                statItem(label: localization.localized(.promptAvgScore), value: "\(Int(manager.avgQualityScore * 100))%")
                if manager.activeABTests > 0 {
                    statItem(label: "A/B", value: "\(manager.activeABTests)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 6) {
                Button(action: { appState.isPromptOptimizationPanelVisible = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 9))
                        Text(localization.localized(.promptViewDetails))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#E040FB"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#E040FB").opacity(0.15))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { appState.togglePromptOptimizationVisualization() }) {
                    Image(systemName: appState.isPromptOptimizationInScene ? "cube.fill" : "cube")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#E040FB").opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(appState.isPromptOptimizationInScene
                    ? localization.localized(.promptHideFromScene)
                    : localization.localized(.promptShowInScene))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Helper Views

    private func scoreBar(label: String, value: Double, color: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 38, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: color))
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 4)
            Text("\(Int(value * 100))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: color))
                .frame(width: 22, alignment: .trailing)
        }
    }

    private func metricPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "#E040FB").opacity(0.6))
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.05))
        .cornerRadius(3)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
