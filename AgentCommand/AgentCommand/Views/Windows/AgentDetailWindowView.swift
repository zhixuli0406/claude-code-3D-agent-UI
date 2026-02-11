import SwiftUI

/// Detachable agent detail panel (D2) - shows agent info in a separate window.
struct AgentDetailWindowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            // Agent selector header
            agentSelectorBar

            Divider().background(Color.white.opacity(0.1))

            if let agent = appState.selectedAgent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Agent header
                        agentHeader(agent)

                        Divider().background(Color.white.opacity(0.1))

                        // Stats section
                        agentStatsSection(agent)

                        Divider().background(Color.white.opacity(0.1))

                        // Assigned tasks
                        agentTasksSection(agent)

                        Divider().background(Color.white.opacity(0.1))

                        // CLI output for active task
                        if let taskId = appState.tasks.first(where: {
                            $0.assignedAgentId == agent.id && $0.status == .inProgress
                        })?.id {
                            cliOutputSection(taskId: taskId)
                        }
                    }
                    .padding()
                }
            } else {
                emptyState
            }
        }
        .background(Color(hex: "#0D1117"))
        .frame(minWidth: 380, minHeight: 400)
    }

    // MARK: - Agent Selector Bar

    private var agentSelectorBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundColor(Color(hex: "#00BCD4"))
                .font(.title3)

            Text(localization.localized(.detachAgentPanel))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Agent picker
            if !appState.agents.isEmpty {
                Menu {
                    ForEach(appState.agents) { agent in
                        Button(action: { appState.selectAgent(agent.id) }) {
                            HStack {
                                Text(agent.role.emoji)
                                Text(agent.name)
                                Circle()
                                    .fill(Color(hex: agent.status.hexColor))
                                    .frame(width: 8, height: 8)
                                if agent.id == appState.selectedAgentId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let agent = appState.selectedAgent {
                            Text(agent.role.emoji)
                            Text(agent.name)
                                .lineLimit(1)
                        } else {
                            Text(localization.localized(.selectAgent))
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // Multi-monitor screen selector
            if NSScreen.screens.count > 1 {
                Menu {
                    ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                        Button("\(localization.localized(.moveToScreen)) \(index + 1)") {
                            moveToScreen(index)
                        }
                    }
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Agent Header

    private func agentHeader(_ agent: Agent) -> some View {
        HStack(spacing: 12) {
            // Role icon
            Text(agent.role.emoji)
                .font(.system(size: 36))
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text(agent.role.localizedName(localization))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    StatusIndicator(status: agent.status)

                    Text(agent.status.localizedName(localization))
                        .font(.caption)
                        .foregroundColor(Color(hex: agent.status.hexColor))
                }

                if agent.isMainAgent {
                    Label("\(agent.subAgentIds.count) \(localization.localized(.subAgents))", systemImage: "person.3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Stats Section

    private func agentStatsSection(_ agent: Agent) -> some View {
        let stats = appState.statsManager.statsFor(agentName: agent.name)
        return VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.agentStats))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                statCard(title: localization.localized(.level), value: "\(stats.level)", color: "#FF9800")
                statCard(title: localization.localized(.totalCompleted), value: "\(stats.totalTasksCompleted)", color: "#4CAF50")
                statCard(title: localization.localized(.successRateLabel), value: "\(Int(stats.successRate * 100))%", color: "#2196F3")
                statCard(title: "Streak", value: "\(stats.currentStreak)", color: "#E91E63")
            }
        }
    }

    private func statCard(title: String, value: String, color: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: color).opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Tasks Section

    private func agentTasksSection(_ agent: Agent) -> some View {
        let agentTasks = appState.tasks.filter { agent.assignedTaskIds.contains($0.id) }
        return VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.assignedTasks))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            if agentTasks.isEmpty {
                Text(localization.localized(.noTasksAssigned))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(agentTasks) { task in
                    TaskRowView(task: task)
                }
            }
        }
    }

    // MARK: - CLI Output Section

    private func cliOutputSection(taskId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.cliOutput))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            CLIOutputView(
                entries: appState.cliProcessManager.outputEntries(for: taskId),
                scrollToEntryId: appState.timelineManager.scrollToEntryId
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(localization.localized(.selectAgentToViewDetails))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moveToScreen(_ index: Int) {
        guard let window = NSApp.windows.first(where: { $0.title.contains("Agent") && $0.title.contains("Detail") }) else { return }
        appState.windowManager.moveWindowToScreen(window, screenIndex: index)
    }
}
