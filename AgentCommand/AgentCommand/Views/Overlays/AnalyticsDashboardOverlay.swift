import SwiftUI

// MARK: - M1: Analytics Dashboard Status Overlay (right-side floating panel)

struct AnalyticsDashboardOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#00BCD4").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#00BCD4").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.adAnalyticsDashboard))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.analyticsDashboardManager.isAnalyzing {
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
            let manager = appState.analyticsDashboardManager

            HStack {
                Text(localization.localized(.adReports))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(manager.reports.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }

            HStack {
                Text(localization.localized(.adForecasts))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(manager.forecasts.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.adPotentialSavings))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "$%.2f", manager.totalPotentialSavings))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
            }

            // Recent optimizations
            ForEach(manager.optimizations.filter { !$0.isApplied }.prefix(3)) { tip in
                optimizationRow(tip)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func optimizationRow(_ tip: CostOptimizationTip) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tip.category.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: tip.impact.colorHex))
            Text(tip.title)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text(tip.formattedSavings)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: "#4CAF50"))
        }
    }
}
