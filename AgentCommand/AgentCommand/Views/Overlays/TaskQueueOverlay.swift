import SwiftUI

/// Floating task queue panel showing pending tasks as visual cards (D1)
struct TaskQueueOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            taskList
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 10))
                .foregroundColor(.cyan)
            Text(localization.localized(.taskQueue).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text("\(appState.pendingTasksOrdered.count)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    // MARK: - Task List

    private var taskList: some View {
        Group {
            if appState.pendingTasksOrdered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(appState.pendingTasksOrdered.enumerated()), id: \.element.id) { index, task in
                            TaskQueueCard(task: task, index: index)
                        }
                        .onMove { source, destination in
                            appState.reorderTaskQueue(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 300)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.2))
            Text(localization.localized(.noQueuedTasks))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Task Queue Card

struct TaskQueueCard: View {
    let task: AgentTask
    let index: Int
    @EnvironmentObject var appState: AppState

    private var isSelected: Bool {
        appState.selectedTaskId == task.id
    }

    var body: some View {
        let cardContent = Button(action: { appState.selectTask(task.id) }) {
            HStack(spacing: 0) {
                // Priority color strip
                priorityStrip

                HStack(spacing: 6) {
                    // Drag handle
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 12)

                    // Task info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            // Priority label
                            Text(task.priority.displayName.uppercased())
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(priorityColor)

                            if task.estimatedDuration > 0 {
                                Text("·")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.system(size: 7))
                                Text(formattedEstimatedTime)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    Spacer()

                    // Queue position
                    Text("#\(index + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.cyan.opacity(0.1) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.cyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)

        cardContent
            .onDrag {
                NSItemProvider(object: "task:\(task.id.uuidString)" as NSString)
            }
    }

    // MARK: - Priority Strip

    private var priorityStrip: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(priorityColor)
            .frame(width: 3)
            .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .critical: return Color(hex: "#F44336")
        case .high: return Color(hex: "#FFC107")
        case .medium: return Color(hex: "#2196F3")
        case .low: return Color(hex: "#9E9E9E")
        }
    }

    // MARK: - Estimated Time

    private var formattedEstimatedTime: String {
        let seconds = task.estimatedDuration
        if seconds <= 0 { return "" }
        if seconds < 60 {
            return "~\(Int(seconds))s"
        } else if seconds < 3600 {
            return "~\(Int(seconds / 60))m"
        } else {
            let h = Int(seconds / 3600)
            let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return m > 0 ? "~\(h)h\(m)m" : "~\(h)h"
        }
    }
}
