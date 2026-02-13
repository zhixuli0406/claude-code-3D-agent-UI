import Foundation

// MARK: - Prompt Quality Score

/// Quality score for a prompt with detailed breakdown
struct PromptQualityScore: Identifiable, Codable {
    let id: String
    var overallScore: Double // 0.0 - 1.0
    var clarity: Double
    var specificity: Double
    var context: Double
    var actionability: Double
    var tokenEfficiency: Double
    var estimatedTokens: Int
    var estimatedCostUSD: Double
    var analyzedAt: Date

    var overallPercentage: Int { Int(overallScore * 100) }
    var clarityPercentage: Int { Int(clarity * 100) }
    var specificityPercentage: Int { Int(specificity * 100) }
    var contextPercentage: Int { Int(context * 100) }
    var actionabilityPercentage: Int { Int(actionability * 100) }
    var tokenEfficiencyPercentage: Int { Int(tokenEfficiency * 100) }

    var gradeLabel: String {
        switch overallScore {
        case 0.9...1.0: return "A+"
        case 0.8..<0.9: return "A"
        case 0.7..<0.8: return "B"
        case 0.6..<0.7: return "C"
        case 0.5..<0.6: return "D"
        default: return "F"
        }
    }

    var gradeColorHex: String {
        switch overallScore {
        case 0.8...1.0: return "#4CAF50"
        case 0.6..<0.8: return "#FF9800"
        default: return "#F44336"
        }
    }
}

// MARK: - Prompt Suggestion

/// A suggestion for improving a prompt
struct PromptSuggestion: Identifiable, Codable {
    let id: String
    var type: SuggestionType
    var title: String
    var description: String
    var originalSnippet: String
    var suggestedSnippet: String
    var impact: SuggestionImpact

    enum SuggestionType: String, Codable, CaseIterable {
        case addContext
        case beMoreSpecific
        case simplify
        case addConstraints
        case improveStructure
        case reduceAmbiguity

        var icon: String {
            switch self {
            case .addContext: return "text.badge.plus"
            case .beMoreSpecific: return "target"
            case .simplify: return "scissors"
            case .addConstraints: return "checklist"
            case .improveStructure: return "list.bullet.indent"
            case .reduceAmbiguity: return "questionmark.circle"
            }
        }

        var displayName: String {
            switch self {
            case .addContext: return "Add Context"
            case .beMoreSpecific: return "Be More Specific"
            case .simplify: return "Simplify"
            case .addConstraints: return "Add Constraints"
            case .improveStructure: return "Improve Structure"
            case .reduceAmbiguity: return "Reduce Ambiguity"
            }
        }
    }

    enum SuggestionImpact: String, Codable {
        case high, medium, low

        var colorHex: String {
            switch self {
            case .high: return "#F44336"
            case .medium: return "#FF9800"
            case .low: return "#4CAF50"
            }
        }
    }
}

// MARK: - Prompt Autocomplete

/// An autocomplete suggestion for the prompt input
struct PromptAutocompleteSuggestion: Identifiable, Codable {
    let id: String
    var text: String
    var category: String
    var relevanceScore: Double
    var source: AutocompleteSource

    enum AutocompleteSource: String, Codable {
        case projectContext
        case history
        case template
    }
}

// MARK: - Prompt History Record

/// A record of a prompt that was sent, with result tracking
struct PromptHistoryRecord: Identifiable, Codable {
    let id: String
    var prompt: String
    var qualityScore: PromptQualityScore?
    var sentAt: Date
    var completedAt: Date?
    var wasSuccessful: Bool?
    var taskDuration: TimeInterval?
    var tokenCount: Int?
    var costUSD: Double?
    var tags: [String]
    var patternId: String? // links to a PromptPattern

    var isCompleted: Bool { completedAt != nil }
}

// MARK: - Prompt Pattern

/// A pattern detected from prompt history analysis
struct PromptPattern: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var matchCount: Int
    var avgSuccessRate: Double
    var avgDuration: TimeInterval
    var avgTokens: Int
    var examplePrompts: [String]
    var detectedAt: Date

    var successPercentage: Int { Int(avgSuccessRate * 100) }

    var effectivenessLabel: String {
        switch avgSuccessRate {
        case 0.8...1.0: return "Highly Effective"
        case 0.6..<0.8: return "Effective"
        case 0.4..<0.6: return "Mixed Results"
        default: return "Low Effectiveness"
        }
    }

    var effectivenessColorHex: String {
        switch avgSuccessRate {
        case 0.8...1.0: return "#4CAF50"
        case 0.6..<0.8: return "#FF9800"
        default: return "#F44336"
        }
    }
}

// MARK: - Prompt A/B Test

/// An A/B test comparing two prompt variants
struct PromptABTest: Identifiable, Codable {
    let id: String
    var taskDescription: String
    var variantA: PromptVariant
    var variantB: PromptVariant
    var status: ABTestStatus
    var createdAt: Date
    var completedAt: Date?
    var winnerVariant: String? // "A" or "B"

    enum ABTestStatus: String, Codable {
        case pending, running, completed

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .running: return "Running"
            case .completed: return "Completed"
            }
        }
    }
}

/// A variant in an A/B test
struct PromptVariant: Identifiable, Codable {
    let id: String
    var label: String // "A" or "B"
    var prompt: String
    var result: String?
    var wasSuccessful: Bool?
    var duration: TimeInterval?
    var tokenCount: Int?
    var costUSD: Double?
    var qualityScore: Double?
}

