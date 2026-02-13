import Foundation

// MARK: - M3: API Usage Analytics Models

/// Detailed metrics for a single API call
struct APICallMetrics: Identifiable, Codable, Hashable {
    let id: String
    var model: String
    var inputTokens: Int
    var outputTokens: Int
    var latencyMs: Double
    var costUSD: Double
    var isError: Bool
    var errorType: String?
    var taskType: String
    var timestamp: Date

    init(model: String, inputTokens: Int, outputTokens: Int, latencyMs: Double, costUSD: Double, isError: Bool = false, errorType: String? = nil, taskType: String = "general") {
        self.id = UUID().uuidString
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.latencyMs = latencyMs
        self.costUSD = costUSD
        self.isError = isError
        self.errorType = errorType
        self.taskType = taskType
        self.timestamp = Date()
    }

    var totalTokens: Int { inputTokens + outputTokens }

    var formattedLatency: String {
        if latencyMs >= 1000 {
            return String(format: "%.1fs", latencyMs / 1000)
        }
        return String(format: "%.0fms", latencyMs)
    }

    var formattedCost: String {
        String(format: "$%.4f", costUSD)
    }
}

// MARK: - Cost Breakdown

/// Cost breakdown by category (model or task type)
struct CostBreakdown: Identifiable, Codable, Hashable {
    let id: String
    var entries: [CostBreakdownEntry]
    var totalCost: Double
    var period: String
    var generatedAt: Date

    init(entries: [CostBreakdownEntry], period: String) {
        self.id = UUID().uuidString
        self.entries = entries
        self.totalCost = entries.reduce(0) { $0 + $1.cost }
        self.period = period
        self.generatedAt = Date()
    }

    var formattedTotal: String {
        String(format: "$%.2f", totalCost)
    }
}

/// A single entry in a cost breakdown
struct CostBreakdownEntry: Identifiable, Codable, Hashable {
    let id: String
    var category: String
    var cost: Double
    var tokenCount: Int
    var callCount: Int
    var percentage: Double

    init(category: String, cost: Double, tokenCount: Int, callCount: Int, totalCost: Double) {
        self.id = UUID().uuidString
        self.category = category
        self.cost = cost
        self.tokenCount = tokenCount
        self.callCount = callCount
        self.percentage = totalCost > 0 ? cost / totalCost : 0
    }

    var formattedCost: String {
        String(format: "$%.2f", cost)
    }

    var percentageDisplay: Int { Int(percentage * 100) }
}

// MARK: - Budget Alert

/// Budget monitoring and alerts
struct BudgetAlert: Identifiable, Codable, Hashable {
    let id: String
    var monthlyBudget: Double
    var currentSpend: Double
    var alertThreshold: Double // 0.0 - 1.0 (e.g., 0.8 = alert at 80%)
    var isActive: Bool
    var lastTriggeredAt: Date?
    var createdAt: Date

    init(monthlyBudget: Double, alertThreshold: Double = 0.8) {
        self.id = UUID().uuidString
        self.monthlyBudget = monthlyBudget
        self.currentSpend = 0
        self.alertThreshold = alertThreshold
        self.isActive = true
        self.createdAt = Date()
    }

    var spendPercentage: Double {
        guard monthlyBudget > 0 else { return 0 }
        return currentSpend / monthlyBudget
    }

    var spendPercentageDisplay: Int { Int(spendPercentage * 100) }

    var remainingBudget: Double {
        max(0, monthlyBudget - currentSpend)
    }

    var formattedBudget: String {
        String(format: "$%.2f", monthlyBudget)
    }

    var formattedSpend: String {
        String(format: "$%.2f", currentSpend)
    }

    var formattedRemaining: String {
        String(format: "$%.2f", remainingBudget)
    }

    var alertLevel: BudgetAlertLevel {
        switch spendPercentage {
        case 0.9...: return .critical
        case alertThreshold..<0.9: return .warning
        default: return .normal
        }
    }

