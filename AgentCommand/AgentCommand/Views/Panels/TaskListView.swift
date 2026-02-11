import SwiftUI

struct TaskListView: View {
    let tasks: [AgentTask]
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with summary
            HStack {
                Text(localization.localized(.allTasks))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Text("\(completedCount)/\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Overall progress
            TaskProgressBar(progress: overallProgress, height: 4, showPercentage: true)

            // Task list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(sortedTasks) { task in
                        TaskCompactRow(task: task)
                    }
                }
            }
        }
    }

    private var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    private var overallProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        return tasks.map(\.progress).reduce(0, +) / Double(tasks.count)
    }

    private var sortedTasks: [AgentTask] {
        tasks.sorted { $0.priority.sortOrder > $1.priority.sortOrder }
    }
}

struct TaskCompactRow: View {
    let task: AgentTask
    @EnvironmentObject var appState: AppState

    private var isSelected: Bool {
        appState.selectedTaskId == task.id
    }

    private var isDraggable: Bool {
        task.status == .pending
    }

    var body: some View {
        let rowContent = Button(action: { appState.selectTask(task.id) }) {
            HStack(spacing: 8) {
                // Drag handle for pending tasks
                if isDraggable {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 12)
                }

                // Status icon
                Image(systemName: statusIcon)
                    .foregroundColor(Color(hex: task.status.hexColor))
                    .font(.caption)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    TaskProgressBar(progress: task.progress, height: 3)
                }

                if task.isRealExecution {
                    Text("CLI")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(3)
                }

                PriorityBadge(priority: task.priority)

                if task.isRealExecution && task.status == .inProgress {
                    Button(action: { appState.cancelTask(task.id) }) {
                        Image(systemName: "xmark.circle")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color(hex: "#00BCD4").opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color(hex: "#00BCD4").opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)

        if isDraggable {
            rowContent
                .onDrag {
                    NSItemProvider(object: "task:\(task.id.uuidString)" as NSString)
                }
        } else {
            rowContent
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

struct TaskDetailView: View {
    let task: AgentTask
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                TaskStatusBadge(status: task.status)
            }

            Text(task.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider().background(Color.white.opacity(0.1))

            TaskProgressBar(progress: task.progress, height: 8, showPercentage: true)

            Text(localization.localized(.subtasks))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            ForEach(task.subtasks) { subtask in
                HStack(spacing: 8) {
                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(subtask.isCompleted ? .green : .secondary)

                    Text(subtask.title)
                        .foregroundColor(subtask.isCompleted ? .secondary : .white)
                        .strikethrough(subtask.isCompleted)
                }
                .font(.caption)
            }
        }
        .padding()
    }
}
