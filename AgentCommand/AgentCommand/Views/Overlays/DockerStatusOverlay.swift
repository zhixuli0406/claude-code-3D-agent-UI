import SwiftUI

// MARK: - I5: Docker Status Overlay (right-side floating panel)

struct DockerStatusOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#0DB7ED").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#0DB7ED").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#0DB7ED"))
            Text(localization.localized(.dockerContainers))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.dockerManager.isMonitoring {
                Circle()
                    .fill(Color(hex: "#4CAF50"))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let stats = appState.dockerManager.stats

            // Container counts
            HStack(spacing: 8) {
                containerBadge(count: stats.runningContainers, color: "#4CAF50", label: localization.localized(.dockerRunning))
                containerBadge(count: stats.stoppedContainers, color: "#9E9E9E", label: localization.localized(.dockerStopped))
                Spacer()
            }

            // Resource usage
            HStack {
                Text("CPU")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.1f%%", stats.totalCPU))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: stats.totalCPU < 50 ? "#4CAF50" : stats.totalCPU < 80 ? "#FF9800" : "#F44336"))
            }

            HStack {
                Text(localization.localized(.dockerMemory))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(formatMemory(stats.totalMemory))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Container list
            Divider().background(Color.white.opacity(0.1))
            ForEach(appState.dockerManager.containers.prefix(3)) { container in
                containerRow(container)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func containerBadge(count: Int, color: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func containerRow(_ container: DockerContainer) -> some View {
        HStack(spacing: 4) {
            Image(systemName: container.status.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: container.status.hexColor))
            Text(container.name)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            if container.status == .running {
                Text(String(format: "%.0f%%", container.cpuUsage))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
