import SwiftUI

// MARK: - I1: CI/CD Status Overlay (right-side floating panel)

struct CICDStatusOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#E91E63").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#E91E63").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#E91E63"))
            Text(localization.localized(.cicdPipeline))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.cicdManager.isMonitoring {
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
            let stats = appState.cicdManager.stats

            // Success rate
            HStack {
                Text(localization.localized(.cicdSuccessRate))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(stats.successRate * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.successRate >= 0.8 ? "#4CAF50" : stats.successRate >= 0.5 ? "#FF9800" : "#F44336"))
            }

            // Pipeline count
            HStack {
                Text(localization.localized(.cicdTotalRuns))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalPipelines)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Recent pipelines
            ForEach(appState.cicdManager.pipelines.prefix(3)) { pipeline in
                pipelineRow(pipeline)
            }

            // PR count
            if !appState.cicdManager.pullRequests.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    Image(systemName: "arrow.triangle.pull")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#E91E63").opacity(0.7))
                    Text("PR")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(appState.cicdManager.pullRequests.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func pipelineRow(_ pipeline: CICDPipeline) -> some View {
        HStack(spacing: 4) {
            Image(systemName: pipeline.status.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: pipeline.status.hexColor))
            Text(pipeline.name)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text(pipeline.branch)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
        }
    }
}
