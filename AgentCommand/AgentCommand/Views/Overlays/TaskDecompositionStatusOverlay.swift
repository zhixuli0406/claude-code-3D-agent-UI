import SwiftUI

/// Floating auto-decomposition orchestration status panel
struct TaskDecompositionStatusOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if let orchestration = activeOrchestration {
                orchestrationSummary(orchestration)
                orchestrationSubTasksList(orchestration)
                orchestrationActions(orchestration)
            } else {
                emptyState
            }
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

    /// Find the first active orchestration (if any)
    private var activeOrchestration: OrchestrationState? {
        appState.orchestrator.activeOrchestrations.values.first { !$0.isFinished }
            ?? appState.orchestrator.activeOrchestrations.values.sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }).first
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF9800"))

            if let orch = activeOrchestration, !orch.isFinished {
                Text(phaseText(orch.phase).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Text(localization.localized(.taskDecomposition).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            if let orch = activeOrchestration, !orch.isFinished {
                ProgressView()
                    .scaleEffect(0.4)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(Color(hex: "#FF9800"))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    // MARK: - Orchestration Summary

    private func orchestrationSummary(_ orchestration: OrchestrationState) -> some View {
        VStack(spacing: 6) {
            metricRow(
                icon: "arrow.triangle.branch",
                label: localization.localized(.orchPhase),
                value: phaseText(orchestration.phase),
                color: phaseColor(orchestration.phase)
            )

            metricRow(
                icon: "list.bullet",
                label: localization.localized(.tdSubTasks),
                value: "\(orchestration.subTasks.count)",
                color: Color(hex: "#FF9800")
            )

            metricRow(
                icon: "checkmark.circle",
                label: localization.localized(.tdCompleted),
                value: "\(orchestration.completedCount)/\(orchestration.subTasks.count)",
                color: .green
            )

            if orchestration.phase == .executing {
                metricRow(
                    icon: "waveform.path.ecg",
                    label: localization.localized(.orchWaveProgress),
                    value: "Wave \(orchestration.currentWave)",
                    color: Color(hex: "#58A6FF")
                )
            }

            if orchestration.failedCount > 0 {
                metricRow(
                    icon: "xmark.circle",
                    label: localization.localized(.orchFailed),
                    value: "\(orchestration.failedCount)",
                    color: .red
                )
            }

            // Progress bar
            VStack(spacing: 2) {
                ProgressView(value: orchestration.progress)
                    .tint(phaseColor(orchestration.phase))

                Text("\(Int(orchestration.progress * 100))%")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(phaseColor(orchestration.phase))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(8)
    }

    // MARK: - Orchestration Sub-tasks List

    private func orchestrationSubTasksList(_ orchestration: OrchestrationState) -> some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(orchestration.subTasks) { subTask in
                        orchestrationSubTaskRow(subTask)
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 180)
        }
    }

    private func orchestrationSubTaskRow(_ subTask: OrchestratedSubTask) -> some View {
        HStack(spacing: 6) {
            // Status icon
            Image(systemName: orchStatusIcon(for: subTask.status))
                .font(.system(size: 8))
                .foregroundColor(orchStatusColor(for: subTask.status))
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(subTask.title)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                if let agentId = subTask.agentId,
                   let agent = appState.agents.first(where: { $0.id == agentId }) {
                    Text(agent.name)
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            if subTask.canParallel {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 7))
                    .foregroundColor(Color(hex: "#4CAF50").opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(orchStatusColor(for: subTask.status).opacity(0.05))
        )
    }

    // MARK: - Orchestration Actions

    private func orchestrationActions(_ orchestration: OrchestrationState) -> some View {
        VStack(spacing: 4) {
            Divider().background(Color.white.opacity(0.1))

            HStack(spacing: 6) {
                if !orchestration.isFinished {
                    Button(action: {
                        appState.orchestrator.cancelOrchestration(commanderId: orchestration.commanderId)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                            Text(localization.localized(.orchCancelDecomposition))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.15))
            Text(localization.localized(.tdNoDecomposition))
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    // MARK: - Helpers

    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func phaseText(_ phase: OrchestrationPhase) -> String {
        switch phase {
        case .decomposing: return localization.localized(.orchDecomposing)
        case .executing: return localization.localized(.orchExecuting)
        case .synthesizing: return localization.localized(.orchSynthesizing)
        case .completed: return localization.localized(.orchCompleted)
        case .failed: return localization.localized(.orchFailed)
        }
    }

    private func phaseColor(_ phase: OrchestrationPhase) -> Color {
        switch phase {
        case .decomposing: return .orange
        case .executing: return Color(hex: "#58A6FF")
        case .synthesizing: return Color(hex: "#E040FB")
        case .completed: return .green
        case .failed: return .red
        }
    }

    private func orchStatusIcon(for status: OrchestratedSubTaskStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .waiting: return "circle.dotted"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func orchStatusColor(for status: OrchestratedSubTaskStatus) -> Color {
        switch status {
        case .pending: return .white.opacity(0.3)
        case .waiting: return Color(hex: "#58A6FF")
        case .inProgress: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}
