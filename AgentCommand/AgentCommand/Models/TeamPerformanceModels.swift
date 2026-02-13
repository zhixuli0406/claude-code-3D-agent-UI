import Foundation

// MARK: - M5: Team Performance Metrics Models

/// Performance snapshot for an agent team
struct TeamPerformanceSnapshot: Identifiable, Codable, Hashable {
    let id: String
    var teamName: String
    var capturedAt: Date
    var memberMetrics: [AgentPerformanceMetric]
    var overallEfficiency: Double // 0.0 - 1.0
    var totalTasksCompleted: Int
    var totalCost: Double
    var averageResponseTime: Double // ms

    init(teamName: String, memberMetrics: [AgentPerformanceMetric] = [], overallEfficiency: Double = 0, totalTasksCompleted: Int = 0, totalCost: Double = 0, averageResponseTime: Double = 0) {
        self.id = UUID().uuidString
        self.teamName = teamName
        self.capturedAt = Date()
        self.memberMetrics = memberMetrics
        self.overallEfficiency = overallEfficiency
        self.totalTasksCompleted = totalTasksCompleted
        self.totalCost = totalCost
        self.averageResponseTime = averageResponseTime
    }

    var efficiencyPercentage: Int { Int(overallEfficiency * 100) }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var efficiencyLabel: String {
        switch overallEfficiency {
        case 0.85...1.0: return "Outstanding"
        case 0.7..<0.85: return "Strong"
        case 0.55..<0.7: return "Moderate"
        default: return "Needs Improvement"
        }
    }

    var efficiencyColorHex: String {
        switch overallEfficiency {
        case 0.85...1.0: return "#4CAF50"
        case 0.7..<0.85: return "#8BC34A"
        case 0.55..<0.7: return "#FF9800"
        default: return "#F44336"
        }
    }
}

// MARK: - Agent Performance Metric

/// Detailed performance metrics for a single agent
struct AgentPerformanceMetric: Identifiable, Codable, Hashable {
    let id: String
    var agentName: String
    var role: String
    var tasksCompleted: Int
    var tasksFailed: Int
    var averageLatencyMs: Double
    var totalTokens: Int
    var totalCost: Double
    var efficiency: Double // 0.0 - 1.0
    var specialization: AgentSpecialization

    init(agentName: String, role: String = "Developer", tasksCompleted: Int = 0, tasksFailed: Int = 0, averageLatencyMs: Double = 0, totalTokens: Int = 0, totalCost: Double = 0, efficiency: Double = 0, specialization: AgentSpecialization = .general) {
        self.id = UUID().uuidString
        self.agentName = agentName
        self.role = role
        self.tasksCompleted = tasksCompleted
        self.tasksFailed = tasksFailed
        self.averageLatencyMs = averageLatencyMs
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.efficiency = efficiency
        self.specialization = specialization
    }

    var successRate: Double {
        let total = tasksCompleted + tasksFailed
        guard total > 0 else { return 0 }
        return Double(tasksCompleted) / Double(total)
    }

    var successRatePercentage: Int { Int(successRate * 100) }
    var efficiencyPercentage: Int { Int(efficiency * 100) }

    var costPerTask: Double {
        guard tasksCompleted > 0 else { return 0 }
        return totalCost / Double(tasksCompleted)
    }

    var formattedCostPerTask: String {
        String(format: "$%.3f", costPerTask)
    }
}

/// Agent specialization area
enum AgentSpecialization: String, Codable, CaseIterable, Hashable {
    case general
    case codeGeneration
    case codeReview
    case testing
    case debugging
    case documentation
    case architecture

    var displayName: String {
        switch self {
        case .general: return "General"
        case .codeGeneration: return "Code Generation"
        case .codeReview: return "Code Review"
        case .testing: return "Testing"
        case .debugging: return "Debugging"
        case .documentation: return "Documentation"
        case .architecture: return "Architecture"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "person"
        case .codeGeneration: return "chevron.left.forwardslash.chevron.right"
        case .codeReview: return "eye"
        case .testing: return "testtube.2"
        case .debugging: return "ant"
        case .documentation: return "doc.text"
        case .architecture: return "building.2"
        }
    }

