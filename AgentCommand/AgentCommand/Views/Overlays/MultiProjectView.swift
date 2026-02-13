import SwiftUI

/// Modal sheet for multi-project workspace view (I4)
struct MultiProjectView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var searchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .frame(width: 700, height: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#673AB7"))
            Text(localization.localized(.multiProject))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text("\(appState.multiProjectManager.projects.count) \(localization.localized(.mpProjects))")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#673AB7").opacity(0.1))
                .cornerRadius(4)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: localization.localized(.mpProjects), icon: "folder.fill", index: 0)
            tabButton(title: localization.localized(.mpSearch), icon: "magnifyingglass", index: 1)
            tabButton(title: localization.localized(.mpComparison), icon: "chart.bar.fill", index: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color(hex: "#673AB7") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#673AB7").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: projectsTab
        case 1: searchTab
        case 2: comparisonTab
        default: projectsTab
        }
    }

    // MARK: - Projects Tab

    private var projectsTab: some View {
        VStack(spacing: 0) {
            // Summary stats
            HStack(spacing: 16) {
                let totalAgents = appState.multiProjectManager.projects.reduce(0) { $0 + $1.activeAgentCount }
                let totalTasks = appState.multiProjectManager.projects.reduce(0) { $0 + $1.totalTasks }
                statBadge(icon: "folder.fill", value: "\(appState.multiProjectManager.projects.count)", label: localization.localized(.mpProjects))
                statBadge(icon: "person.2.fill", value: "\(totalAgents)", label: localization.localized(.mpAgentCount))
                statBadge(icon: "checkmark.circle", value: "\(totalTasks)", label: localization.localized(.mpTaskCount))
                Spacer()

                // Add project button
                Button(action: { addProjectViaOpenPanel() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text(localization.localized(.mpAddProject))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#673AB7").opacity(0.5))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Project list
            if appState.multiProjectManager.projects.isEmpty {
                emptyState(icon: "square.stack.3d.up", message: localization.localized(.mpNoProjects))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.multiProjectManager.projects) { project in
                            projectCard(project)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func projectCard(_ project: ProjectWorkspace) -> some View {
        HStack(spacing: 12) {
            // Project icon
            Circle()
                .fill(Color(hex: project.iconColor))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(project.isActive ? 0.8 : 0), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    if project.isActive {
                        Text(localization.localized(.mpActive))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#4CAF50"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#4CAF50").opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                Text(project.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8))
                        Text("\(project.activeAgentCount)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: "#673AB7").opacity(0.7))

                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 8))
                        Text("\(project.completedTasks)/\(project.totalTasks)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.4))

                    if project.failedTasks > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 8))
                            Text("\(project.failedTasks)")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundColor(Color(hex: "#F44336").opacity(0.7))
                    }

                    if let lastActivity = project.lastActivityAt {
                        Text(formatTimeAgo(lastActivity))
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            Spacer()

            VStack(spacing: 4) {
                // Switch button
                if !project.isActive {
                    Button(action: { appState.multiProjectManager.switchToProject(project.id) }) {
                        Text(localization.localized(.mpSwitchProject))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#673AB7").opacity(0.3))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                // Remove button
                Button(action: { appState.multiProjectManager.removeProject(project.id) }) {
                    Text(localization.localized(.mpRemoveProject))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.red.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(project.isActive ? 0.05 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: project.isActive ? "#673AB7" : "#FFFFFF").opacity(project.isActive ? 0.2 : 0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))

                TextField(localization.localized(.mpSearch), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Search results
            let results = appState.multiProjectManager.searchTasks(query: searchQuery)
            if searchQuery.isEmpty {
                emptyState(icon: "magnifyingglass", message: localization.localized(.mpSearch))
            } else if results.isEmpty {
                emptyState(icon: "magnifyingglass", message: localization.localized(.mpNoProjects))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(results) { task in
                            searchResultRow(task)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func searchResultRow(_ task: CrossProjectTask) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.taskTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 8))
                        Text(task.projectName)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(Color(hex: "#673AB7").opacity(0.7))

                    HStack(spacing: 3) {
                        Image(systemName: "person")
                            .font(.system(size: 8))
                        Text(task.agentName)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.4))

                    Text(task.status)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(2)

                    Text(formatTimeAgo(task.createdAt))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Comparison Tab

    private var comparisonTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text(localization.localized(.mpComparison))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()

                Button(action: { appState.multiProjectManager.generateComparison() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text(localization.localized(.mpComparison))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#673AB7").opacity(0.3))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            if let comparison = appState.multiProjectManager.comparison {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(comparison.projects) { metrics in
                            comparisonCard(metrics)
                        }
                    }
                    .padding(12)
                }
            } else if appState.multiProjectManager.projects.isEmpty {
                emptyState(icon: "chart.bar.fill", message: localization.localized(.mpNoProjects))
            } else {
                emptyState(icon: "chart.bar.fill", message: localization.localized(.mpComparison))
            }
        }
    }

    private func comparisonCard(_ metrics: ProjectMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metrics.projectName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                metricItem(icon: "checkmark.circle", value: "\(metrics.completedTasks)/\(metrics.totalTasks)", label: localization.localized(.mpTaskCount))
                metricItem(icon: "person.2.fill", value: "\(metrics.agentCount)", label: localization.localized(.mpAgentCount))
                metricItem(icon: "clock", value: formatDuration(metrics.avgDuration), label: "Avg Duration")
                metricItem(icon: "dollarsign.circle", value: String(format: "$%.2f", metrics.totalCost), label: "Cost")
            }

            // Completion bar
            let completionRate = metrics.totalTasks > 0 ? Double(metrics.completedTasks) / Double(metrics.totalTasks) : 0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#673AB7"))
                        .frame(width: geo.size.width * completionRate)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#673AB7").opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private func metricItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#673AB7"))
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Shared Components

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#673AB7"))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.15))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
        }
    }

    // MARK: - Actions

    private func addProjectViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = localization.localized(.mpAddProject)

        if panel.runModal() == .OK, let url = panel.url {
            let name = url.lastPathComponent
            appState.multiProjectManager.addProject(name: name, path: url.path)
        }
    }

    // MARK: - Formatters

    private func formatTimeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86400))d ago"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return String(format: "%.0fs", seconds) }
        if seconds < 3600 { return String(format: "%.0fm", seconds / 60) }
        return String(format: "%.1fh", seconds / 3600)
    }
}
