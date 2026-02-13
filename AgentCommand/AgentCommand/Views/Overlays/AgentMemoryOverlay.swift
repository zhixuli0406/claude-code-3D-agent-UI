import SwiftUI

// MARK: - H2: Agent Memory Status Overlay (shown in 3D scene)

struct AgentMemoryOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private var stats: MemoryStats {
        appState.agentMemoryManager.memoryStats
    }

    private var recentMemories: [AgentMemory] {
        Array(appState.agentMemoryManager.memories.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(localization.localized(.agentMemory))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(stats.totalMemories)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }

            Divider()
                .background(Color.white.opacity(0.15))

            // Stats row
            HStack(spacing: 12) {
                miniStat(icon: "person.2", value: "\(stats.totalAgents)", label: localization.localized(.memoryAgents))
                miniStat(icon: "internaldrive", value: stats.formattedSize, label: localization.localized(.memorySize))
            }

            // Category breakdown
            if !stats.categoryCounts.isEmpty {
                HStack(spacing: 4) {
                    ForEach(MemoryCategory.allCases, id: \.self) { cat in
                        let count = stats.categoryCounts[cat.rawValue] ?? 0
                        if count > 0 {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color(hex: cat.colorHex))
                                    .frame(width: 6, height: 6)
                                Text("\(count)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                }
            }

            // Recent memories
            if !recentMemories.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.15))

                Text(localization.localized(.memoryRecent))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                ForEach(recentMemories) { memory in
                    HStack(spacing: 6) {
                        Image(systemName: memory.category.iconName)
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: memory.category.colorHex))
                        Text(memory.taskTitle)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0D1117")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#00BCD4").opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#00BCD4").opacity(0.7))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
