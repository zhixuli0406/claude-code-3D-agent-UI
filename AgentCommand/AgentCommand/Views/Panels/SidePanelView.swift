import SwiftUI

struct SidePanelView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "command.circle.fill")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(localization.localized(.agentCommandTitle))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.03))

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Agent hierarchy
                    AgentHierarchyView()
                        .padding(.horizontal)

                    Divider().background(Color.white.opacity(0.1))
                        .padding(.horizontal)

                    // Selected agent detail
                    if let agent = appState.selectedAgent {
                        AgentDetailView(
                            agent: agent,
                            tasks: appState.tasksForSelectedAgent
                        )
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text(localization.localized(.selectAnAgent))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(localization.localized(.clickOnAgentHelpText))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                    Divider().background(Color.white.opacity(0.1))
                        .padding(.horizontal)

                    // Task list
                    TaskListView(tasks: appState.tasks)
                        .padding(.horizontal)

                    // Task team for selected task
                    if let task = appState.selectedTask {
                        let team = appState.teamForSelectedTask
                        if !team.isEmpty {
                            Divider().background(Color.white.opacity(0.1))
                                .padding(.horizontal)

                            TaskTeamView(
                                team: team,
                                leadAgentId: task.assignedAgentId
                            )
                            .padding(.horizontal)
                        }
                    }

                    // CLI output for selected task
                    if let taskId = appState.selectedTaskId {
                        Divider().background(Color.white.opacity(0.1))
                            .padding(.horizontal)

                        CLIOutputView(
                            entries: appState.cliProcessManager.outputEntries(for: taskId),
                            scrollToEntryId: appState.timelineManager.scrollToEntryId
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color(hex: "#0D1117"))
    }
}
