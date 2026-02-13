import Foundation

// MARK: - M4: Session History Analytics Models

/// Aggregated analytics for a single coding session
struct SessionAnalytics: Identifiable, Codable, Hashable {
    let id: String
    var sessionName: String
    var startedAt: Date
    var endedAt: Date?
    var totalTokens: Int
    var totalCost: Double
    var tasksCompleted: Int
    var tasksFailed: Int
    var agentsUsed: Int
    var dominantModel: String
    var averageLatencyMs: Double
    var peakTokenRate: Int // tokens/minute at peak
    var productivityScore: Double // 0.0 - 1.0

    init(sessionName: String, startedAt: Date = Date(), totalTokens: Int = 0, totalCost: Double = 0, tasksCompleted: Int = 0, tasksFailed: Int = 0, agentsUsed: Int = 0, dominantModel: String = "sonnet", averageLatencyMs: Double = 0, peakTokenRate: Int = 0, productivityScore: Double = 0) {
        self.id = UUID().uuidString
        self.sessionName = sessionName
        self.startedAt = startedAt
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.tasksCompleted = tasksCompleted
        self.tasksFailed = tasksFailed
        self.agentsUsed = agentsUsed
        self.dominantModel = dominantModel
        self.averageLatencyMs = averageLatencyMs
        self.peakTokenRate = peakTokenRate
        self.productivityScore = productivityScore
    }

    var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "In Progress" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var successRate: Double {
        let total = tasksCompleted + tasksFailed
        guard total > 0 else { return 0 }
        return Double(tasksCompleted) / Double(total)
    }

    var successRatePercentage: Int { Int(successRate * 100) }

    var productivityLabel: String {
        switch productivityScore {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Average"
        default: return "Below Average"
        }
    }

    var productivityColorHex: String {
        switch productivityScore {
        case 0.8...1.0: return "#4CAF50"
        case 0.6..<0.8: return "#8BC34A"
        case 0.4..<0.6: return "#FF9800"
        default: return "#F44336"
        }
    }
}

// MARK: - Productivity Trend

/// Tracks productivity over time
struct ProductivityTrend: Identifiable, Codable, Hashable {
    let id: String
    var dataPoints: [ProductivityDataPoint]
    var overallTrend: TrendDirection
    var averageProductivity: Double
    var generatedAt: Date

    init(dataPoints: [ProductivityDataPoint], overallTrend: TrendDirection, averageProductivity: Double) {
        self.id = UUID().uuidString
        self.dataPoints = dataPoints
        self.overallTrend = overallTrend
        self.averageProductivity = averageProductivity
        self.generatedAt = Date()
    }

    var averagePercentage: Int { Int(averageProductivity * 100) }
}

/// A single productivity data point
struct ProductivityDataPoint: Identifiable, Codable, Hashable {
    let id: String
    var date: Date
    var productivity: Double // 0.0 - 1.0
    var tasksCompleted: Int
    var tokensUsed: Int
    var cost: Double

    init(date: Date, productivity: Double, tasksCompleted: Int = 0, tokensUsed: Int = 0, cost: Double = 0) {
        self.id = UUID().uuidString
        self.date = date
        self.productivity = productivity
        self.tasksCompleted = tasksCompleted
        self.tokensUsed = tokensUsed
        self.cost = cost
    }
}

/// Direction of a trend
enum TrendDirection: String, Codable, CaseIterable, Hashable {
    case improving
    case stable
    case declining

    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var colorHex: String {
        switch self {
        case .improving: return "#4CAF50"
        case .stable: return "#FF9800"
        case .declining: return "#F44336"
        }
    }
}

// MARK: - Session Comparison

/// Comparison between two sessions
struct SessionComparison: Identifiable, Codable, Hashable {
    let id: String
    var sessionAId: String
    var sessionBId: String
    var sessionAName: String
    var sessionBName: String
    var metrics: [ComparisonMetric]
    var generatedAt: Date

