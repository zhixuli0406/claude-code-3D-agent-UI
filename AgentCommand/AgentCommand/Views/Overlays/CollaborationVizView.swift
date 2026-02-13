import SwiftUI

/// Modal sheet for Collaboration Visualization detail view (J2)
struct CollaborationVizView: View {
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

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.collabVisualization))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.collaborationVizManager.isMonitoring {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#4CAF50")).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#4CAF50"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#4CAF50").opacity(0.1))
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: localization.localized(.collabDataFlow), icon: "arrow.triangle.swap", index: 0)
            tabButton(title: localization.localized(.collabSharedResources), icon: "doc.on.doc", index: 1)
            tabButton(title: localization.localized(.collabTaskHandoffs), icon: "arrow.right.arrow.left", index: 2)
            tabButton(title: localization.localized(.collabRadarChart), icon: "chart.pie.fill", index: 3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color(hex: "#00BCD4") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#00BCD4").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: dataFlowTab
        case 1: sharedResourcesTab
        case 2: taskHandoffsTab
        case 3: radarChartTab
        default: dataFlowTab
        }
    }

    // MARK: - Data Flow Tab

    private var dataFlowTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                statBadge(icon: "arrow.triangle.swap", value: "\(appState.collaborationVizManager.stats.totalPaths)", label: localization.localized(.collabActivePaths))
                statBadge(icon: "arrow.triangle.branch", value: "\(appState.collaborationVizManager.collaborationPaths.filter { $0.isActive }.count)", label: localization.localized(.collabActive))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    if appState.collaborationVizManager.isMonitoring {
                        appState.collaborationVizManager.stopMonitoring()
                    } else {
                        appState.collaborationVizManager.startMonitoring()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.collaborationVizManager.isMonitoring ? "stop.fill" : "play.fill")
                        Text(appState.collaborationVizManager.isMonitoring ? localization.localized(.collabStopMonitoring) : localization.localized(.collabStartMonitoring))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#00BCD4").opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: { appState.toggleCollaborationVisualization() }) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isCollaborationVizInScene ? "eye.slash" : "eye")
                        Text(appState.isCollaborationVizInScene ? localization.localized(.collabHideFromScene) : localization.localized(.collabShowInScene))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if appState.collaborationVizManager.collaborationPaths.isEmpty {
                emptyState(icon: "arrow.triangle.swap", message: localization.localized(.collabNoPaths))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.collaborationVizManager.collaborationPaths) { path in
                            pathCard(path)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func pathCard(_ path: AgentCollaborationPath) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: path.direction.hexColor))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(path.dataType)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                Text("Transfers: \(path.transferCount)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            if path.isActive {
                Text("Active")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: "#4CAF50"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#4CAF50").opacity(0.1))
                    .cornerRadius(3)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Shared Resources Tab

    private var sharedResourcesTab: some View {
        VStack(spacing: 0) {
            if appState.collaborationVizManager.sharedResources.isEmpty {
                emptyState(icon: "doc.on.doc", message: localization.localized(.collabNoResources))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.collaborationVizManager.sharedResources) { resource in
                            HStack(spacing: 8) {
                                Image(systemName: resource.accessType.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: resource.accessType.hexColor))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resource.resourcePath.components(separatedBy: "/").last ?? resource.resourcePath)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("\(resource.accessingAgentIds.count) agents accessing")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.4))
                                }

                                Spacer()

                                if resource.hasConflict {
                                    HStack(spacing: 3) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 8))
                                        Text("Conflict")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(Color(hex: "#F44336"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#F44336").opacity(0.1))
                                    .cornerRadius(3)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: resource.hasConflict ? "#F44336" : "#FFFFFF").opacity(resource.hasConflict ? 0.2 : 0.06), lineWidth: 0.5))
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Task Handoffs Tab

    private var taskHandoffsTab: some View {
        VStack(spacing: 0) {
            if appState.collaborationVizManager.taskHandoffs.isEmpty {
                emptyState(icon: "arrow.right.arrow.left", message: localization.localized(.collabNoHandoffs))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.collaborationVizManager.taskHandoffs) { handoff in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(handoff.taskTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(handoff.handoffReason)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(formatTimeAgo(handoff.timestamp))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Radar Chart Tab

    private var radarChartTab: some View {
        VStack(spacing: 16) {
            Text(localization.localized(.collabRadarChart))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 16)

            if appState.collaborationVizManager.efficiencyMetrics.isEmpty {
                emptyState(icon: "chart.pie.fill", message: localization.localized(.collabNoMetrics))
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.collaborationVizManager.efficiencyMetrics) { metric in
                        HStack(spacing: 8) {
                            Text(metric.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 120, alignment: .trailing)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.1))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: metric.value >= 0.8 ? "#4CAF50" : metric.value >= 0.5 ? "#FF9800" : "#F44336"))
                                        .frame(width: geo.size.width * metric.value)
                                }
                            }
                            .frame(height: 12)

                            Text("\(Int(metric.value * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 40)
                        }
                    }
                }
                .padding(20)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9))
                Text(value).font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#00BCD4"))
            Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.4))
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon).font(.system(size: 32)).foregroundColor(.white.opacity(0.15))
            Text(message).font(.system(size: 13)).foregroundColor(.white.opacity(0.4))
            Spacer()
        }
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86400))d ago"
    }
}
