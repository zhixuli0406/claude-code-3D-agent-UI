import SwiftUI

// MARK: - L2: Smart Scheduling Status Overlay (right-side floating panel)

struct SmartSchedulingOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#00BFA5").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#00BFA5").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00BFA5"))
            Text(localization.localized(.ssSmartScheduling))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.smartSchedulingManager.isAutoScheduling {
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
            let stats = appState.smartSchedulingManager.stats

            HStack {
                Text(localization.localized(.ssScheduledTasks))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalScheduled)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BFA5"))
            }

            HStack {
                Text(localization.localized(.ssCompletedOnTime))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.completedOnTime)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.ssResourceUtil))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(stats.resourceUtilization * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.resourceUtilization > 0.8 ? "#FF9800" : "#4CAF50"))
            }

            // Upcoming tasks
            ForEach(appState.smartSchedulingManager.scheduledTasks.filter { $0.status == .scheduled }.prefix(3)) { task in
                taskRow(task)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func taskRow(_ task: ScheduledTask) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: task.priority.hexColor))
                .frame(width: 6, height: 6)
            Text(task.name)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            if let suggested = task.suggestedTime {
                Text(suggested, style: .time)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