    init(sessionA: SessionAnalytics, sessionB: SessionAnalytics) {
        self.id = UUID().uuidString
        self.sessionAId = sessionA.id
        self.sessionBId = sessionB.id
        self.sessionAName = sessionA.sessionName
        self.sessionBName = sessionB.sessionName
        self.generatedAt = Date()

        self.metrics = [
            ComparisonMetric(name: "Tasks Completed", valueA: Double(sessionA.tasksCompleted), valueB: Double(sessionB.tasksCompleted), unit: "tasks"),
            ComparisonMetric(name: "Cost", valueA: sessionA.totalCost, valueB: sessionB.totalCost, unit: "USD"),
            ComparisonMetric(name: "Tokens", valueA: Double(sessionA.totalTokens), valueB: Double(sessionB.totalTokens), unit: "tokens"),
            ComparisonMetric(name: "Avg Latency", valueA: sessionA.averageLatencyMs, valueB: sessionB.averageLatencyMs, unit: "ms"),
            ComparisonMetric(name: "Productivity", valueA: sessionA.productivityScore, valueB: sessionB.productivityScore, unit: "score"),
            ComparisonMetric(name: "Success Rate", valueA: sessionA.successRate, valueB: sessionB.successRate, unit: "%"),
        ]
    }
}

/// A single metric in a session comparison
struct ComparisonMetric: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var valueA: Double
    var valueB: Double
    var unit: String

    init(name: String, valueA: Double, valueB: Double, unit: String) {
        self.id = UUID().uuidString
        self.name = name
        self.valueA = valueA
        self.valueB = valueB
        self.unit = unit
    }

    var delta: Double { valueB - valueA }

    var deltaPercentage: Double {
        guard valueA > 0 else { return 0 }
        return (valueB - valueA) / valueA
    }

    var deltaDisplay: String {
        let pct = Int(deltaPercentage * 100)
        return pct >= 0 ? "+\(pct)%" : "\(pct)%"
    }
}

// MARK: - Session Time Distribution

/// How time was spent during a session
struct SessionTimeDistribution: Identifiable, Codable, Hashable {
    let id: String
    var entries: [TimeDistributionEntry]
    var totalMinutes: Double

    init(entries: [TimeDistributionEntry]) {
        self.id = UUID().uuidString
        self.entries = entries
        self.totalMinutes = entries.reduce(0) { $0 + $1.minutes }
    }
}

/// A category of time spent
struct TimeDistributionEntry: Identifiable, Codable, Hashable {
    let id: String
    var category: TimeCategory
    var minutes: Double
    var percentage: Double

    init(category: TimeCategory, minutes: Double, totalMinutes: Double) {
        self.id = UUID().uuidString
        self.category = category
        self.minutes = minutes
        self.percentage = totalMinutes > 0 ? minutes / totalMinutes : 0
    }

    var percentageDisplay: Int { Int(percentage * 100) }

    enum TimeCategory: String, Codable, CaseIterable, Hashable {
        case coding
        case reviewing
        case debugging
        case testing
        case planning
        case idle

        var displayName: String {
            switch self {
            case .coding: return "Coding"
            case .reviewing: return "Reviewing"
            case .debugging: return "Debugging"
            case .testing: return "Testing"
            case .planning: return "Planning"
            case .idle: return "Idle"
            }
        }

        var colorHex: String {
            switch self {
            case .coding: return "#4CAF50"
            case .reviewing: return "#2196F3"
            case .debugging: return "#F44336"
            case .testing: return "#9C27B0"
            case .planning: return "#FF9800"
            case .idle: return "#9E9E9E"
            }
        }

        var iconName: String {
            switch self {
            case .coding: return "chevron.left.forwardslash.chevron.right"
            case .reviewing: return "eye"
            case .debugging: return "ant"
            case .testing: return "testtube.2"
            case .planning: return "map"
            case .idle: return "moon.zzz"
            }
        }
    }
}
