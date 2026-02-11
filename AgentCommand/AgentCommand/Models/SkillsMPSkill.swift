import Foundation

// MARK: - SkillsMP API Response Models

/// Top-level API response wrapper supporting multiple formats:
/// - Wrapped: { "success": true, "data": { "skills": [...], "total": ... } }
/// - Flat: { "skills": [...], "total": ... }
/// - Results key: { "results": [...], "total": ... }
struct SkillsMPAPIResponse: Decodable {
    let success: Bool?
    let data: SkillsMPSearchResponse?

    // Fallback fields for direct (unwrapped) responses
    let skills: [SkillsMPSkill]?
    let results: [SkillsMPSkill]?
    let total: Int?
    let count: Int?

    /// Returns skills from whichever key is present
    var resolvedSkills: [SkillsMPSkill]? {
        skills ?? results
    }

    var resolvedTotal: Int? {
        total ?? count
    }
}

/// Inner data payload from SkillsMP search API
struct SkillsMPSearchResponse: Decodable {
    let skills: [SkillsMPSkill]?
    let results: [SkillsMPSkill]?
    let total: Int?
    let count: Int?
    let page: Int?
    let limit: Int?

    /// Returns skills from whichever key is present
    var resolvedSkills: [SkillsMPSkill] {
        skills ?? results ?? []
    }

    var resolvedTotal: Int? {
        total ?? count
    }
}

/// Represents a single skill from the SkillsMP marketplace
struct SkillsMPSkill: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let author: String
    let description: String
    let githubUrl: String?
    let stars: Int
    let updatedAt: SkillTimestamp

    enum CodingKeys: String, CodingKey {
        case id, name, author, description
        case githubUrl = "github_url"
        case stars
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id can be String or Int from API
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }

        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        author = (try? container.decode(String.self, forKey: .author)) ?? "Unknown"
        description = (try? container.decode(String.self, forKey: .description)) ?? ""
        githubUrl = try? container.decode(String.self, forKey: .githubUrl)
        stars = (try? container.decode(Int.self, forKey: .stars)) ?? 0
        updatedAt = (try? container.decode(SkillTimestamp.self, forKey: .updatedAt)) ?? SkillTimestamp(date: Date())
    }

    /// Convert to local AgentSkill for storage
    func toAgentSkill() -> AgentSkill {
        let parsedDate = updatedAt.date

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

// MARK: - Flexible Timestamp Decoding

/// Handles both Unix timestamp (Int) and ISO8601 string formats
struct SkillTimestamp: Decodable, Hashable {
    let date: Date

    init(date: Date) {
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let timestamp = try? container.decode(Double.self) {
            date = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = try? container.decode(String.self) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: dateString) {
                date = parsed
            } else {
                iso.formatOptions = [.withInternetDateTime]
                date = iso.date(from: dateString) ?? Date()
            }
        } else {
            date = Date()
        }
    }
}
