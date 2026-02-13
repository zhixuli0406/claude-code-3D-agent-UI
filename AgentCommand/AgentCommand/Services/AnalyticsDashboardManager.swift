import Foundation
import Combine

// MARK: - M1: Advanced Analytics Dashboard Manager

@MainActor
class AnalyticsDashboardManager: ObservableObject {
    @Published var reports: [DashboardReport] = []
    @Published var forecasts: [TrendForecast] = []
    @Published var optimizations: [CostOptimizationTip] = []
    @Published var benchmarks: [PerformanceBenchmark] = []
    @Published var selectedTimeRange: AnalyticsTimeRange = .last7Days
    @Published var isAnalyzing: Bool = false

    // Memory optimization: cap collection sizes to prevent unbounded growth
    private static let maxReports = 20
    private static let maxForecasts = 10
    private static let maxOptimizations = 30
    private static let maxBenchmarks = 10

    /// Back-reference to AppState for reading live agent/task data
    weak var appState: AppState?

    // MARK: - Report Management

    /// Create a new custom dashboard report
    func createReport(name: String, description: String = "") {
        let report = DashboardReport(name: name, description: description)
        reports.insert(report, at: 0)

        // Evict oldest non-default reports when exceeding cap
        while reports.count > Self.maxReports {
            if let nonDefaultIdx = reports.lastIndex(where: { !$0.isDefault }) {
                reports.remove(at: nonDefaultIdx)
            } else {
                // All are default — remove the oldest (last) entry
                reports.removeLast()
            }
        }
    }

    /// Delete a report by its ID
    func deleteReport(_ reportId: String) {
        reports.removeAll { $0.id == reportId }
    }

