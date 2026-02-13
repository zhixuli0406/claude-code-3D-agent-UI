import SwiftUI

/// Modal sheet for Docker / dev environment view (I5)
struct DockerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var selectedContainerId: String?

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
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#0DB7ED"))
            Text(localization.localized(.dockerContainers))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.dockerManager.isMonitoring {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#4CAF50"))
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#4CAF50"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#4CAF50").opacity(0.1))
                .cornerRadius(4)
            }

            let stats = appState.dockerManager.stats
            HStack(spacing: 6) {
                containerCountBadge(count: stats.runningContainers, color: "#4CAF50", label: localization.localized(.dockerRunning))
                containerCountBadge(count: stats.stoppedContainers, color: "#9E9E9E", label: localization.localized(.dockerStopped))
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    private func containerCountBadge(count: Int, color: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: color).opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: localization.localized(.dockerContainers), icon: "shippingbox", index: 0)
            tabButton(title: localization.localized(.dockerLogs), icon: "text.alignleft", index: 1)
            tabButton(title: localization.localized(.dockerResources), icon: "gauge.with.dots.needle.50percent", index: 2)
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
            .foregroundColor(selectedTab == index ? Color(hex: "#0DB7ED") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#0DB7ED").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: containersTab
        case 1: logsTab
        case 2: resourcesTab
        default: containersTab
        }
    }

    // MARK: - Containers Tab

    private var containersTab: some View {
        VStack(spacing: 0) {
            // Summary stats
            let stats = appState.dockerManager.stats
            HStack(spacing: 16) {
                statBadge(icon: "shippingbox.fill", value: "\(stats.totalContainers)", label: localization.localized(.dockerContainers))
                statBadge(icon: "play.circle.fill", value: "\(stats.runningContainers)", label: localization.localized(.dockerRunning))
                statBadge(icon: "stop.circle.fill", value: "\(stats.stoppedContainers)", label: localization.localized(.dockerStopped))

                Spacer()

                // Start monitoring button
                Button(action: {
                    if appState.dockerManager.isMonitoring {
                        appState.dockerManager.stopMonitoring()
                    } else {
                        appState.dockerManager.startMonitoring()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.dockerManager.isMonitoring ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(appState.dockerManager.isMonitoring
                             ? localization.localized(.dockerStopMonitoring)
                             : localization.localized(.dockerStartMonitoring))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#0DB7ED").opacity(0.5))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Container list
            if appState.dockerManager.containers.isEmpty {
                emptyState(icon: "shippingbox", message: localization.localized(.dockerNoContainers))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.dockerManager.containers) { container in
                            containerCard(container)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func containerCard(_ container: DockerContainer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: container.status.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: container.status.hexColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(container.image)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // Container actions
                HStack(spacing: 4) {
                    if container.status == .running {
                        actionButton(icon: "stop.fill", color: "#F44336") {
                            appState.dockerManager.stopContainer(container.containerId)
                        }
                        actionButton(icon: "arrow.clockwise", color: "#FF9800") {
                            appState.dockerManager.restartContainer(container.containerId)
                        }
                    } else {
                        actionButton(icon: "play.fill", color: "#4CAF50") {
                            appState.dockerManager.startContainer(container.containerId)
                        }
                    }

                    // View logs
                    actionButton(icon: "text.alignleft", color: "#0DB7ED") {
                        selectedContainerId = container.containerId
                        appState.dockerManager.fetchLogs(containerId: container.containerId)
                        selectedTab = 1
                    }
                }
            }

            // Resource usage for running containers
            if container.status == .running {
                HStack(spacing: 16) {
                    // CPU
                    HStack(spacing: 4) {
                        Text(localization.localized(.dockerCPU))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                        Text(String(format: "%.1f%%", container.cpuUsage))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: container.cpuUsage < 50 ? "#4CAF50" : container.cpuUsage < 80 ? "#FF9800" : "#F44336"))
                    }

                    // Memory
                    HStack(spacing: 4) {
                        Text(localization.localized(.dockerMemory))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                        Text(formatMemory(container.memoryUsage))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        Text("/ \(formatMemory(container.memoryLimit))")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    // Network
                    HStack(spacing: 4) {
                        Text(localization.localized(.dockerNetwork))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                        Text("\(formatBytes(container.networkIn))\u{2191} \(formatBytes(container.networkOut))\u{2193}")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Ports
                    if !container.ports.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(container.ports, id: \.hostPort) { port in
                                Text("\(port.hostPort):\(port.containerPort)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(Color(hex: "#0DB7ED").opacity(0.7))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color(hex: "#0DB7ED").opacity(0.1))
                                    .cornerRadius(2)
                            }
                        }
                    }
                }

                // Memory usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.05))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: container.memoryUsagePercent < 0.5 ? "#4CAF50" : container.memoryUsagePercent < 0.8 ? "#FF9800" : "#F44336"))
                            .frame(width: geo.size.width * container.memoryUsagePercent)
                    }
                }
                .frame(height: 3)
            }

            // Container ID
            HStack(spacing: 6) {
                Text(container.containerId)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))

                if let uptime = container.uptime {
                    Text("up \(formatUptime(uptime))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: container.status.hexColor).opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func actionButton(icon: String, color: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: color))
                .frame(width: 24, height: 24)
                .background(Color(hex: color).opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logs Tab

    private var logsTab: some View {
        VStack(spacing: 0) {
            // Container selector
            HStack(spacing: 8) {
                Text(localization.localized(.dockerLogs))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Container picker
                if !appState.dockerManager.containers.isEmpty {
                    Menu {
                        ForEach(appState.dockerManager.containers) { container in
                            Button(action: {
                                selectedContainerId = container.containerId
                                appState.dockerManager.fetchLogs(containerId: container.containerId)
                            }) {
                                HStack {
                                    Image(systemName: container.status.iconName)
                                    Text(container.name)
                                    if selectedContainerId == container.containerId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 10))
                            Text(selectedContainerName())
                                .font(.system(size: 11))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Log entries
            if appState.dockerManager.logEntries.isEmpty {
                emptyState(icon: "text.alignleft", message: localization.localized(.dockerLogs))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(appState.dockerManager.logEntries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(formatLogTimestamp(entry.timestamp))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.25))
                                    .frame(width: 60, alignment: .leading)

                                Text(entry.stream == .stderr ? "ERR" : "OUT")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(entry.stream == .stderr ? Color(hex: "#F44336") : Color(hex: "#0DB7ED"))
                                    .frame(width: 24)

                                Text(entry.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(entry.stream == .stderr ? Color(hex: "#F44336").opacity(0.8) : .white.opacity(0.7))
                                    .lineLimit(3)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.black.opacity(0.2))
            }
        }
    }

    private func selectedContainerName() -> String {
        if let id = selectedContainerId,
           let container = appState.dockerManager.containers.first(where: { $0.containerId == id }) {
            return container.name
        }
        return localization.localized(.dockerContainers)
    }

    // MARK: - Resources Tab

    private var resourcesTab: some View {
        VStack(spacing: 0) {
            // Current resource usage
            let stats = appState.dockerManager.stats
            HStack(spacing: 20) {
                resourceGauge(label: localization.localized(.dockerCPU), value: stats.totalCPU, maxValue: 100, unit: "%", color: "#0DB7ED")
                resourceGauge(label: localization.localized(.dockerMemory), value: stats.totalMemory, maxValue: 2048, unit: "MB", color: "#8BC34A")
                resourceGauge(label: "\u{2191} " + localization.localized(.dockerNetwork), value: stats.totalNetworkIn / 1024, maxValue: 1024, unit: "KB", color: "#FF9800")
                resourceGauge(label: "\u{2193} " + localization.localized(.dockerNetwork), value: stats.totalNetworkOut / 1024, maxValue: 1024, unit: "KB", color: "#9C27B0")
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Resource history
            if appState.dockerManager.resourceHistory.isEmpty {
                emptyState(icon: "gauge.with.dots.needle.50percent", message: localization.localized(.dockerResources))
            } else {
                // Per-container resource breakdown
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.dockerManager.containers.filter { $0.status == .running }) { container in
                            containerResourceRow(container)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func resourceGauge(label: String, value: Double, maxValue: Double, unit: String, color: String) -> some View {
        VStack(spacing: 4) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 4)
                    .frame(width: 50, height: 50)

                let progress = min(value / maxValue, 1.0)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: color), lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(String(format: "%.0f", value))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: color))
                    Text(unit)
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func containerResourceRow(_ container: DockerContainer) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#0DB7ED"))
                .frame(width: 16)

            Text(container.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 120, alignment: .leading)

            // CPU bar
            VStack(spacing: 1) {
                Text(localization.localized(.dockerCPU))
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.3))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.05))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: container.cpuUsage < 50 ? "#4CAF50" : container.cpuUsage < 80 ? "#FF9800" : "#F44336"))
                            .frame(width: geo.size.width * min(container.cpuUsage / 100, 1.0))
                    }
                }
                .frame(height: 4)
            }

            Text(String(format: "%.1f%%", container.cpuUsage))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 42, alignment: .trailing)

            // Memory bar
            VStack(spacing: 1) {
                Text(localization.localized(.dockerMemory))
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.3))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.05))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: container.memoryUsagePercent < 0.5 ? "#4CAF50" : container.memoryUsagePercent < 0.8 ? "#FF9800" : "#F44336"))
                            .frame(width: geo.size.width * container.memoryUsagePercent)
                    }
                }
                .frame(height: 4)
            }

            Text(formatMemory(container.memoryUsage))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 54, alignment: .trailing)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
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
            .foregroundColor(Color(hex: "#0DB7ED"))
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

    // MARK: - Formatters

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1fMB", bytes / 1_000_000)
        }
        if bytes >= 1000 {
            return String(format: "%.0fKB", bytes / 1000)
        }
        return String(format: "%.0fB", bytes)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86400))d"
    }

    private func formatLogTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
