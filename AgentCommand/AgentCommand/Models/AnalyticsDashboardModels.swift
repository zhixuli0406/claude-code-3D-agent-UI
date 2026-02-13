import Foundation

// MARK: - M1: Advanced Analytics Dashboard Models

/// A custom analytics report definition
struct DashboardReport: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var widgets: [ReportWidget]
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool

    init(name: String, description: String = "", widgets: [ReportWidget] = [], isDefault: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.widgets = widgets
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDefault = isDefault
    }
}

/// A configurable widget for the analytics dashboard
struct ReportWidget: Identifiable, Codable, Hashable {
    let id: String
    var type: WidgetType
    var title: String
    var dataSource: WidgetDataSource
    var size: WidgetSize
    var position: Int

    init(type: WidgetType, title: String, dataSource: WidgetDataSource, size: WidgetSize = .medium, position: Int = 0) {
        self.id = UUID().uuidString
        self.type = type
        self.title = title
        self.dataSource = dataSource
        self.size = size
        self.position = position
    }

    enum WidgetType: String, Codable, CaseIterable, Hashable {
        case lineChart
        case barChart
        case pieChart
        case metric
        case table
        case heatmap

        var displayName: String {
            switch self {
            case .lineChart: return "Line Chart"
            case .barChart: return "Bar Chart"
            case .pieChart: return "Pie Chart"
            case .metric: return "Metric"
            case .table: return "Table"
            case .heatmap: return "Heatmap"
            }
        }

        var iconName: String {
            switch self {
            case .lineChart: return "chart.xyaxis.line"
            case .barChart: return "chart.bar"
            case .pieChart: return "chart.pie"
            case .metric: return "number"
            case .table: return "tablecells"
            case .heatmap: return "square.grid.3x3.fill"
            }
        }
    }

    enum WidgetDataSource: String, Codable, CaseIterable, Hashable {
        case tokenUsage
        case costOverTime
        case taskCompletion
        case errorRate
        case responseLatency
        case modelDistribution

        var displayName: String {
            switch self {
            case .tokenUsage: return "Token Usage"
            case .costOverTime: return "Cost Over Time"
            case .taskCompletion: return "Task Completion"
            case .errorRate: return "Error Rate"
            case .responseLatency: return "Response Latency"
            case .modelDistribution: return "Model Distribution"
            }
        }
    }

    enum WidgetSize: String, Codable, CaseIterable, Hashable {
        case small
        case medium
        case large

        var columnSpan: Int {
            switch self {
            case .small: return 1
            case .medium: return 2
            case .large: return 3
            }
        }
    }
}

// MARK: - Trend Forecast

/// Forecast data point for a predicted metric
struct TrendForecast: Identifiable, Codable, Hashable {
    let id: String
    var metric: ForecastMetric
    var dataPoints: [ForecastDataPoint]
    var confidence: Double // 0.0 - 1.0
    var generatedAt: Date
    var periodDays: Int

    init(metric: ForecastMetric, dataPoints: [ForecastDataPoint], confidence: Double, periodDays: Int) {
        self.id = UUID().uuidString
        self.metric = metric
        self.dataPoints = dataPoints
        self.confidence = confidence
        self.generatedAt = Date()
        self.periodDays = periodDays
    }

    var confidencePercentage: Int { Int(confidence * 100) }

    var confidenceLabel: String {
        switch confidence {
        case 0.8...1.0: return "High"
        case 0.6..<0.8: return "Medium"
        default: return "Low"
        }
    }

    var confidenceColorHex: String {
        switch confidence {
        case 0.8...1.0: return "#4CAF50"
        case 0.6..<0.8: return "#FF9800"
        default: return "#F44336"
        }
    }
}

/// A single data point in a forecast
struct ForecastDataPoint: Identifiable, Codable, Hashable {
    let id: String
    var date: Date
    var value: Double
    var lowerBound: Double
    var upperBound: Double
    var isActual: Bool

    init(date: Date, value: Double, lowerBound: Double, upperBound: Double, isActual: Bool = false) {
        self.id = UUID().uuidString
        self.date = date
        self.value = value
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.isActual = isActual
    }
}

/// Metric types available for forecasting
enum ForecastMetric: String, Codable, CaseIterable, Hashable {
    case tokenUsage
    case cost
    case taskCount
    case errorRate
    case responseTime

    var displayName: String {
        switch self {
        case .tokenUsage: return "Token Usage"
        case .cost: return "Cost"
        case .taskCount: return "Task Count"
        case .errorRate: return "Error Rate"
        case .responseTime: return "Response Time"
        }
    }

    var unit: String {
        switch self {
        case .tokenUsage: return "tokens"
        case .cost: return "USD"
        case .taskCount: return "tasks"
        case .errorRate: return "%"
        case .responseTime: return "ms"
        }
    }

    var iconName: String {
        switch self {
        case .tokenUsage: return "number.circle"
        case .cost: return "dollarsign.circle"
        case .taskCount: return "checkmark.circle"
        case .errorRate: return "exclamationmark.triangle"
        case .responseTime: return "clock"
        }
    }
}

// MARK: - Cost Optimization