    var colorHex: String {
        switch self {
        case .general: return "#9E9E9E"
        case .codeGeneration: return "#4CAF50"
        case .codeReview: return "#2196F3"
        case .testing: return "#9C27B0"
        case .debugging: return "#F44336"
        case .documentation: return "#FF9800"
        case .architecture: return "#00BCD4"
        }
    }
}

// MARK: - Team Radar Chart Data

/// Multi-dimensional team performance for radar charts
struct TeamRadarData: Identifiable, Codable, Hashable {
    let id: String
    var teamName: String
    var dimensions: [RadarDimension]
    var generatedAt: Date

    init(teamName: String, dimensions: [RadarDimension]) {
        self.id = UUID().uuidString
        self.teamName = teamName
        self.dimensions = dimensions
        self.generatedAt = Date()
    }

    var averageScore: Double {
        guard !dimensions.isEmpty else { return 0 }
        return dimensions.reduce(0.0) { $0 + $1.value } / Double(dimensions.count)
    }
}

/// A single dimension in a radar chart
struct RadarDimension: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var value: Double // 0.0 - 1.0
    var category: PerformanceDimension

    init(category: PerformanceDimension, value: Double) {
        self.id = UUID().uuidString
        self.name = category.displayName
        self.value = min(1.0, max(0, value))
        self.category = category
    }

    var percentage: Int { Int(value * 100) }
}

/// Dimensions of team performance
enum PerformanceDimension: String, Codable, CaseIterable, Hashable {
    case speed
    case quality
    case costEfficiency
    case reliability
    case collaboration
    case throughput

    var displayName: String {
        switch self {
        case .speed: return "Speed"
        case .quality: return "Quality"
        case .costEfficiency: return "Cost Efficiency"
        case .reliability: return "Reliability"
        case .collaboration: return "Collaboration"
        case .throughput: return "Throughput"
        }
    }

    var iconName: String {
        switch self {
        case .speed: return "bolt"
        case .quality: return "star"
        case .costEfficiency: return "dollarsign.circle"
        case .reliability: return "checkmark.shield"
        case .collaboration: return "person.2"
        case .throughput: return "arrow.up.right"
        }
    }
}

// MARK: - Team Leaderboard

/// Leaderboard ranking teams by a metric
struct TeamLeaderboard: Identifiable, Codable, Hashable {
    let id: String
    var metric: LeaderboardMetric
    var entries: [LeaderboardEntry]
    var generatedAt: Date

    init(metric: LeaderboardMetric, entries: [LeaderboardEntry]) {
        self.id = UUID().uuidString
        self.metric = metric
        self.entries = entries.sorted { $0.score > $1.score }
        self.generatedAt = Date()
    }
}

/// A single entry in a leaderboard
struct LeaderboardEntry: Identifiable, Codable, Hashable {
    let id: String
    var agentName: String
    var score: Double
    var rank: Int
    var trend: TrendDirection

    init(agentName: String, score: Double, rank: Int, trend: TrendDirection = .stable) {
        self.id = UUID().uuidString
        self.agentName = agentName
        self.score = score
        self.rank = rank
        self.trend = trend
    }

    var formattedScore: String {
        String(format: "%.1f", score)
    }
}

/// Metrics available for leaderboard ranking
enum LeaderboardMetric: String, Codable, CaseIterable, Hashable {
    case tasksCompleted
    case successRate
    case costEfficiency
    case speed
    case tokensUsed

    var displayName: String {
        switch self {
        case .tasksCompleted: return "Tasks Completed"
        case .successRate: return "Success Rate"
        case .costEfficiency: return "Cost Efficiency"
        case .speed: return "Speed"
        case .tokensUsed: return "Tokens Used"
        }
    }

    var unit: String {
        switch self {
        case .tasksCompleted: return "tasks"
        case .successRate: return "%"
        case .costEfficiency: return "tasks/$"
        case .speed: return "ms"
        case .tokensUsed: return "tokens"
        }
    }
}
