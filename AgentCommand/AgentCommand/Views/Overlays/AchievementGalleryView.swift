import SwiftUI

/// Achievement gallery / trophy room view showing all achievements and their unlock status
struct AchievementGalleryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Achievement Gallery")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()

                // Progress summary
                let unlocked = appState.achievementManager.unlockedAchievements.count
                let total = AchievementId.allCases.count
                Text("\(unlocked)/\(total)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.yellow)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.05))

            Divider().background(Color.white.opacity(0.1))

            // Progress bar
            let progress = Double(appState.achievementManager.unlockedAchievements.count) / Double(AchievementId.allCases.count)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)

            // Achievement grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AchievementId.allCases, id: \.self) { achievement in
                        AchievementCard(
                            achievement: achievement,
                            unlocked: appState.achievementManager.unlockedAchievements[achievement]
                        )
                    }
                }
                .padding()
            }

            Divider().background(Color.white.opacity(0.1))

            // Agent Stats Summary
            agentStatsSummary
        }
        .frame(width: 420, height: 520)
        .background(Color(hex: "#0D1117"))
    }

    private var agentStatsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Stats")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            let allStats = appState.statsManager.stats
            if allStats.isEmpty {
                Text("No stats yet. Complete tasks to earn XP!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(allStats.keys.sorted()), id: \.self) { agentName in
                    if let stats = allStats[agentName] {
                        AgentStatsRow(agentName: agentName, stats: stats)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: AchievementId
    let unlocked: UnlockedAchievement?

    var isUnlocked: Bool { unlocked != nil }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: achievement.icon)
                .foregroundColor(isUnlocked ? .white : .white.opacity(0.3))
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isUnlocked
                                ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))

                Text(achievement.description)
                    .font(.system(size: 10))
                    .foregroundColor(isUnlocked ? .white.opacity(0.6) : .white.opacity(0.25))
                    .lineLimit(2)

                if let unlocked = unlocked {
                    Text(unlocked.unlockedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isUnlocked ? Color.yellow.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isUnlocked ? Color.yellow.opacity(0.3) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - Agent Stats Row

struct AgentStatsRow: View {
    let agentName: String
    let stats: AgentStats

    var body: some View {
        HStack(spacing: 8) {
            // Level badge
            Text("Lv.\(stats.level)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(levelColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelColor.opacity(0.15))
                )

            Text(agentName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // XP progress bar
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.totalXP) XP")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(levelColor)
                            .frame(width: geo.size.width * stats.xpProgress)
                    }
                }
                .frame(width: 60, height: 3)
            }

            // Tasks count
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                Text("\(stats.totalTasksCompleted)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Next unlock hint
            if let next = Accessory.nextUnlock(forLevel: stats.level) {
                HStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                    Text("Lv.\(next.unlockLevel)")
                        .font(.system(size: 9))
                }
                .foregroundColor(.orange.opacity(0.6))
            }
        }
    }

    private var levelColor: Color {
        switch stats.level {
        case 1: return .gray
        case 2...4: return .green
        case 5...9: return .blue
        default: return .yellow
        }
    }
}