// MARK: - Prompt Version

/// A versioned snapshot of a prompt
struct PromptVersion: Identifiable, Codable {
    let id: String
    var promptId: String
    var version: Int
    var content: String
    var qualityScore: Double?
    var wasSuccessful: Bool?
    var note: String?
    var createdAt: Date

    var versionLabel: String { "v\(version)" }
}

// MARK: - Prompt Anti-Pattern

/// An anti-pattern detected in a prompt
struct PromptAntiPattern: Identifiable, Codable {
    let id: String
    var category: AntiPatternCategory
    var title: String
    var description: String
    var matchedText: String
    var severity: AntiPatternSeverity
    var fixSuggestion: String

    enum AntiPatternCategory: String, Codable, CaseIterable {
        case vagueness
        case overloading
        case missingConstraints
        case negativeFraming
        case implicitAssumption
        case redundancy
        case scopeCreep

        var icon: String {
            switch self {
            case .vagueness: return "eye.slash"
            case .overloading: return "exclamationmark.triangle"
            case .missingConstraints: return "rectangle.dashed"
            case .negativeFraming: return "minus.circle"
            case .implicitAssumption: return "questionmark.diamond"
            case .redundancy: return "doc.on.doc.fill"
            case .scopeCreep: return "arrow.up.left.and.arrow.down.right"
            }
        }

        var displayName: String {
            switch self {
            case .vagueness: return "Vagueness"
            case .overloading: return "Overloading"
            case .missingConstraints: return "Missing Constraints"
            case .negativeFraming: return "Negative Framing"
            case .implicitAssumption: return "Implicit Assumption"
            case .redundancy: return "Redundancy"
            case .scopeCreep: return "Scope Creep"
            }
        }
    }

    enum AntiPatternSeverity: String, Codable, Comparable {
        case critical, warning, info

        var colorHex: String {
            switch self {
            case .critical: return "#F44336"
            case .warning: return "#FF9800"
            case .info: return "#03A9F4"
            }
        }

        private var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .warning: return 1
            case .info: return 2
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}

// MARK: - Prompt Rewrite Suggestion

/// An automated rewrite suggestion for an entire prompt
struct PromptRewriteSuggestion: Identifiable, Codable {
    let id: String
    var originalPrompt: String
    var rewrittenPrompt: String
    var improvementSummary: String
    var estimatedScoreImprovement: Double // 0.0 - 1.0 delta
    var appliedRules: [String]
    var createdAt: Date
}

// MARK: - Prompt Analysis Report

/// A comprehensive analysis report for a prompt
struct PromptAnalysisReport: Identifiable, Codable {
    let id: String
    var prompt: String
    var score: PromptQualityScore
    var suggestions: [PromptSuggestion]
    var antiPatterns: [PromptAntiPattern]
    var rewriteSuggestion: PromptRewriteSuggestion?
    var analyzedAt: Date

    var issueCount: Int { antiPatterns.count }
    var criticalCount: Int { antiPatterns.filter { $0.severity == .critical }.count }
    var warningCount: Int { antiPatterns.filter { $0.severity == .warning }.count }
    var infoCount: Int { antiPatterns.filter { $0.severity == .info }.count }
}

// MARK: - History Sort Option

/// Sort options for prompt history records
enum PromptHistorySortOption: String, Codable, CaseIterable {
    case dateDesc
    case dateAsc
    case qualityDesc
    case qualityAsc
    case tokenDesc
    case costDesc

    var displayName: String {
        switch self {
        case .dateDesc: return "Latest First"
        case .dateAsc: return "Oldest First"
        case .qualityDesc: return "Best Quality"
        case .qualityAsc: return "Worst Quality"
        case .tokenDesc: return "Most Tokens"
        case .costDesc: return "Highest Cost"
        }
    }

    var iconName: String {
        switch self {
        case .dateDesc, .dateAsc: return "clock"
        case .qualityDesc, .qualityAsc: return "star"
        case .tokenDesc: return "number"
        case .costDesc: return "dollarsign.circle"
        }
    }
}

// MARK: - History Time Grouping

/// Time-based grouping for history organization
enum PromptHistoryTimeGrouping: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var iconName: String {
        switch self {
        case .daily: return "calendar"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar.circle"
        }
    }
}

// MARK: - History Statistics

/// Aggregated statistics for a time period group of prompts
struct PromptHistoryStats: Identifiable, Codable {
    let id: String
    var periodLabel: String
    var periodStart: Date
    var periodEnd: Date
    var totalCount: Int
    var successCount: Int
    var failedCount: Int
    var avgQualityScore: Double
    var totalTokens: Int
    var totalCostUSD: Double
    var tagDistribution: [String: Int]

    var successRate: Double {
        totalCount > 0 ? Double(successCount) / Double(totalCount) : 0
    }

    var avgTokensPerPrompt: Int {
        totalCount > 0 ? totalTokens / totalCount : 0
    }

    var avgCostPerPrompt: Double {
        totalCount > 0 ? totalCostUSD / Double(totalCount) : 0
    }
}

/// Category-based statistics for a tag group
struct PromptCategoryStats: Identifiable, Codable {
    let id: String
    var categoryName: String
    var count: Int
    var successRate: Double
    var avgQualityScore: Double
    var avgTokens: Int
    var totalCostUSD: Double
    var lastUsed: Date
}
