import Foundation

// MARK: - SkillsMP API Response Models

/// Response wrapper from SkillsMP search API
struct SkillsMPSearchResponse: Decodable {
    let skills: [SkillsMPSkill]
    let total: Int?
    let page: Int?
    let limit: Int?
}

/// Represents a single skill from the SkillsMP marketplace
struct SkillsMPSkill: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let author: String
    let description: String
    let githubUrl: String?
    let stars: Int
    let updatedAt: String

    /// Convert to local AgentSkill for storage
    func toAgentSkill() -> AgentSkill {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsedDate = formatter.date(from: updatedAt)
            ?? ISO8601DateFormatter().date(from: updatedAt)
            ?? Date()

        var tags = ["skillsmp"]
        if let url = githubUrl, !url.isEmpty {
            tags.append("github")
        }

        return AgentSkill(
            id: "skillsmp_\(id)",
            name: name,
            description: description,
            category: .custom,
            icon: "puzzlepiece.extension.fill",
            version: "1.0.0",
            author: author,
            source: .community,
            instructionsPreview: nil,
            instructionsFull: nil,
            resources: [],
            createdAt: parsedDate,
            updatedAt: parsedDate,
            tags: tags,
            compatiblePlatforms: ["claude-code"]
        )
    }
}
