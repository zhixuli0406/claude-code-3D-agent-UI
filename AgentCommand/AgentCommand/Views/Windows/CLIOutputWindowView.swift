import SwiftUI
import AppKit

/// Pop-out CLI output window (D2) - displays CLI output in a separate, resizable window.
struct CLIOutputWindowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            // Task selector header
            taskSelectorBar

            Divider().background(Color.white.opacity(0.1))

            // CLI output content
            if let taskId = appState.selectedTaskId {
                let entries = appState.cliProcessManager.outputEntries(for: taskId)
                VStack(spacing: 0) {
                    taskInfoBar(taskId: taskId)
                    cliContentView(entries: entries)
                }
            } else {
                emptyState
            }
        }
        .background(Color(hex: "#0D1117"))
        .frame(minWidth: 500, minHeight: 300)
    }

    // MARK: - Task Selector

    private var taskSelectorBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .foregroundColor(Color(hex: "#00BCD4"))
                .font(.title3)

            Text(localization.localized(.cliOutput))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Task picker
            if !appState.tasks.isEmpty {
                Menu {
                    ForEach(appState.tasks.filter({ $0.isRealExecution })) { task in
                        Button(action: { appState.selectTask(task.id) }) {
                            HStack {
                                Image(systemName: statusIcon(for: task.status))
                                Text(task.title)
                                if task.id == appState.selectedTaskId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let task = appState.selectedTask {
                            Text(task.title)
                                .lineLimit(1)
                        } else {
                            Text(localization.localized(.noTaskSelected))
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

            // Screen selector for multi-monitor
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

    // MARK: - Task Info Bar

    private func taskInfoBar(taskId: UUID) -> some View {
        HStack(spacing: 8) {
            if let task = appState.tasks.first(where: { $0.id == taskId }) {
                // Status indicator
                Circle()
                    .fill(statusColor(for: task.status))
                    .frame(width: 8, height: 8)

                Text(task.status == .inProgress ? localization.localized(.cliRunning) :
                     task.status == .completed ? localization.localized(.cliCompleted) :
                     task.status == .failed ? localization.localized(.cliFailed) : "")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor(for: task.status))

                if task.status == .inProgress {
                    Text(localization.localized(.live))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(3)
                }

                Spacer()

                // Agent name
                if let agentId = task.assignedAgentId,
                   let agent = appState.agents.first(where: { $0.id == agentId }) {
                    HStack(spacing: 4) {
                        Text(agent.role.emoji)
                            .font(.system(size: 12))
                        Text(agent.name)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Entry count
                let count = appState.cliProcessManager.outputEntries(for: taskId).count
                Text("\(count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - CLI Content

    private func cliContentView(entries: [CLIOutputEntry]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(entries) { entry in
                        CLIOutputEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: entries.count) { _, _ in
                if let last = entries.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(localization.localized(.selectTaskToViewCLI))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func statusIcon(for status: TaskStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }

    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .inProgress: return Color(hex: "#00BCD4")
        case .completed: return Color(hex: "#4CAF50")
        case .failed: return Color(hex: "#F44336")
        }
    }

    private func moveToScreen(_ index: Int) {
        guard let window = NSApp.windows.first(where: { $0.title.contains("CLI") }) else { return }
        appState.windowManager.moveWindowToScreen(window, screenIndex: index)
    }
}