/// A cost optimization suggestion
struct CostOptimizationTip: Identifiable, Codable, Hashable {
    let id: String
    var category: OptimizationCategory
    var title: String
    var description: String
    var estimatedSavings: Double // USD per month
    var impact: OptimizationImpact
    var isApplied: Bool
    var createdAt: Date

    init(category: OptimizationCategory, title: String, description: String, estimatedSavings: Double, impact: OptimizationImpact) {
        self.id = UUID().uuidString
        self.category = category
        self.title = title
        self.description = description
        self.estimatedSavings = estimatedSavings
        self.impact = impact
        self.isApplied = false
        self.createdAt = Date()
    }

    var formattedSavings: String {
        String(format: "$%.2f/mo", estimatedSavings)
    }

    enum OptimizationCategory: String, Codable, CaseIterable, Hashable {
        case modelSelection
        case promptOptimization
        case caching
        case batchProcessing
        case tokenReduction

        var displayName: String {
            switch self {
            case .modelSelection: return "Model Selection"
            case .promptOptimization: return "Prompt Optimization"
            case .caching: return "Caching"
            case .batchProcessing: return "Batch Processing"
            case .tokenReduction: return "Token Reduction"
            }
        }

        var iconName: String {
            switch self {
            case .modelSelection: return "cpu"
            case .promptOptimization: return "text.badge.checkmark"
            case .caching: return "memorychip"
            case .batchProcessing: return "square.stack.3d.up"
            case .tokenReduction: return "arrow.down.right.circle"
            }
        }
    }

    enum OptimizationImpact: String, Codable, CaseIterable, Hashable {
        case high
        case medium
        case low

        var colorHex: String {
            switch self {
            case .high: return "#4CAF50"
            case .medium: return "#FF9800"
            case .low: return "#2196F3"
            }
        }

        var displayName: String {
            switch self {
            case .high: return "High Impact"
            case .medium: return "Medium Impact"
            case .low: return "Low Impact"
            }
        }
    }
}

// MARK: - Performance Benchmark

/// Performance benchmark comparing agents or teams
struct PerformanceBenchmark: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var entries: [BenchmarkEntry]
    var metric: BenchmarkMetric
    var generatedAt: Date

    init(name: String, entries: [BenchmarkEntry], metric: BenchmarkMetric) {
        self.id = UUID().uuidString
        self.name = name
        self.entries = entries
        self.metric = metric
        self.generatedAt = Date()
    }

    var bestEntry: BenchmarkEntry? {
        entries.max(by: { $0.score < $1.score })
    }

    var averageScore: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0.0) { $0 + $1.score } / Double(entries.count)
    }
}

/// A single entry in a benchmark comparison
struct BenchmarkEntry: Identifiable, Codable, Hashable {
    let id: String
    var label: String
    var score: Double
    var details: [String: Double]

    init(label: String, score: Double, details: [String: Double] = [:]) {
        self.id = UUID().uuidString
        self.label = label
        self.score = score
        self.details = details
    }

    var scorePercentage: Int { Int(score * 100) }
}

/// Metric types for benchmarking
enum BenchmarkMetric: String, Codable, CaseIterable, Hashable {
    case taskSuccessRate
    case averageResponseTime
    case costEfficiency
    case tokenEfficiency
    case errorRecoveryRate

    var displayName: String {
        switch self {
        case .taskSuccessRate: return "Task Success Rate"
        case .averageResponseTime: return "Avg Response Time"
        case .costEfficiency: return "Cost Efficiency"
        case .tokenEfficiency: return "Token Efficiency"
        case .errorRecoveryRate: return "Error Recovery Rate"
        }
    }

    var unit: String {
        switch self {
        case .taskSuccessRate: return "%"
        case .averageResponseTime: return "ms"
        case .costEfficiency: return "tasks/$"
        case .tokenEfficiency: return "tokens/task"
        case .errorRecoveryRate: return "%"
        }
    }
}

// MARK: - Analytics Time Range

/// Time range for analytics queries
enum AnalyticsTimeRange: String, Codable, CaseIterable {
    case lastHour
    case last24Hours
    case last7Days
    case last30Days
    case last90Days
    case custom

    var displayName: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .last24Hours: return "Last 24 Hours"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .custom: return "Custom"
        }
    }

    var dateInterval: DateInterval? {
        let now = Date()
        switch self {
        case .lastHour: return DateInterval(start: now.addingTimeInterval(-3600), end: now)
        case .last24Hours: return DateInterval(start: now.addingTimeInterval(-86400), end: now)
        case .last7Days: return DateInterval(start: now.addingTimeInterval(-604800), end: now)
        case .last30Days: return DateInterval(start: now.addingTimeInterval(-2592000), end: now)
        case .last90Days: return DateInterval(start: now.addingTimeInterval(-7776000), end: now)
        case .custom: return nil
        }
    }
}

// MARK: - Analytics Data Point

/// Generic time-series data point for analytics
struct AnalyticsDataPoint: Identifiable, Codable, Hashable {
    let id: String
    var timestamp: Date
    var value: Double
    var label: String?

    init(timestamp: Date, value: Double, label: String? = nil) {
        self.id = UUID().uuidString
        self.timestamp = timestamp
        self.value = value
        self.label = label
    }
}
