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

            if appState.agents.isEmpty {
                Text(localization.localized(.noAgentsYet))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(appState.mainAgents()) { commander in
                    let isDisbanding = appState.disbandingTeamIds.contains(commander.id)
                    TeamSection(
                        commander: commander,
                        children: appState.subAgents(of: commander.id),
                        selectedAgentId: appState.selectedAgentId,
                        onSelectAgent: { appState.selectAgent($0) },
                        teamLabel: localization.localized(.teamLabel),
                        isDisbanding: isDisbanding,
                        onReassignAgent: { agentId, newCommanderId in
                            appState.reassignAgentToTeam(agentId: agentId, newCommanderId: newCommanderId)
                        }
                    )
                    .opacity(isDisbanding ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 0.5), value: isDisbanding)
                }
            }
        }
    }
}

// MARK: - Multi-team section

struct TeamSection: View {
    let commander: Agent
    let children: [Agent]
    let selectedAgentId: UUID?
    let onSelectAgent: (UUID) -> Void
    let teamLabel: String
    var isDisbanding: Bool = false
    var onReassignAgent: ((UUID, UUID) -> Void)?

    @State private var isExpanded = true
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Team header (expand/collapse + drop target for agent reassignment)
            Button(action: {
                withAnimation { isExpanded.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#00BCD4"))
                        .frame(width: 12)

                    Image(systemName: "person.3.fill")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#00BCD4"))

                    Text("\(teamLabel): \(commander.name)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#00BCD4"))

                    Spacer()

                    StatusIndicator(status: commander.status, size: 8)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDropTargeted ? Color(hex: "#4CAF50").opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isDropTargeted ? Color(hex: "#4CAF50").opacity(0.6) : Color.clear, lineWidth: 1.5)
                )
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .onDrop(of: [.plainText], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let payload = object as? String,
                          payload.hasPrefix("agent:") else { return }
                    let agentIdString = String(payload.dropFirst("agent:".count))
                    guard let agentId = UUID(uuidString: agentIdString) else { return }
                    DispatchQueue.main.async {
                        onReassignAgent?(agentId, commander.id)
                    }
                }
                return true
            }

            if isExpanded {
                // Commander row
                Button(action: { onSelectAgent(commander.id) }) {
                    HStack(spacing: 8) {
                        Spacer().frame(width: 16)

                        Text(commander.role.emoji)
                            .font(.caption)

                        Text(commander.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Spacer()

                        StatusIndicator(status: commander.status, size: 8)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(selectedAgentId == commander.id ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Sub-agents (draggable when idle)
                ForEach(children) { child in
                    let childRow = Button(action: { onSelectAgent(child.id) }) {
                        HStack(spacing: 8) {
                            Spacer().frame(width: 28)

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

                    if child.status == .idle {
                        childRow
                            .onDrag {
                                NSItemProvider(object: "agent:\(child.id.uuidString)" as NSString)
                            }
                    } else {
                        childRow
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.05))
                    .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Single-team tree node

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
