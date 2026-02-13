import SwiftUI

/// Modal sheet for auto-decomposition orchestration management
struct TaskDecompositionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            header
            if let orchestration = activeOrchestration {
                executionContent(orchestration)
            } else {
                executionEmptyState
            }
        }
        .frame(width: 720, height: 600)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#FF9800"))
            Text(localization.localized(.taskDecomposition))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if let orch = activeOrchestration, !orch.isFinished {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(executionPhaseText(orch.phase))
                        .font(.system(size: 11))
                        .foregroundColor(executionPhaseColor(orch.phase))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(executionPhaseColor(orch.phase).opacity(0.1))
                .cornerRadius(4)
            } else if let orch = activeOrchestration {
                HStack(spacing: 4) {
                    Circle()
                        .fill(executionPhaseColor(orch.phase))
                        .frame(width: 6, height: 6)
                    Text("\(orch.subTasks.count) \(localization.localized(.tdSubTasks).lowercased())")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Button(action: { appState.isTaskDecompositionViewVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Active Orchestration

    private var activeOrchestration: OrchestrationState? {
        appState.orchestrator.activeOrchestrations.values.first { !$0.isFinished }
            ?? appState.orchestrator.activeOrchestrations.values
                .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
                .first
    }

    // MARK: - Execution Content

    private func executionContent(_ orchestration: OrchestrationState) -> some View {
        VStack(spacing: 0) {
            // Phase indicator
            HStack(spacing: 12) {
                executionPhaseBadge(orchestration.phase)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(orchestration.originalPrompt.prefix(60)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(orchestration.completedCount)/\(orchestration.subTasks.count) \(localization.localized(.tdSubTasks).lowercased())")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))

                        if orchestration.phase == .executing {
                            Text("Wave \(orchestration.currentWave)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: "#58A6FF"))
                        }
                    }
                }

                Spacer()

                if !orchestration.isFinished {
                    Button(action: {
                        appState.orchestrator.cancelOrchestration(commanderId: orchestration.commanderId)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            // Progress bar
            ProgressView(value: orchestration.progress)
                .tint(executionPhaseColor(orchestration.phase))
                .padding(.horizontal, 16)

            Divider().background(Color.white.opacity(0.1)).padding(.top, 8)

            // Sub-agent cards
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(orchestration.subTasks) { subTask in
                        executionSubTaskCard(subTask)
                    }
                }
                .padding(12)
            }
        }
    }

    private func executionSubTaskCard(_ subTask: OrchestratedSubTask) -> some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(executionSubTaskColor(subTask.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subTask.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(subTask.estimatedComplexity.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(2)

                    if subTask.canParallel {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#4CAF50"))
                    }
                }

                HStack(spacing: 8) {
                    if let agentId = subTask.agentId,
                       let agent = appState.agents.first(where: { $0.id == agentId }) {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 8))
                            Text(agent.name)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(Color(hex: "#58A6FF"))
                    }

                    Text(subTask.status.rawValue)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(executionSubTaskColor(subTask.status))
                }

                // Show preview of result or error
                if let result = subTask.result {
                    Text(String(result.prefix(100)))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(2)
                } else if let error = subTask.error {
                    Text("Error: \(String(error.prefix(80)))")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(executionSubTaskColor(subTask.status).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(executionSubTaskColor(subTask.status).opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var executionEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.15))
            Text(localization.localized(.tdNoDecomposition))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Text(localization.localized(.tdEnterTaskHint))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Phase Helpers

    private func executionPhaseBadge(_ phase: OrchestrationPhase) -> some View {
        HStack(spacing: 4) {
            if phase == .decomposing || phase == .synthesizing || phase == .executing {
                ProgressView()
                    .scaleEffect(0.4)
                    .frame(width: 10, height: 10)
            }
            Text(executionPhaseText(phase))
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(executionPhaseColor(phase))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(executionPhaseColor(phase).opacity(0.15))
        .cornerRadius(4)
    }

    private func executionPhaseText(_ phase: OrchestrationPhase) -> String {
        switch phase {
        case .decomposing: return localization.localized(.orchDecomposing)
        case .executing: return localization.localized(.orchExecuting)
        case .synthesizing: return localization.localized(.orchSynthesizing)
        case .completed: return localization.localized(.orchCompleted)
        case .failed: return localization.localized(.orchFailed)
        }
    }

    private func executionPhaseColor(_ phase: OrchestrationPhase) -> Color {
        switch phase {
        case .decomposing: return .orange
        case .executing: return Color(hex: "#58A6FF")
        case .synthesizing: return Color(hex: "#E040FB")
        case .completed: return .green
        case .failed: return .red
        }
    }

    private func executionSubTaskColor(_ status: OrchestratedSubTaskStatus) -> Color {
        switch status {
        case .pending: return .white.opacity(0.3)
        case .waiting: return Color(hex: "#58A6FF")
        case .inProgress: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}
