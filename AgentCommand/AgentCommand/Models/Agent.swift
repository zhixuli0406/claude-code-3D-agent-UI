import Foundation

struct Agent: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: AgentRole
    var status: AgentStatus
    var selectedModel: ClaudeModel
    var personality: AgentPersonality
    var appearance: VoxelAppearance
    var position: ScenePosition
    var parentAgentId: UUID?
    var subAgentIds: [UUID]
    var assignedTaskIds: [UUID]

    var isMainAgent: Bool { parentAgentId == nil }

    enum CodingKeys: String, CodingKey {
        case id, name, role, status, selectedModel, personality, appearance
        case position, parentAgentId, subAgentIds, assignedTaskIds
    }

    init(id: UUID, name: String, role: AgentRole, status: AgentStatus,
         selectedModel: ClaudeModel = .sonnet,
         personality: AgentPersonality = AgentPersonality(trait: .calm),
         appearance: VoxelAppearance,
         position: ScenePosition, parentAgentId: UUID?,
         subAgentIds: [UUID], assignedTaskIds: [UUID]) {
        self.id = id
        self.name = name
        self.role = role
        self.status = status
        self.selectedModel = selectedModel
        self.personality = personality
        self.appearance = appearance
        self.position = position
        self.parentAgentId = parentAgentId
        self.subAgentIds = subAgentIds
        self.assignedTaskIds = assignedTaskIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(AgentRole.self, forKey: .role)
        status = try container.decode(AgentStatus.self, forKey: .status)
        selectedModel = try container.decodeIfPresent(ClaudeModel.self, forKey: .selectedModel) ?? .sonnet
        personality = try container.decodeIfPresent(AgentPersonality.self, forKey: .personality) ?? AgentPersonality(trait: .calm)
        appearance = try container.decode(VoxelAppearance.self, forKey: .appearance)
        position = try container.decode(ScenePosition.self, forKey: .position)
        parentAgentId = try container.decodeIfPresent(UUID.self, forKey: .parentAgentId)
        subAgentIds = try container.decode([UUID].self, forKey: .subAgentIds)
        assignedTaskIds = try container.decode([UUID].self, forKey: .assignedTaskIds)
    }
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
