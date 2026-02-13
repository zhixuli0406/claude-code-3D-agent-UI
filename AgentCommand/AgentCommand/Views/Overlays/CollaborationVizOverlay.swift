import SwiftUI

// MARK: - J2: Collaboration Visualization Status Overlay (right-side floating panel)

struct CollaborationVizOverlay: View {
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
            Image(systemName: "person.3.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.collabVisualization))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.collaborationVizManager.isMonitoring {
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
            let stats = appState.collaborationVizManager.stats

            HStack {
                Text(localization.localized(.collabActivePaths))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalPaths)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.collabConflicts))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.activeConflicts)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.activeConflicts > 0 ? "#F44336" : "#4CAF50"))
            }

            HStack {
                Text(localization.localized(.collabHandoffs))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.handoffCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.collabEfficiency))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(stats.avgEfficiency * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.avgEfficiency >= 0.8 ? "#4CAF50" : stats.avgEfficiency >= 0.5 ? "#FF9800" : "#F44336"))
            }

            // Conflict alerts
            ForEach(appState.collaborationVizManager.sharedResources.filter { $0.hasConflict }.prefix(2)) { resource in
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "#F44336"))
                    Text(resource.resourcePath.components(separatedBy: "/").last ?? resource.resourcePath)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    Text("\(resource.accessingAgentIds.count)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
