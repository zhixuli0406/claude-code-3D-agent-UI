import SwiftUI

struct AgentDetailView: View {
    let agent: Agent
    let tasks: [AgentTask]
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Role icon
                Text(agent.role.emoji)
                    .font(.title)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Text(agent.role.localizedName(localization))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        StatusIndicator(status: agent.status)

                        Text(agent.status.localizedName(localization))
                            .font(.caption)
                            .foregroundColor(Color(hex: agent.status.hexColor))
                    }
                }

                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            // Agent info
            if agent.isMainAgent {
                Label("\(agent.subAgentIds.count) \(localization.localized(.subAgents))", systemImage: "person.3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Label(localization.localized(.subAgent), systemImage: "person.badge.shield.checkmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Assigned tasks
            if !tasks.isEmpty {
                Text(localization.localized(.assignedTasks))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                ForEach(tasks) { task in
                    TaskRowView(task: task)
                }
            } else {
                Text(localization.localized(.noTasksAssigned))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

struct TaskRowView: View {
    let task: AgentTask

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Task header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(task.title)
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            PriorityBadge(priority: task.priority)
                            TaskStatusBadge(status: task.status)
                        }

                        TaskProgressBar(progress: task.progress, height: 4)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded subtasks
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)

                    ForEach(task.subtasks) { subtask in
                        HStack(spacing: 6) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                                .font(.caption2)

                            Text(subtask.title)
                                .font(.caption2)
                                .foregroundColor(subtask.isCompleted ? .secondary : .white)
                                .strikethrough(subtask.isCompleted)
                        }
                        .padding(.leading, 16)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }
}