    /// Add a widget to an existing report
    func addWidget(to reportId: String, type: ReportWidget.WidgetType, title: String, dataSource: ReportWidget.WidgetDataSource, size: ReportWidget.WidgetSize) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        let position = reports[index].widgets.count
        let widget = ReportWidget(type: type, title: title, dataSource: dataSource, size: size, position: position)
        reports[index].widgets.append(widget)
        reports[index].updatedAt = Date()
    }

    /// Remove a widget from a report
    func removeWidget(from reportId: String, widgetId: String) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        reports[index].widgets.removeAll { $0.id == widgetId }
        // Re-index positions
        for i in reports[index].widgets.indices {
            reports[index].widgets[i].position = i
        }
        reports[index].updatedAt = Date()
    }

    // MARK: - Trend Forecasting

    /// Generate a trend forecast for the specified metric over a given period
    func generateForecast(for metric: ForecastMetric, periodDays: Int = 30) {
        isAnalyzing = true

        // Generate data points: historical (actual) + projected (forecast)
        let now = Date()
        let historicalDays = 14
        var dataPoints: [ForecastDataPoint] = []

        // Seed values based on the metric type
        var baseValue: Double
        var volatility: Double

        switch metric {
        case .tokenUsage:
            baseValue = 12000
            volatility = 2000
        case .cost:
            baseValue = 45.0
            volatility = 8.0
        case .taskCount:
            baseValue = 25
            volatility = 5
        case .errorRate:
            baseValue = 3.5
            volatility = 1.0
        case .responseTime:
            baseValue = 850
            volatility = 150
        }

        // Historical data points (actual)
        for day in stride(from: -historicalDays, through: 0, by: 1) {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let noise = Double.random(in: -volatility...volatility)
            let value = max(0, baseValue + noise)
            let point = ForecastDataPoint(
                date: date,
                value: value,
                lowerBound: value,
                upperBound: value,
                isActual: true
            )
            dataPoints.append(point)
        }

        // Projected data points (forecast) with widening confidence intervals
        let trendSlope = Double.random(in: -0.02...0.05) * baseValue
        for day in 1...periodDays {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let projectedValue = baseValue + trendSlope * Double(day) / Double(periodDays)
            let intervalWidth = volatility * (1.0 + Double(day) * 0.05)
            let point = ForecastDataPoint(
                date: date,
                value: max(0, projectedValue),
                lowerBound: max(0, projectedValue - intervalWidth),
                upperBound: projectedValue + intervalWidth,
                isActual: false
            )
            dataPoints.append(point)
        }

        let confidence = max(0.4, min(0.95, 0.9 - Double(periodDays) * 0.005))
        let forecast = TrendForecast(
            metric: metric,
            dataPoints: dataPoints,
            confidence: confidence,
            periodDays: periodDays
        )

        // Replace existing forecast for same metric, or append
        if let existingIdx = forecasts.firstIndex(where: { $0.metric == metric }) {
            forecasts[existingIdx] = forecast
        } else {
            forecasts.append(forecast)
        }

        // Evict oldest forecasts when exceeding cap
        if forecasts.count > Self.maxForecasts {
            forecasts = Array(forecasts.suffix(Self.maxForecasts))
        }

        isAnalyzing = false
    }

    // MARK: - Cost Optimization

    /// Analyze the current usage and generate cost optimization suggestions
    func analyzeOptimizations() {
        isAnalyzing = true

        let suggestions: [CostOptimizationTip] = [
            CostOptimizationTip(
                category: .modelSelection,
                title: "Downgrade simple tasks to a lighter model",
                description: "Analysis shows 40% of tasks involve simple text formatting that can be handled by a smaller, cheaper model. Routing these tasks to a lighter model could significantly reduce costs.",
                estimatedSavings: 120.0,
                impact: .high
            ),
            CostOptimizationTip(
                category: .promptOptimization,
                title: "Reduce system prompt length",
                description: "Several agents use system prompts exceeding 2,000 tokens. Condensing these prompts while preserving instructions can reduce per-request token costs.",
                estimatedSavings: 45.0,
                impact: .medium
            ),
            CostOptimizationTip(
                category: .caching,
                title: "Enable semantic caching for repeated queries",
                description: "Approximately 15% of queries are semantically similar to recent requests. Implementing a semantic cache layer could eliminate redundant API calls.",
                estimatedSavings: 85.0,
                impact: .high
            ),
            CostOptimizationTip(
                category: .batchProcessing,
                title: "Batch independent sub-tasks",
                description: "Multiple independent sub-tasks are being sent as sequential requests. Batching them into parallel calls can reduce wall-clock time and may qualify for batch pricing discounts.",
                estimatedSavings: 30.0,
                impact: .low
            ),
            CostOptimizationTip(
                category: .tokenReduction,
                title: "Trim verbose logging from context",
                description: "Debug logs are being included in agent context windows, consuming an average of 800 extra tokens per request. Removing verbose logs from the context can lower costs.",
                estimatedSavings: 55.0,
                impact: .medium
            ),
        ]

        // Add only suggestions that don't already exist (by title)
        let existingTitles = Set(optimizations.map(\.title))
        for tip in suggestions where !existingTitles.contains(tip.title) {
            optimizations.append(tip)
        }

        // Evict oldest unapplied tips when exceeding cap
        while optimizations.count > Self.maxOptimizations {
            if let unappliedIdx = optimizations.lastIndex(where: { !$0.isApplied }) {
                optimizations.remove(at: unappliedIdx)
            } else {
                optimizations.removeLast()
            }
        }

        isAnalyzing = false
    }

    /// Mark a cost optimization tip as applied
    func applyOptimization(_ tipId: String) {
        guard let index = optimizations.firstIndex(where: { $0.id == tipId }) else { return }
        optimizations[index].isApplied = true
    }

    // MARK: - Benchmarks

    /// Generate a performance benchmark comparing agents on the specified metric
    func generateBenchmark(metric: BenchmarkMetric) {
        isAnalyzing = true

        var entries: [BenchmarkEntry] = []

        // Generate benchmark entries from available agents or use defaults
        let agentNames: [String]
        if let appState = appState, !appState.agents.isEmpty {
            agentNames = appState.agents.prefix(6).map(\.name)
        } else {
            agentNames = ["Developer-1", "Reviewer-1", "Tester-1", "Architect-1"]
        }

        for name in agentNames {
            let score: Double
            var details: [String: Double] = [:]

            switch metric {
            case .taskSuccessRate:
                score = Double.random(in: 0.70...0.99)
                details["completed"] = Double(Int.random(in: 20...80))
                details["failed"] = Double(Int.random(in: 1...10))
            case .averageResponseTime:
                score = Double.random(in: 0.50...0.95)
                details["avg_ms"] = Double(Int.random(in: 400...2000))
                details["p95_ms"] = Double(Int.random(in: 1500...5000))
            case .costEfficiency:
                score = Double.random(in: 0.55...0.98)
                details["cost_per_task"] = Double.random(in: 0.02...0.15)
                details["total_cost"] = Double.random(in: 5.0...50.0)
            case .tokenEfficiency:
                score = Double.random(in: 0.60...0.95)
                details["avg_tokens"] = Double(Int.random(in: 500...5000))
                details["total_tokens"] = Double(Int.random(in: 10000...100000))
            case .errorRecoveryRate:
                score = Double.random(in: 0.40...0.95)
                details["recovered"] = Double(Int.random(in: 5...20))
                details["total_errors"] = Double(Int.random(in: 8...30))
            }

            entries.append(BenchmarkEntry(label: name, score: score, details: details))
        }

        let benchmark = PerformanceBenchmark(
            name: "\(metric.displayName) Benchmark",
            entries: entries,
            metric: metric
        )

        // Replace existing benchmark for same metric, or append
        if let existingIdx = benchmarks.firstIndex(where: { $0.metric == metric }) {
            benchmarks[existingIdx] = benchmark
        } else {
            benchmarks.append(benchmark)
        }

        // Evict oldest benchmarks when exceeding cap
        if benchmarks.count > Self.maxBenchmarks {
            benchmarks = Array(benchmarks.suffix(Self.maxBenchmarks))
        }

        isAnalyzing = false
    }

    // MARK: - Sample Data

    /// Load realistic sample data for previews and initial state
    func loadSampleData() {
        // -- Reports --
        var overviewReport = DashboardReport(
            name: "Daily Overview",
            description: "High-level summary of daily agent activity, token usage, and costs",
            widgets: [],
            isDefault: true
        )
        overviewReport.widgets = [
            ReportWidget(type: .metric, title: "Total Tokens Today", dataSource: .tokenUsage, size: .small, position: 0),
            ReportWidget(type: .lineChart, title: "Cost Trend", dataSource: .costOverTime, size: .large, position: 1),
            ReportWidget(type: .barChart, title: "Tasks by Status", dataSource: .taskCompletion, size: .medium, position: 2),
            ReportWidget(type: .pieChart, title: "Model Distribution", dataSource: .modelDistribution, size: .medium, position: 3),
        ]

        var performanceReport = DashboardReport(
            name: "Performance Deep Dive",
            description: "Detailed performance metrics including latency, error rates, and throughput",
            widgets: []
        )
        performanceReport.widgets = [
            ReportWidget(type: .lineChart, title: "Response Latency (p50/p95)", dataSource: .responseLatency, size: .large, position: 0),
            ReportWidget(type: .heatmap, title: "Error Rate Heatmap", dataSource: .errorRate, size: .medium, position: 1),
            ReportWidget(type: .table, title: "Top Token Consumers", dataSource: .tokenUsage, size: .medium, position: 2),
        ]

        reports = [overviewReport, performanceReport]

        // -- Forecasts --
        let now = Date()

        // Token usage forecast
        var tokenDataPoints: [ForecastDataPoint] = []
        for day in stride(from: -7, through: 0, by: 1) {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let value = 12000 + Double.random(in: -1500...1500)
            tokenDataPoints.append(ForecastDataPoint(date: date, value: value, lowerBound: value, upperBound: value, isActual: true))
        }
        for day in 1...14 {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let projected = 12500 + Double(day) * 150
            let interval = 800 + Double(day) * 100
            tokenDataPoints.append(ForecastDataPoint(date: date, value: projected, lowerBound: projected - interval, upperBound: projected + interval, isActual: false))
        }

        // Cost forecast
        var costDataPoints: [ForecastDataPoint] = []
        for day in stride(from: -7, through: 0, by: 1) {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let value = 42.0 + Double.random(in: -6.0...6.0)
            costDataPoints.append(ForecastDataPoint(date: date, value: value, lowerBound: value, upperBound: value, isActual: true))
        }
        for day in 1...14 {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let projected = 44.0 + Double(day) * 0.8
            let interval = 5.0 + Double(day) * 0.6
            costDataPoints.append(ForecastDataPoint(date: date, value: projected, lowerBound: max(0, projected - interval), upperBound: projected + interval, isActual: false))
        }

        // Error rate forecast
        var errorDataPoints: [ForecastDataPoint] = []
        for day in stride(from: -7, through: 0, by: 1) {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let value = 3.2 + Double.random(in: -0.8...0.8)
            errorDataPoints.append(ForecastDataPoint(date: date, value: value, lowerBound: value, upperBound: value, isActual: true))
        }
        for day in 1...14 {
            let date = Calendar.current.date(byAdding: .day, value: day, to: now) ?? now
            let projected = 3.0 - Double(day) * 0.05
            let interval = 0.5 + Double(day) * 0.08
            errorDataPoints.append(ForecastDataPoint(date: date, value: max(0, projected), lowerBound: max(0, projected - interval), upperBound: projected + interval, isActual: false))
        }

        forecasts = [
            TrendForecast(metric: .tokenUsage, dataPoints: tokenDataPoints, confidence: 0.87, periodDays: 14),
            TrendForecast(metric: .cost, dataPoints: costDataPoints, confidence: 0.82, periodDays: 14),
            TrendForecast(metric: .errorRate, dataPoints: errorDataPoints, confidence: 0.74, periodDays: 14),
        ]

        // -- Cost Optimization Tips --
        optimizations = [
            CostOptimizationTip(
                category: .modelSelection,
                title: "Use Haiku for classification tasks",
                description: "32% of agent tasks involve simple classification (pass/fail, yes/no). Routing these to Claude Haiku instead of Sonnet can reduce costs by up to 90% per request with minimal quality loss.",
                estimatedSavings: 95.0,
                impact: .high
            ),
            CostOptimizationTip(
                category: .caching,
                title: "Cache repeated tool-use results",
                description: "File-read and directory-listing tool calls are repeated across agent turns. Caching these results for 60 seconds can eliminate 25% of redundant API calls.",
                estimatedSavings: 60.0,
                impact: .high
            ),
            CostOptimizationTip(
                category: .promptOptimization,
                title: "Compress system prompts with structured formatting",
                description: "Replacing verbose natural-language instructions with structured bullet points and XML tags can reduce system prompt tokens by 35% without degrading output quality.",
                estimatedSavings: 38.0,
                impact: .medium
            ),
            CostOptimizationTip(
                category: .tokenReduction,
                title: "Truncate large file contents in context",
                description: "Some agents include entire file contents (up to 5,000 lines) in the context window. Truncating to relevant sections with line-range references can save thousands of tokens per request.",
                estimatedSavings: 72.0,
                impact: .high
            ),
            CostOptimizationTip(
                category: .batchProcessing,
                title: "Consolidate sequential review requests",
                description: "Code review agents send separate requests for each file. Batching files into a single review request can reduce overhead tokens and lower total cost by ~20%.",
                estimatedSavings: 25.0,
                impact: .low
            ),
        ]

        // -- Benchmarks --
        benchmarks = [
            PerformanceBenchmark(
                name: "Task Success Rate Benchmark",
                entries: [
                    BenchmarkEntry(label: "Developer-1", score: 0.94, details: ["completed": 47, "failed": 3]),
                    BenchmarkEntry(label: "Reviewer-1", score: 0.89, details: ["completed": 34, "failed": 4]),
                    BenchmarkEntry(label: "Tester-1", score: 0.92, details: ["completed": 55, "failed": 5]),
                    BenchmarkEntry(label: "Architect-1", score: 0.97, details: ["completed": 29, "failed": 1]),
                ],
                metric: .taskSuccessRate
            ),
            PerformanceBenchmark(
                name: "Cost Efficiency Benchmark",
                entries: [
                    BenchmarkEntry(label: "Developer-1", score: 0.78, details: ["cost_per_task": 0.08, "total_cost": 28.5]),
                    BenchmarkEntry(label: "Reviewer-1", score: 0.85, details: ["cost_per_task": 0.05, "total_cost": 15.2]),
                    BenchmarkEntry(label: "Tester-1", score: 0.72, details: ["cost_per_task": 0.10, "total_cost": 38.0]),
                    BenchmarkEntry(label: "Architect-1", score: 0.91, details: ["cost_per_task": 0.04, "total_cost": 9.8]),
                ],
                metric: .costEfficiency
            ),
        ]
    }

    // MARK: - Computed Properties

    /// Total potential savings across all unapplied optimization tips
    var totalPotentialSavings: Double {
        optimizations
            .filter { !$0.isApplied }
            .reduce(0.0) { $0 + $1.estimatedSavings }
    }

    /// Count of optimization tips that have been applied
    var appliedSavingsCount: Int {
        optimizations.filter(\.isApplied).count
    }
}
