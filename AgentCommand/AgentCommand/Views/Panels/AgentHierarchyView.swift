import SwiftUI

struct AgentHierarchyView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localization.localized(.agentHierarchy))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ForEach(appState.mainAgents()) { agent in
                AgentTreeNode(
                    agent: agent,
                    isSelected: appState.selectedAgentId == agent.id,
                    onSelect: { appState.selectAgent(agent.id) },
                    children: appState.subAgents(of: agent.id),
                    selectedAgentId: appState.selectedAgentId,
                    onSelectChild: { appState.selectAgent($0) }
                )
            }
        }
    }
}

struct AgentTreeNode: View {
    let agent: Agent
    let isSelected: Bool
    let onSelect: () -> Void
    let children: [Agent]
    let selectedAgentId: UUID?
    let onSelectChild: (UUID) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Parent agent row
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    if !children.isEmpty {
                        Button(action: { withAnimation { isExpanded.toggle() } }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer().frame(width: 12)
                    }

                    Text(agent.role.emoji)
                        .font(.caption)

                    Text(agent.name)
                        .font(.caption)
                        .fontWeight(agent.isMainAgent ? .semibold : .regular)
                        .foregroundColor(.white)

                    Spacer()

                    StatusIndicator(status: agent.status, size: 8)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Children
            if isExpanded {
                ForEach(children) { child in
                    Button(action: { onSelectChild(child.id) }) {
                        HStack(spacing: 8) {
                            Spacer().frame(width: 24)

                            // Connection line indicator
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#00BCD4").opacity(0.5))

                            Text(child.role.emoji)
                                .font(.caption)

                            Text(child.name)
                                .font(.caption)
                                .foregroundColor(.white)

                            Spacer()

                            StatusIndicator(status: child.status, size: 8)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(selectedAgentId == child.id ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
