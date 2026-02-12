import Foundation

// MARK: - Personality Trait

/// Core personality traits that affect agent animations and behavior
enum PersonalityTrait: String, Codable, CaseIterable {
    case energetic    // Moves quickly, fidgets often
    case calm         // Smooth movements, minimal fidgeting
    case curious      // Looks around frequently, examines things
    case focused      // Rarely distracted, steady work rhythm
    case social       // Waves at others, visits frequently
    case shy          // Avoids others, minimal emotes

    var displayName: String {
        switch self {
        case .energetic: return "Energetic"
        case .calm: return "Calm"
        case .curious: return "Curious"
        case .focused: return "Focused"
        case .social: return "Social"
        case .shy: return "Shy"
        }
    }

    var emoji: String {
        switch self {
        case .energetic: return "⚡"
        case .calm: return "🧘"
        case .curious: return "🔍"
        case .focused: return "🎯"
        case .social: return "🤗"
        case .shy: return "🫣"
        }
    }

    @MainActor func localizedName(_ l: LocalizationManager) -> String {
        switch self {
        case .energetic: return l.localized(.personalityEnergetic)
        case .calm: return l.localized(.personalityCalm)
        case .curious: return l.localized(.personalityCurious)
        case .focused: return l.localized(.personalityFocused)
        case .social: return l.localized(.personalitySocial)
        case .shy: return l.localized(.personalityShy)
        }
    }
}

// MARK: - Agent Mood

/// Mood is influenced by task outcomes and affects idle animations
enum AgentMood: String, Codable, CaseIterable {
    case happy        // Recent successes
    case neutral      // Default state
    case stressed     // Recent failures or long tasks
    case excited      // Streak active or level up
    case tired        // Working for a long time

    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .neutral: return "Neutral"
        case .stressed: return "Stressed"
        case .excited: return "Excited"
        case .tired: return "Tired"
        }
    }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .neutral: return "😐"
        case .stressed: return "😰"
        case .excited: return "🤩"
        case .tired: return "😴"
        }
    }

    var hexColor: String {
        switch self {
        case .happy: return "#4CAF50"
        case .neutral: return "#9E9E9E"
        case .stressed: return "#FF5722"
        case .excited: return "#FFD700"
        case .tired: return "#607D8B"
        }
    }

    @MainActor func localizedName(_ l: LocalizationManager) -> String {
        switch self {
        case .happy: return l.localized(.moodHappy)
        case .neutral: return l.localized(.moodNeutral)
        case .stressed: return l.localized(.moodStressed)
        case .excited: return l.localized(.moodExcited)
        case .tired: return l.localized(.moodTired)
        }
    }
}

// MARK: - Idle Behavior

/// Random idle behaviors triggered when agent is idle
enum IdleBehavior: String, Codable, CaseIterable {
    case stretching       // Arms up stretch
    case lookingAround    // Head turns left and right
    case coffeeBreak      // Sips from invisible cup
    case tapping          // Taps foot impatiently
    case waving           // Waves at nearby agents
    case yawning          // Head tilts back
}

// MARK: - Agent Relationship

/// Tracks collaboration frequency between two agents
struct AgentRelationship: Codable, Identifiable {
    var id: String { "\(agentNameA)-\(agentNameB)" }
    let agentNameA: String
    let agentNameB: String
    var collaborationCount: Int
    var lastCollaboration: Date

    /// Relationship level based on collaboration count
    var level: RelationshipLevel {
        switch collaborationCount {
        case 0: return .stranger
        case 1...3: return .acquaintance
        case 4...9: return .colleague
        default: return .partner
        }
    }
}

enum RelationshipLevel: String, Codable {
    case stranger       // Never worked together
    case acquaintance   // 1-3 collaborations
    case colleague      // 4-9 collaborations
    case partner        // 10+ collaborations

    var emoji: String {
        switch self {
        case .stranger: return "👤"
        case .acquaintance: return "🤝"
        case .colleague: return "👥"
        case .partner: return "💫"
        }
    }
}

