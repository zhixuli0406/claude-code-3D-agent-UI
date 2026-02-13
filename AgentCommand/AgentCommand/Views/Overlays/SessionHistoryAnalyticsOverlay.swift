import SwiftUI

// MARK: - M4: Session History Analytics Status Overlay (right-side floating panel)

struct SessionHistoryAnalyticsOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#9C27B0").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#9C27B0").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#9C27B0"))
            Text(localization.localized(.shSessionAnalytics))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.sessionHistoryAnalyticsManager.isAnalyzing {
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
            let manager = appState.sessionHistoryAnalyticsManager

            HStack {
                Text(localization.localized(.shTotalSessions))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(manager.totalSessions)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#9C27B0"))
            }

            HStack {
                Text(localization.localized(.shProductivity))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(manager.averageProductivity * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
            }

            HStack {
                Text(localization.localized(.auTotalCost))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "$%.2f", manager.totalCostAllSessions))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            if let trend = manager.productivityTrend {
                HStack(spacing: 4) {
                    Image(systemName: trend.overallTrend.iconName)
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: trend.overallTrend.colorHex))
                    Text(trend.overallTrend.displayName)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(trend.averagePercentage)% avg")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Recent sessions
            ForEach(manager.sessions.prefix(3)) { session in
                sessionRow(session)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func sessionRow(_ session: SessionAnalytics) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: session.productivityColorHex))
                .frame(width: 5, height: 5)
            Text(session.sessionName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text("\(session.tasksCompleted) tasks")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
