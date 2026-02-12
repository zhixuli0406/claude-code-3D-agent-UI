import Foundation

struct AgentFactory {

    private static let commanderNames = [
        "Commander Alpha", "Commander Bravo", "Commander Echo",
        "Commander Nova", "Commander Titan", "Commander Zenith",
        "Commander Vortex", "Commander Blaze", "Commander Frost",
        "Commander Storm", "Commander Apex", "Commander Cipher"
    ]

    private static let subAgentNames = [
        "Dev Bot", "Research Unit", "Code Crafter", "Data Scout",
        "Logic Engine", "Syntax Agent", "Debug Drone", "Build Bot",
        "Parse Unit", "Query Agent", "Refactor Bot", "Test Runner"
    ]

    private static let skinColors = ["#FFCC99", "#D2A679", "#F5D5C8", "#8D5524", "#C68642"]
    private static let shirtColors = ["#1A237E", "#1B5E20", "#4A148C", "#B71C1C", "#004D40", "#E65100", "#1565C0"]
    private static let pantsColors = ["#37474F", "#263238", "#1A237E", "#3E2723", "#212121"]
    private static let hairColors = ["#3E2723", "#212121", "#F5F5F5", "#795548", "#FF8A65"]

    private static let subAgentRoles: [AgentRole] = [.developer, .researcher, .reviewer, .tester, .designer]

    private static var teamCounter = 0

    /// Create a new team: 1 commander + `subAgentCount` sub-agents
    static func createTeam(subAgentCount: Int = 2, model: ClaudeModel = .sonnet) -> [Agent] {
        teamCounter += 1

        let commanderId = UUID()
        var subAgentIds: [UUID] = []
        var agents: [Agent] = []

        for _ in 0..<subAgentCount {
            subAgentIds.append(UUID())
        }

        // Commander
        let commanderName = commanderNames[(teamCounter - 1) % commanderNames.count]
        let commander = Agent(
            id: commanderId,
            name: "\(commanderName) #\(teamCounter)",
            role: .commander,
            status: .idle,
            selectedModel: model,
            personality: randomPersonality(for: .commander),
            appearance: randomAppearance(),
            position: ScenePosition(x: 0, y: 0, z: 0, rotation: 0),
            parentAgentId: nil,
            subAgentIds: subAgentIds,
            assignedTaskIds: []
        )
        agents.append(commander)

        // Sub-agents inherit the same model from their commander
        let shuffledRoles = subAgentRoles.shuffled()
        let shuffledNames = subAgentNames.shuffled()
        for (i, subId) in subAgentIds.enumerated() {
            let role = shuffledRoles[i % shuffledRoles.count]
            let name = shuffledNames[i % shuffledNames.count]
            let subAgent = Agent(
                id: subId,
                name: "\(name) #\(teamCounter)",
                role: role,
                status: .idle,
                selectedModel: model,
                personality: randomPersonality(for: role),
                appearance: randomAppearance(),
                position: ScenePosition(x: 0, y: 0, z: 0, rotation: 0),
                parentAgentId: commanderId,
                subAgentIds: [],
                assignedTaskIds: []
            )
            agents.append(subAgent)
        }

        return agents
    }

    /// Generate a personality with trait biased by role
    private static func randomPersonality(for role: AgentRole) -> AgentPersonality {
        let weightedTraits: [PersonalityTrait]
        switch role {
        case .commander:
            weightedTraits = [.focused, .focused, .calm, .social, .energetic]
        case .developer:
            weightedTraits = [.focused, .focused, .calm, .energetic, .curious]
        case .researcher:
            weightedTraits = [.curious, .curious, .calm, .focused, .shy]
        case .reviewer:
            weightedTraits = [.calm, .calm, .focused, .curious, .shy]
        case .tester:
            weightedTraits = [.energetic, .energetic, .curious, .focused, .social]
        case .designer:
            weightedTraits = [.curious, .curious, .social, .energetic, .calm]
        }
        let trait = weightedTraits.randomElement()!
        return AgentPersonality(trait: trait)
    }

    private static func randomAppearance() -> VoxelAppearance {
        VoxelAppearance(
            skinColor: skinColors.randomElement()!,
            shirtColor: shirtColors.randomElement()!,
            pantsColor: pantsColors.randomElement()!,
            hairColor: hairColors.randomElement()!,
            hairStyle: HairStyle.allCases.randomElement()!,
            accessory: Bool.random() ? Accessory.allCases.randomElement() : nil
        )
    }
}