// MARK: - Agent Personality

/// Complete personality profile for an agent
struct AgentPersonality: Codable, Hashable {
    var trait: PersonalityTrait
    var mood: AgentMood
    /// Seconds since last idle behavior was triggered
    var lastIdleBehaviorTime: Date?

    init(trait: PersonalityTrait, mood: AgentMood = .neutral) {
        self.trait = trait
        self.mood = mood
        self.lastIdleBehaviorTime = nil
    }

    /// How frequently this personality triggers idle behaviors (in seconds)
    var idleBehaviorInterval: TimeInterval {
        switch trait {
        case .energetic: return 8
        case .calm: return 20
        case .curious: return 10
        case .focused: return 25
        case .social: return 12
        case .shy: return 22
        }
    }

    /// Which idle behaviors this personality prefers
    var preferredBehaviors: [IdleBehavior] {
        switch trait {
        case .energetic: return [.stretching, .tapping, .waving]
        case .calm: return [.stretching, .coffeeBreak]
        case .curious: return [.lookingAround, .tapping, .waving]
        case .focused: return [.coffeeBreak, .stretching]
        case .social: return [.waving, .lookingAround, .coffeeBreak]
        case .shy: return [.coffeeBreak, .yawning, .stretching]
        }
    }

    /// Pick a random idle behavior weighted by personality
    func randomIdleBehavior() -> IdleBehavior {
        // Mood can override some behaviors
        if mood == .tired {
            return [.yawning, .stretching, .coffeeBreak].randomElement()!
        }
        if mood == .excited {
            return [.waving, .tapping, .stretching].randomElement()!
        }
        return preferredBehaviors.randomElement() ?? .stretching
    }

    // MARK: - Hashable

    static func == (lhs: AgentPersonality, rhs: AgentPersonality) -> Bool {
        lhs.trait == rhs.trait && lhs.mood == rhs.mood
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(trait)
        hasher.combine(mood)
    }
}

// MARK: - Relationship Manager

/// Manages relationships between agents, persisted locally
class AgentRelationshipManager {
    private static let storageKey = "agentRelationships"

    private(set) var relationships: [AgentRelationship] = []

    init() {
        load()
    }

    /// Record a collaboration between two agents
    func recordCollaboration(agentA: String, agentB: String) {
        let keyA = min(agentA, agentB)
        let keyB = max(agentA, agentB)

        if let idx = relationships.firstIndex(where: { $0.agentNameA == keyA && $0.agentNameB == keyB }) {
            relationships[idx].collaborationCount += 1
            relationships[idx] = AgentRelationship(
                agentNameA: keyA,
                agentNameB: keyB,
                collaborationCount: relationships[idx].collaborationCount,
                lastCollaboration: Date()
            )
        } else {
            relationships.append(AgentRelationship(
                agentNameA: keyA,
                agentNameB: keyB,
                collaborationCount: 1,
                lastCollaboration: Date()
            ))
        }
        save()
    }

    /// Get the relationship between two agents
    func relationship(between agentA: String, and agentB: String) -> AgentRelationship? {
        let keyA = min(agentA, agentB)
        let keyB = max(agentA, agentB)
        return relationships.first { $0.agentNameA == keyA && $0.agentNameB == keyB }
    }

    /// Get all relationships for a specific agent
    func relationships(for agentName: String) -> [AgentRelationship] {
        relationships.filter { $0.agentNameA == agentName || $0.agentNameB == agentName }
    }

    /// Get the top collaborators for an agent
    func topCollaborators(for agentName: String, limit: Int = 3) -> [AgentRelationship] {
        relationships(for: agentName)
            .sorted { $0.collaborationCount > $1.collaborationCount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(relationships) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let loaded = try? JSONDecoder().decode([AgentRelationship].self, from: data) else { return }
        relationships = loaded
    }
}
