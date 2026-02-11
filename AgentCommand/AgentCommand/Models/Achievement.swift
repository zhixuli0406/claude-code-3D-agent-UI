import Foundation

enum AchievementId: String, Codable, CaseIterable {
    case firstBlood        // Complete first task
    case speedDemon        // Complete a task under 30 seconds
    case teamPlayer        // Complete a 4+ agent team task
    case bugSlayer         // Fix 10 bugs (complete 10 tasks)
    case nightOwl          // Complete a task after midnight
    case flawless          // Complete 5 tasks in a row without errors
    case architect         // Review and approve 10 plans
    case explorer          // Use all 4 themes
    case secretFinder      // Discover first hidden item
    case cartographer      // Reveal entire map in any theme

    var title: String {
        switch self {
        case .firstBlood: return "First Blood"
        case .speedDemon: return "Speed Demon"
        case .teamPlayer: return "Team Player"
        case .bugSlayer: return "Bug Slayer"
        case .nightOwl: return "Night Owl"
        case .flawless: return "Flawless"
        case .architect: return "Architect"
        case .explorer: return "Explorer"
        case .secretFinder: return "Secret Finder"
        case .cartographer: return "Cartographer"
        }
    }

    var description: String {
        switch self {
        case .firstBlood: return "Complete your first task"
        case .speedDemon: return "Complete a task in under 30 seconds"
        case .teamPlayer: return "Complete a task with 4+ agents"
        case .bugSlayer: return "Complete 10 tasks"
        case .nightOwl: return "Complete a task after midnight"
        case .flawless: return "Complete 5 tasks in a row without errors"
        case .architect: return "Review and approve 10 plans"
        case .explorer: return "Use all 4 themes"
        case .secretFinder: return "Discover your first hidden item"
        case .cartographer: return "Reveal the entire map in any theme"
        }
    }

    var icon: String {
        switch self {
        case .firstBlood: return "drop.fill"
        case .speedDemon: return "bolt.fill"
        case .teamPlayer: return "person.3.fill"
        case .bugSlayer: return "ant.fill"
        case .nightOwl: return "moon.fill"
        case .flawless: return "star.fill"
        case .architect: return "building.columns.fill"
        case .explorer: return "globe"
        case .secretFinder: return "eye.fill"
        case .cartographer: return "map.fill"
        }
    }
}

struct UnlockedAchievement: Codable {
    let id: AchievementId
    let unlockedAt: Date
}

/// Manages achievement tracking and persistence
@MainActor
class AchievementManager: ObservableObject {
    @Published var unlockedAchievements: [AchievementId: UnlockedAchievement] = [:]
    @Published var pendingPopup: AchievementId?

    private var totalCompletions: Int = 0
    private var consecutiveSuccesses: Int = 0
    private var planApprovals: Int = 0
    private var usedThemes: Set<String> = []

    private let storageKey = "achievements"
    private let metaKey = "achievementMeta"

    init() {
        load()
    }

    func isUnlocked(_ id: AchievementId) -> Bool {
        unlockedAchievements[id] != nil
    }

    // MARK: - Event Tracking

    func onTaskCompleted(teamSize: Int, duration: TimeInterval) {
        totalCompletions += 1
        consecutiveSuccesses += 1

        // First Blood
        if totalCompletions == 1 { unlock(.firstBlood) }

        // Speed Demon
        if duration < 30 { unlock(.speedDemon) }

        // Team Player
        if teamSize >= 4 { unlock(.teamPlayer) }

        // Bug Slayer
        if totalCompletions >= 10 { unlock(.bugSlayer) }

        // Night Owl
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 5 { unlock(.nightOwl) }

        // Flawless
        if consecutiveSuccesses >= 5 { unlock(.flawless) }

        saveMeta()
    }

    func onTaskFailed() {
        consecutiveSuccesses = 0
        saveMeta()
    }

    func onPlanApproved() {
        planApprovals += 1
        if planApprovals >= 10 { unlock(.architect) }
        saveMeta()
    }

    func onThemeUsed(_ theme: String) {
        usedThemes.insert(theme)
        if usedThemes.count >= 4 { unlock(.explorer) }
        saveMeta()
    }

    func onItemDiscovered(totalDiscovered: Int, fogPercentage: Double) {
        // Secret Finder: first discovery
        if totalDiscovered >= 1 { unlock(.secretFinder) }
        // Cartographer: 100% fog revealed
        if fogPercentage >= 1.0 { unlock(.cartographer) }
    }

    func dismissPopup() {
        pendingPopup = nil
    }

    // MARK: - Private

    private func unlock(_ id: AchievementId) {
        guard !isUnlocked(id) else { return }
        unlockedAchievements[id] = UnlockedAchievement(id: id, unlockedAt: Date())
        pendingPopup = id
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(unlockedAchievements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AchievementId: UnlockedAchievement].self, from: data) {
            unlockedAchievements = decoded
        }
        loadMeta()
    }

    private func saveMeta() {
        let meta: [String: Any] = [
            "totalCompletions": totalCompletions,
            "consecutiveSuccesses": consecutiveSuccesses,
            "planApprovals": planApprovals,
            "usedThemes": Array(usedThemes)
        ]
        UserDefaults.standard.set(meta, forKey: metaKey)
    }

    private func loadMeta() {
        if let meta = UserDefaults.standard.dictionary(forKey: metaKey) {
            totalCompletions = meta["totalCompletions"] as? Int ?? 0
            consecutiveSuccesses = meta["consecutiveSuccesses"] as? Int ?? 0
            planApprovals = meta["planApprovals"] as? Int ?? 0
            if let themes = meta["usedThemes"] as? [String] {
                usedThemes = Set(themes)
            }
        }
    }
}
