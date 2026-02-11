import Foundation

/// A single daily performance record for historical charts
struct DailyRecord: Codable {
    let date: String // "yyyy-MM-dd"
    var tasksCompleted: Int = 0
    var tasksFailed: Int = 0
    var totalDuration: TimeInterval = 0
    var xpEarned: Int = 0
}

/// Persistent stats and XP tracking for agents
struct AgentStats: Codable {
    var totalTasksCompleted: Int = 0
    var totalTasksFailed: Int = 0
    var totalXP: Int = 0
    var level: Int = 1
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var fastestTaskDuration: TimeInterval?
    var totalWorkTime: TimeInterval = 0

    // B3: Historical data
    var dailyRecords: [DailyRecord] = []
    var activeHours: [Int: Int] = [:] // hour (0-23) -> task count

    var successRate: Double {
        let total = totalTasksCompleted + totalTasksFailed
        guard total > 0 else { return 0 }
        return Double(totalTasksCompleted) / Double(total)
    }

    var averageTaskDuration: TimeInterval {
        guard totalTasksCompleted > 0 else { return 0 }
        return totalWorkTime / Double(totalTasksCompleted)
    }

    var xpForNextLevel: Int {
        level * 100 + 50
    }

    var xpProgress: Double {
        let xpInCurrentLevel = totalXP - xpForLevel(level)
        let xpNeeded = xpForNextLevel
        return min(1.0, max(0, Double(xpInCurrentLevel) / Double(xpNeeded)))
    }

    /// Productivity score combining success rate, speed, and volume
    var productivityScore: Double {
        let volumeScore = min(Double(totalTasksCompleted) / 10.0, 1.0)
        let speedScore = averageTaskDuration > 0 ? min(60.0 / averageTaskDuration, 1.0) : 0
        return (successRate * 0.4 + volumeScore * 0.3 + speedScore * 0.3) * 100
    }

    private func xpForLevel(_ lvl: Int) -> Int {
        guard lvl > 1 else { return 0 }
        var total = 0
        for l in 1..<lvl {
            total += l * 100 + 50
        }
        return total
    }

    /// Returns the new level if leveled up, nil otherwise
    mutating func addXP(_ amount: Int) -> Bool {
        totalXP += amount
        let newLevel = calculateLevel()
        if newLevel > level {
            level = newLevel
            return true // Leveled up
        }
        return false
    }

    /// Returns the accessory that was just unlocked at the current level, if any
    var newlyUnlockedAccessory: Accessory? {
        Accessory.allCases.first { $0.unlockLevel == level }
    }

    private func calculateLevel() -> Int {
        var lvl = 1
        var xpNeeded = 0
        while true {
            xpNeeded += lvl * 100 + 50
            if totalXP < xpNeeded { break }
            lvl += 1
        }
        return lvl
    }

    // MARK: - B3: Daily record helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    mutating func recordDailyCompletion(duration: TimeInterval, xp: Int) {
        let today = Self.dayFormatter.string(from: Date())
        if let idx = dailyRecords.firstIndex(where: { $0.date == today }) {
            dailyRecords[idx].tasksCompleted += 1
            dailyRecords[idx].totalDuration += duration
            dailyRecords[idx].xpEarned += xp
        } else {
            dailyRecords.append(DailyRecord(date: today, tasksCompleted: 1, totalDuration: duration, xpEarned: xp))
        }
        // Keep only the last 30 days
        if dailyRecords.count > 30 {
            dailyRecords.removeFirst(dailyRecords.count - 30)
        }
        let hour = Calendar.current.component(.hour, from: Date())
        activeHours[hour, default: 0] += 1
    }

    mutating func recordDailyFailure() {
        let today = Self.dayFormatter.string(from: Date())
        if let idx = dailyRecords.firstIndex(where: { $0.date == today }) {
            dailyRecords[idx].tasksFailed += 1
        } else {
            dailyRecords.append(DailyRecord(date: today, tasksFailed: 1))
        }
        let hour = Calendar.current.component(.hour, from: Date())
        activeHours[hour, default: 0] += 1
    }
}

/// Manages persistent agent stats stored in UserDefaults
@MainActor
class AgentStatsManager: ObservableObject {
    @Published var stats: [String: AgentStats] = [:] // keyed by agent name for persistence

    private let storageKey = "agentStats"

    init() {
        load()
    }

    func statsFor(agentName: String) -> AgentStats {
        stats[agentName] ?? AgentStats()
    }

    /// Record a task completion and return (xpGained, didLevelUp, unlockedAccessory)
    @discardableResult
    func recordCompletion(agentName: String, duration: TimeInterval) -> (xp: Int, leveledUp: Bool, unlockedAccessory: Accessory?) {
        var s = statsFor(agentName: agentName)
        s.totalTasksCompleted += 1
        s.currentStreak += 1
        s.bestStreak = max(s.bestStreak, s.currentStreak)
        s.totalWorkTime += duration

        if let fastest = s.fastestTaskDuration {
            s.fastestTaskDuration = min(fastest, duration)
        } else {
            s.fastestTaskDuration = duration
        }

        // Calculate XP: base 50 + streak bonus + speed bonus
        var xp = 50
        xp += min(s.currentStreak * 10, 100) // Streak bonus capped at 100
        if duration < 30 { xp += 30 } // Speed bonus
        else if duration < 60 { xp += 15 }

        let leveledUp = s.addXP(xp)
        let unlockedAccessory = leveledUp ? s.newlyUnlockedAccessory : nil
        s.recordDailyCompletion(duration: duration, xp: xp)
        stats[agentName] = s
        save()
        return (xp, leveledUp, unlockedAccessory)
    }

    /// Record a task failure and return the streak that was lost (0 if no streak was active)
    @discardableResult
    func recordFailure(agentName: String) -> Int {
        var s = statsFor(agentName: agentName)
        let lostStreak = s.currentStreak
        s.totalTasksFailed += 1
        s.currentStreak = 0
        s.recordDailyFailure()
        stats[agentName] = s
        save()
        return lostStreak
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: AgentStats].self, from: data) {
            stats = decoded
        }
    }
}
