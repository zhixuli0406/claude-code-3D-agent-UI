import Foundation

// MARK: - H2: AI Agent Memory System Models

/// Represents a single memory entry for an agent
struct AgentMemory: Identifiable, Codable, Hashable {
    let id: String
    var agentName: String
    var taskTitle: String
    var summary: String
    var category: MemoryCategory
    var relevanceScore: Float
    var createdAt: Date
    var lastAccessedAt: Date
    var accessCount: Int
    var relatedFilesPaths: [String]
    var tags: [String]

    init(agentName: String, taskTitle: String, summary: String, category: MemoryCategory, relevanceScore: Float = 1.0, relatedFilesPaths: [String] = [], tags: [String] = []) {
        self.id = UUID().uuidString
        self.agentName = agentName
        self.taskTitle = taskTitle
        self.summary = summary
        self.category = category
        self.relevanceScore = relevanceScore
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.accessCount = 0
        self.relatedFilesPaths = relatedFilesPaths
        self.tags = tags
    }

    /// Time-decayed relevance score (decreases over time)
    var decayedScore: Float {
        let daysSinceCreation = Float(Date().timeIntervalSince(createdAt) / 86400)
        let decayFactor = exp(-0.05 * daysSinceCreation)
        let recencyBoost = Float(Date().timeIntervalSince(lastAccessedAt) < 3600 ? 0.2 : 0)
        let frequencyBoost = min(Float(accessCount) * 0.05, 0.3)
        return relevanceScore * decayFactor + recencyBoost + frequencyBoost
    }
}

/// Category of memory
enum MemoryCategory: String, Codable, CaseIterable {
    case taskSummary
    case codeKnowledge
    case errorPattern
    case userPreference
    case projectContext

    var displayName: String {
        switch self {
        case .taskSummary: return "Task Summary"
        case .codeKnowledge: return "Code Knowledge"
        case .errorPattern: return "Error Pattern"
        case .userPreference: return "User Preference"
        case .projectContext: return "Project Context"
        }
    }

    var iconName: String {
        switch self {
        case .taskSummary: return "doc.text"
        case .codeKnowledge: return "chevron.left.forwardslash.chevron.right"
        case .errorPattern: return "exclamationmark.triangle"
        case .userPreference: return "person.crop.circle"
        case .projectContext: return "folder"
        }
    }

    var colorHex: String {
        switch self {
        case .taskSummary: return "#4CAF50"
        case .codeKnowledge: return "#2196F3"
        case .errorPattern: return "#FF5722"
        case .userPreference: return "#9C27B0"
        case .projectContext: return "#FF9800"
        }
    }
}

/// Statistics for the memory system
struct MemoryStats: Codable {
    var totalMemories: Int
    var totalAgents: Int
    var oldestMemoryDate: Date?
    var newestMemoryDate: Date?
    var databaseSizeBytes: Int64
    var categoryCounts: [String: Int]

    static let empty = MemoryStats(
        totalMemories: 0,
        totalAgents: 0,
        databaseSizeBytes: 0,
        categoryCounts: [:]
    )

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: databaseSizeBytes)
    }
}

/// Shared memory between agents
struct SharedMemory: Identifiable, Codable {
    let id: String
    var sourceAgentName: String
    var targetAgentName: String
    var memoryId: String
    var sharedAt: Date

    init(sourceAgentName: String, targetAgentName: String, memoryId: String) {
        self.id = UUID().uuidString
        self.sourceAgentName = sourceAgentName
        self.targetAgentName = targetAgentName
        self.memoryId = memoryId
        self.sharedAt = Date()
    }
}
