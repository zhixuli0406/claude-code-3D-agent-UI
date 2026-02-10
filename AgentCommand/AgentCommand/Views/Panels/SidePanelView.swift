import SwiftUI

struct SidePanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "command.circle.fill")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text("Agent Command")
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
                            Text("Select an agent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Click on a 3D character or select from the hierarchy above")
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
                }
                .padding(.vertical)
            }
        }
        .background(Color(hex: "#0D1117"))
    }
}
