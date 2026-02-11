import Foundation

struct Agent: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: AgentRole
    var status: AgentStatus
    var appearance: VoxelAppearance
    var position: ScenePosition
    var parentAgentId: UUID?
    var subAgentIds: [UUID]
    var assignedTaskIds: [UUID]

    var isMainAgent: Bool { parentAgentId == nil }
}

enum AgentRole: String, Codable, CaseIterable {
    case commander
    case developer
    case researcher
    case reviewer
    case tester
    case designer

    var displayName: String {
        switch self {
        case .commander: return "Commander"
        case .developer: return "Developer"
        case .researcher: return "Researcher"
        case .reviewer: return "Reviewer"
        case .tester: return "Tester"
        case .designer: return "Designer"
        }
    }

    @MainActor func localizedName(_ l: LocalizationManager) -> String {
        switch self {
        case .commander: return l.localized(.roleCommander)
        case .developer: return l.localized(.roleDeveloper)
        case .researcher: return l.localized(.roleResearcher)
        case .reviewer: return l.localized(.roleReviewer)
        case .tester: return l.localized(.roleTester)
        case .designer: return l.localized(.roleDesigner)
        }
    }

    var emoji: String {
        switch self {
        case .commander: return "⭐"
        case .developer: return "💻"
        case .researcher: return "🔬"
        case .reviewer: return "📋"
        case .tester: return "🧪"
        case .designer: return "🎨"
        }
    }
}

struct VoxelAppearance: Codable, Hashable {
    var skinColor: String
    var shirtColor: String
    var pantsColor: String
    var hairColor: String
    var hairStyle: HairStyle
    var accessory: Accessory?
}

enum HairStyle: String, Codable, CaseIterable {
    case short
    case medium
    case long
    case mohawk
    case bald
}

enum Accessory: String, Codable, CaseIterable {
    case glasses
    case headphones
    case hat
    case crown       // Unlocked at level 5
    case cape        // Unlocked at level 3
    case aura        // Unlocked at level 10

    /// Minimum agent level required to unlock this accessory
    var unlockLevel: Int {
        switch self {
        case .glasses, .headphones, .hat: return 1
        case .cape: return 3
        case .crown: return 5
        case .aura: return 10
        }
    }

    /// Accessories unlocked at or above the given level
    static func unlockedAccessories(forLevel level: Int) -> [Accessory] {
        allCases.filter { $0.unlockLevel <= level }
    }

    /// The next accessory that will be unlocked after the given level
    static func nextUnlock(forLevel level: Int) -> Accessory? {
        allCases
            .filter { $0.unlockLevel > level }
            .min(by: { $0.unlockLevel < $1.unlockLevel })
    }
}

struct ScenePosition: Codable, Hashable {
    var x: Float
    var y: Float
    var z: Float
    var rotation: Float
}
