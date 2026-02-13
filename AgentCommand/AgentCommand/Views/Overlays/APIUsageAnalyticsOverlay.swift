import SwiftUI

// MARK: - M3: API Usage Analytics Status Overlay (right-side floating panel)

struct APIUsageAnalyticsOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#FF9800").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF9800").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF9800"))
            Text(localization.localized(.auAPIUsageAnalytics))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.apiUsageAnalyticsManager.isMonitoring {
                Circle()
                    .fill(Color(hex: "#4CAF50"))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let manager = appState.apiUsageAnalyticsManager
            let summary = manager.summary

            HStack {
                Text(localization.localized(.auTotalCalls))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(summary.totalCalls)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF9800"))
            }

            HStack {
                Text(localization.localized(.auTotalCost))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(summary.formattedCost)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.auErrorRate))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(summary.errorRatePercentage)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: summary.errorRate > 0.1 ? "#F44336" : "#4CAF50"))
            }

            // Budget status
            if let budget = manager.budgetAlert {
                budgetRow(budget)
            }

            // Model breakdown
            ForEach(manager.modelStats.prefix(3)) { stat in
                modelRow(stat)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func budgetRow(_ budget: BudgetAlert) -> some View {
        HStack(spacing: 4) {
            Image(systemName: budget.alertLevel.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: budget.alertLevel.colorHex))
            Text(localization.localized(.auBudget))
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("\(budget.spendPercentageDisplay)%")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: budget.alertLevel.colorHex))
        }
    }

    private func modelRow(_ stat: ModelUsageStats) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(modelColor(stat.modelName))
                .frame(width: 6, height: 6)
            Text(stat.modelName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text(stat.formattedCost)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func modelColor(_ name: String) -> Color {
        if name.lowercased().contains("opus") { return Color(hex: "#9C27B0") }
        if name.lowercased().contains("sonnet") { return Color(hex: "#2196F3") }
        if name.lowercased().contains("haiku") { return Color(hex: "#4CAF50") }
        return Color(hex: "#FF9800")
    }
}
