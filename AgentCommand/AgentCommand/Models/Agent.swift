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
