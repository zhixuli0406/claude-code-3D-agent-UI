import SwiftUI

/// Modal sheet for Data Flow Animation detail view (J4)
struct DataFlowDetailView: View {
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
        .onAppear {
            if !appState.dataFlowAnimationManager.isAnimating {
                appState.dataFlowAnimationManager.startAnimating()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.dataFlowAnimation))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.dataFlowAnimationManager.isAnimating {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#4CAF50")).frame(width: 6, height: 6)
                    Text("STREAMING")
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
            tabButton(title: localization.localized(.dfTokenStream), icon: "waveform.path", index: 0)
            tabButton(title: localization.localized(.dfIOPipeline), icon: "arrow.up.arrow.down", index: 1)
            tabButton(title: localization.localized(.dfToolChain), icon: "wrench.and.screwdriver.fill", index: 2)
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
        case 0: tokenStreamTab
        case 1: ioPipelineTab
        case 2: toolChainTab
        default: tokenStreamTab
        }
    }

    // MARK: - Token Stream Tab

    private var tokenStreamTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                statBadge(icon: "arrow.up.circle.fill", value: "\(appState.dataFlowAnimationManager.stats.totalTokensIn)", label: localization.localized(.dfTokensIn))
                statBadge(icon: "arrow.down.circle.fill", value: "\(appState.dataFlowAnimationManager.stats.totalTokensOut)", label: localization.localized(.dfTokensOut))
                statBadge(icon: "bolt.fill", value: "\(appState.dataFlowAnimationManager.stats.activeFlows)", label: localization.localized(.dfActiveFlows))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Action buttons
            HStack(spacing: 8) {
                Button(action: { appState.toggleDataFlowVisualization() }) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isDataFlowInScene ? "eye.slash" : "eye")
                        Text(appState.isDataFlowInScene ? localization.localized(.dfHideFromScene) : localization.localized(.dfShowInScene))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#00BCD4").opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if appState.dataFlowAnimationManager.tokenFlows.isEmpty {
                emptyState(icon: "waveform.path", message: localization.localized(.dfNoFlows))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.dataFlowAnimationManager.tokenFlows.reversed()) { flow in
                            HStack(spacing: 8) {
                                Image(systemName: flow.flowType.iconName)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: flow.flowType.hexColor))
                                    .frame(width: 16)
                                Text(flow.flowType.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text("\(flow.tokenCount) tokens")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                Circle()
                                    .fill(Color(hex: flow.isActive ? "#4CAF50" : "#9E9E9E"))
                                    .frame(width: 6, height: 6)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - IO Pipeline Tab

    private var ioPipelineTab: some View {
        VStack(spacing: 0) {
            if appState.dataFlowAnimationManager.pipelineStages.isEmpty {
                emptyState(icon: "arrow.up.arrow.down", message: localization.localized(.dfNoPipeline))
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(appState.dataFlowAnimationManager.pipelineStages) { stage in
                            HStack(spacing: 8) {
                                // Status indicator
                                Circle()
                                    .fill(Color(hex: stage.status.hexColor))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stage.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(stage.flowType.displayName)
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.4))
                                }

                                Spacer()

                                Text("\(stage.dataSize) tokens")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

                                Text(stage.status.rawValue.capitalized)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Color(hex: stage.status.hexColor))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: stage.status.hexColor).opacity(0.1))
                                    .cornerRadius(3)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.03))
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Tool Chain Tab

    private var toolChainTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                statBadge(icon: "wrench.and.screwdriver.fill", value: "\(appState.dataFlowAnimationManager.stats.totalToolCalls)", label: localization.localized(.dfToolCalls))
                statBadge(icon: "clock", value: String(format: "%.1fs", appState.dataFlowAnimationManager.stats.avgResponseTime), label: localization.localized(.dfAvgResponseTime))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            if appState.dataFlowAnimationManager.toolCallChain.isEmpty {
                emptyState(icon: "wrench.and.screwdriver.fill", message: localization.localized(.dfNoToolCalls))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.dataFlowAnimationManager.toolCallChain) { call in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("#\(call.sequenceIndex + 1)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: "#E91E63"))
                                    Text(call.toolName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if let dur = call.duration {
                                        Text(String(format: "%.2fs", dur))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }

                                Text("Input: \(call.input)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)

                                if let output = call.output {
                                    Text("Output: \(output)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color(hex: "#4CAF50").opacity(0.6))
                                        .lineLimit(1)
                                }
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
}
