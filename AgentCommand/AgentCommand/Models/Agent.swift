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
}

struct ScenePosition: Codable, Hashable {
    var x: Float
    var y: Float
    var z: Float
    var rotation: Float
}