    enum BudgetAlertLevel: String, Codable, Hashable {
        case normal
        case warning
        case critical

        var displayName: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }

        var colorHex: String {
            switch self {
            case .normal: return "#4CAF50"
            case .warning: return "#FF9800"
            case .critical: return "#F44336"
            }
        }

        var iconName: String {
            switch self {
            case .normal: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .critical: return "xmark.octagon"
            }
        }
    }
}

// MARK: - Usage Forecast

/// Forecast for API usage and cost
struct UsageForecast: Identifiable, Codable, Hashable {
    let id: String
    var forecastedMonthEndCost: Double
    var forecastedMonthEndTokens: Int
    var dailyAverage: Double
    var trend: UsageTrend
    var dataPoints: [ForecastDataPoint]
    var generatedAt: Date

    init(forecastedMonthEndCost: Double, forecastedMonthEndTokens: Int, dailyAverage: Double, trend: UsageTrend, dataPoints: [ForecastDataPoint] = []) {
        self.id = UUID().uuidString
        self.forecastedMonthEndCost = forecastedMonthEndCost
        self.forecastedMonthEndTokens = forecastedMonthEndTokens
        self.dailyAverage = dailyAverage
        self.trend = trend
        self.dataPoints = dataPoints
        self.generatedAt = Date()
    }

    var formattedForecastCost: String {
        String(format: "$%.2f", forecastedMonthEndCost)
    }

    var formattedDailyAverage: String {
        String(format: "$%.2f/day", dailyAverage)
    }

    enum UsageTrend: String, Codable, Hashable {
        case increasing
        case stable
        case decreasing

        var displayName: String {
            switch self {
            case .increasing: return "Increasing"
            case .stable: return "Stable"
            case .decreasing: return "Decreasing"
            }
        }

        var iconName: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .decreasing: return "arrow.down.right"
            }
        }

        var colorHex: String {
            switch self {
            case .increasing: return "#F44336"
            case .stable: return "#FF9800"
            case .decreasing: return "#4CAF50"
            }
        }
    }
}

// MARK: - Model Usage Statistics

/// Per-model usage statistics
struct ModelUsageStats: Identifiable, Codable, Hashable {
    let id: String
    var modelName: String
    var totalCalls: Int
    var totalTokens: Int
    var totalCost: Double
    var averageLatencyMs: Double
    var errorRate: Double // 0.0 - 1.0
    var lastUsedAt: Date?

    init(modelName: String, totalCalls: Int = 0, totalTokens: Int = 0, totalCost: Double = 0, averageLatencyMs: Double = 0, errorRate: Double = 0) {
        self.id = UUID().uuidString
        self.modelName = modelName
        self.totalCalls = totalCalls
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.averageLatencyMs = averageLatencyMs
        self.errorRate = errorRate
    }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var errorRatePercentage: Int { Int(errorRate * 100) }

    var costPerCall: Double {
        guard totalCalls > 0 else { return 0 }
        return totalCost / Double(totalCalls)
    }

    var tokensPerCall: Double {
        guard totalCalls > 0 else { return 0 }
        return Double(totalTokens) / Double(totalCalls)
    }
}

// MARK: - API Usage Summary

/// Aggregated usage summary for a time period
struct APIUsageSummary: Codable {
    var totalCalls: Int
    var totalTokens: Int
    var totalCost: Double
    var averageLatencyMs: Double
    var errorCount: Int
    var uniqueModels: Int
    var periodStart: Date
    var periodEnd: Date

    var errorRate: Double {
        guard totalCalls > 0 else { return 0 }
        return Double(errorCount) / Double(totalCalls)
    }

    var errorRatePercentage: Int { Int(errorRate * 100) }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    static let empty = APIUsageSummary(
        totalCalls: 0, totalTokens: 0, totalCost: 0,
        averageLatencyMs: 0, errorCount: 0, uniqueModels: 0,
        periodStart: Date(), periodEnd: Date()
    )
}
