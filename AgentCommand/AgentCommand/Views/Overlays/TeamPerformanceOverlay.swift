import SwiftUI

// MARK: - M5: Team Performance Status Overlay (right-side floating panel)

struct TeamPerformanceOverlay: View {
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
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.tpTeamPerformance))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.teamPerformanceManager.isAnalyzing {
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
            let manager = appState.teamPerformanceManager

            if let snapshot = manager.latestSnapshot {
                HStack {
                    Text(localization.localized(.tpEfficiency))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(snapshot.efficiencyPercentage)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: snapshot.efficiencyColorHex))
                }

                HStack {
                    Text(localization.localized(.shTotalTasks))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(snapshot.totalTasksCompleted)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                }

                HStack {
                    Text(localization.localized(.auTotalCost))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(snapshot.formattedCost)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Top performers
                ForEach(snapshot.memberMetrics.sorted { $0.efficiency > $1.efficiency }.prefix(3)) { metric in
                    memberRow(metric)
                }
            } else {
                Text(localization.localized(.tpNoData))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            if let topPerformer = manager.topPerformer {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "#FFD700"))
                    Text(topPerformer.agentName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFD700"))
                    Spacer()
                    Text("\(topPerformer.efficiencyPercentage)%")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func memberRow(_ metric: AgentPerformanceMetric) -> some View {
        HStack(spacing: 4) {
            Image(systemName: metric.specialization.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: metric.specialization.colorHex))
            Text(metric.agentName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text("\(metric.efficiencyPercentage)%")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: metric.efficiency > 0.8 ? "#4CAF50" : "#FF9800"))
        }
    }
}
