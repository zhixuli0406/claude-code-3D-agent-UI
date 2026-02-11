import SwiftUI
import SceneKit

/// Floating always-on-top monitoring mini-view (D2).
/// Shows a compact overview of active agents and tasks with a mini 3D scene.
struct FloatingMonitorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    @State private var selectedTab: MonitorTab = .overview

    enum MonitorTab: String, CaseIterable {
        case overview
        case agents
        case tasks
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            headerBar

            Divider().background(Color.white.opacity(0.1))

            // Content based on tab
            switch selectedTab {
            case .overview:
                overviewTab
            case .agents:
                agentsTab
            case .tasks:
                tasksTab
            }
        }
        .background(Color(hex: "#0D1117").opacity(0.95))
        .frame(minWidth: 280, minHeight: 200)
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .font(.caption)

                Text(localization.localized(.floatingMonitor))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Opacity slider
                HStack(spacing: 4) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { appState.windowManager.floatingMonitorOpacity },
                            set: { appState.windowManager.setFloatingMonitorOpacity($0) }
                        ),
                        in: 0.3...1.0
                    )
                    .frame(width: 60)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Tab bar
            HStack(spacing: 0) {
                tabButton(.overview, icon: "gauge.with.dots.needle.33percent", label: localization.localized(.systemOverview))
                tabButton(.agents, icon: "person.3", label: localization.localized(.activeAgents))
                tabButton(.tasks, icon: "list.bullet", label: localization.localized(.activeTasks))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(Color.white.opacity(0.03))
    }

    private func tabButton(_ tab: MonitorTab, icon: String, label: String) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } }) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? Color(hex: "#00BCD4") : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selectedTab == tab ? Color(hex: "#00BCD4").opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 8) {
            // Quick stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                miniStatCard(
                    icon: "person.fill",
                    value: "\(appState.agents.count)",
                    label: localization.localized(.activeAgents),
                    color: "#2196F3"
                )
                miniStatCard(
                    icon: "list.bullet.rectangle",
                    value: "\(appState.tasks.filter { $0.status == .inProgress }.count)",
                    label: localization.localized(.activeTasks),
                    color: "#FF9800"
                )
                miniStatCard(
                    icon: "checkmark.circle",
                    value: "\(appState.tasks.filter { $0.status == .completed }.count)",
                    label: localization.localized(.taskCompleted),
                    color: "#4CAF50"
                )
                miniStatCard(
                    icon: "xmark.circle",
                    value: "\(appState.tasks.filter { $0.status == .failed }.count)",
                    label: localization.localized(.taskFailed),
                    color: "#F44336"
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            // Active agent status summary
            if !appState.agents.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(appState.agents.filter({ $0.isMainAgent })) { agent in
                        miniAgentRow(agent)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()

            // Coin balance
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(Color(hex: "#FFD700"))
                    .font(.caption2)
                Text("\(appState.coinManager.coins)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Agents Tab

    private var agentsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(appState.agents) { agent in
                    agentRow(agent)
                }
            }
            .padding(8)
        }
    }

    private func agentRow(_ agent: Agent) -> some View {
        HStack(spacing: 6) {
            Text(agent.role.emoji)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(agent.status.localizedName(localization))
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: agent.status.hexColor))
            }

            Spacer()

            Circle()
                .fill(Color(hex: agent.status.hexColor))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(agent.status == .working ? 0.05 : 0.02))
        .cornerRadius(4)
        .onTapGesture {
            appState.selectAgent(agent.id)
        }
    }

    // MARK: - Tasks Tab

    private var tasksTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(appState.tasks.filter({ $0.status == .inProgress || $0.status == .pending })) { task in
                    taskRow(task)
                }

                if appState.tasks.filter({ $0.status == .inProgress || $0.status == .pending }).isEmpty {
                    Text(localization.localized(.noQueuedTasks))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }
            }
            .padding(8)
        }
    }

    private func taskRow(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(taskStatusColor(task.status))
                    .frame(width: 6, height: 6)

                Text(task.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if task.status == .inProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                        Rectangle()
                            .fill(Color(hex: "#00BCD4"))
                            .frame(width: geo.size.width * task.progress)
                    }
                }
                .frame(height: 2)
                .cornerRadius(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.02))
        .cornerRadius(4)
        .onTapGesture {
            appState.selectTask(task.id)
        }
    }

    // MARK: - Helpers

    private func miniStatCard(icon: String, value: String, label: String, color: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: color))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: color))
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: color).opacity(0.08))
        .cornerRadius(4)
    }

    private func miniAgentRow(_ agent: Agent) -> some View {
        HStack(spacing: 4) {
            Text(agent.role.emoji)
                .font(.system(size: 10))
            Text(agent.name)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(Color(hex: agent.status.hexColor))
                .frame(width: 5, height: 5)
            Text(agent.status.localizedName(localization))
                .font(.system(size: 9))
                .foregroundColor(Color(hex: agent.status.hexColor))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func taskStatusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .inProgress: return Color(hex: "#00BCD4")
        case .completed: return Color(hex: "#4CAF50")
        case .failed: return Color(hex: "#F44336")
        }
    }
}
