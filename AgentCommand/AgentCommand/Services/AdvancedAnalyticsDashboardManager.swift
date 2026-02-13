import Foundation
import Combine

// MARK: - M1: Advanced Analytics Dashboard Manager

/// Manages custom reports, trend forecasting, cost optimization, and performance benchmarks
@MainActor
class AdvancedAnalyticsDashboardManager: ObservableObject {

    // MARK: - Published State

    @Published var reports: [DashboardReport] = []
    @Published var currentReport: DashboardReport?
    @Published var forecasts: [TrendForecast] = []
    @Published var optimizationTips: [CostOptimizationTip] = []
    @Published var benchmarks: [PerformanceBenchmark] = []
    @Published var selectedTimeRange: AnalyticsTimeRange = .last7Days
    @Published var isLoading: Bool = false
    @Published var timeSeriesData: [String: [AnalyticsDataPoint]] = [:]

    // MARK: - Persistence Keys

    private static let reportsKey = "analyticsReports"
    private static let tipsKey = "analyticsOptimizationTips"
    private static let benchmarksKey = "analyticsBenchmarks"

    // MARK: - Memory Limits

    static let maxReports = 50
    static let maxForecasts = 20
    static let maxTips = 100
    static let maxBenchmarks = 30
    static let maxDataPoints = 500

    // MARK: - Initialization

    init() {
        load()
    }

    func initialize() {
        load()
        generateDefaultReportIfNeeded()
    }

    func shutdown() {
        save()
    }

    // MARK: - Report Management

    /// Create a new custom report
    func createReport(name: String, description: String = "", widgets: [ReportWidget] = []) -> DashboardReport {
        let report = DashboardReport(name: name, description: description, widgets: widgets)
        reports.append(report)
        enforceReportLimit()
        save()
        return report
    }

    /// Delete a report by ID
    func deleteReport(id: String) {
        reports.removeAll { $0.id == id }
        if currentReport?.id == id {
            currentReport = reports.first
        }
        save()
    }

    /// Add a widget to a report
    func addWidget(to reportId: String, widget: ReportWidget) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        var report = reports[index]
        report.widgets.append(widget)
        report.updatedAt = Date()
        reports[index] = report
        save()
    }

    /// Remove a widget from a report
    func removeWidget(from reportId: String, widgetId: String) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        var report = reports[index]
        report.widgets.removeAll { $0.id == widgetId }
        report.updatedAt = Date()
        reports[index] = report
        save()
    }

    /// Reorder widgets within a report
    func reorderWidgets(in reportId: String, widgets: [ReportWidget]) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        var report = reports[index]
        report.widgets = widgets.enumerated().map { offset, widget in
            var w = widget
            w.position = offset
            return w
        }
        report.updatedAt = Date()
        reports[index] = report
        save()
    }

    // MARK: - Trend Prediction

    /// Generate trend forecast using simple moving average
    func generateForecast(for metric: ForecastMetric, historicalData: [AnalyticsDataPoint], daysAhead: Int = 14) -> TrendForecast {
        isLoading = true
        defer { isLoading = false }

        let values = historicalData.map(\.value)
        let predictedValues = simpleMovingAverageForecast(values: values, periods: daysAhead)

        let calendar = Calendar.current
        let today = Date()
        var dataPoints: [ForecastDataPoint] = []

        // Add historical data points
        for point in historicalData.suffix(30) {
            dataPoints.append(ForecastDataPoint(
                date: point.timestamp,
                value: point.value,
                lowerBound: point.value,
                upperBound: point.value,
                isActual: true
            ))
        }

        // Add predicted data points
        let stdDev = standardDeviation(values)
        for (index, predicted) in predictedValues.enumerated() {
            let date = calendar.date(byAdding: .day, value: index + 1, to: today) ?? today
            let uncertaintyFactor = 1.0 + Double(index) * 0.1
            dataPoints.append(ForecastDataPoint(
                date: date,
                value: predicted,
                lowerBound: predicted - stdDev * uncertaintyFactor,
                upperBound: predicted + stdDev * uncertaintyFactor,
                isActual: false
            ))
        }

        let confidence = calculateForecastConfidence(values: values)

        let forecast = TrendForecast(
            metric: metric,
            dataPoints: dataPoints,
            confidence: confidence,
            periodDays: daysAhead
        )

        forecasts.append(forecast)
        enforceForcastLimit()

        return forecast
    }

    /// Simple Moving Average (SMA) prediction
    private func simpleMovingAverageForecast(values: [Double], periods: Int, windowSize: Int = 7) -> [Double] {
        guard values.count >= windowSize else {
            let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            return Array(repeating: avg, count: periods)
        }

        var predictions: [Double] = []
        var window = Array(values.suffix(windowSize))

        for _ in 0..<periods {
            let avg = window.reduce(0, +) / Double(window.count)
            predictions.append(avg)
            window.removeFirst()
            window.append(avg)
        }

        return predictions
    }

    /// Calculate confidence based on data variability
    private func calculateForecastConfidence(values: [Double]) -> Double {
        guard values.count >= 7 else { return 0.3 }

        let stdDev = standardDeviation(values)
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0.5 }

        let cv = stdDev / mean // Coefficient of variation
        let confidence = max(0.1, min(0.95, 1.0 - cv))

        return confidence
    }

    /// Standard deviation of an array of values
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return sqrt(variance)
    }

    // MARK: - Cost Optimization

    /// Analyze API call patterns and generate optimization tips
    func generateOptimizationTips(apiMetrics: [APICallMetrics]) -> [CostOptimizationTip] {
        var tips: [CostOptimizationTip] = []

        // Tip 1: Model selection optimization
        if let modelTip = analyzeModelSelection(apiMetrics) {
            tips.append(modelTip)
        }

        // Tip 2: Token reduction opportunities
        if let tokenTip = analyzeTokenUsage(apiMetrics) {
            tips.append(tokenTip)
        }

        // Tip 3: Caching opportunities
        if let cachingTip = analyzeCachingOpportunities(apiMetrics) {
            tips.append(cachingTip)
        }

        // Tip 4: Batch processing optimization
        if let batchTip = analyzeBatchProcessing(apiMetrics) {
            tips.append(batchTip)
        }

        optimizationTips = tips
        enforeTipsLimit()
        save()

        return tips
    }

    /// Analyze if cheaper models could be used for simple tasks
    private func analyzeModelSelection(_ metrics: [APICallMetrics]) -> CostOptimizationTip? {
        let expensiveCalls = metrics.filter { $0.costUSD > 0.01 && $0.totalTokens < 500 }
        guard expensiveCalls.count >= 5 else { return nil }

        let potentialSavings = expensiveCalls.reduce(0.0) { $0 + $1.costUSD * 0.6 }

        return CostOptimizationTip(
            category: .modelSelection,
            title: "Use lighter models for simple tasks",
            description: "Found \(expensiveCalls.count) API calls using expensive models for tasks with < 500 tokens. Consider using a lighter model for these.",
            estimatedSavings: potentialSavings * 30, // Monthly estimate
            impact: potentialSavings > 1.0 ? .high : .medium
        )
    }

    /// Analyze token usage for reduction opportunities
    private func analyzeTokenUsage(_ metrics: [APICallMetrics]) -> CostOptimizationTip? {
        let highTokenCalls = metrics.filter { $0.inputTokens > 2000 }
        guard highTokenCalls.count >= 3 else { return nil }

        let avgInputTokens = Double(highTokenCalls.reduce(0) { $0 + $1.inputTokens }) / Double(highTokenCalls.count)
        let estimatedReduction = avgInputTokens * 0.3 // Assume 30% reduction possible
        let costPerToken = 0.000003 // Approximate
        let savings = estimatedReduction * Double(highTokenCalls.count) * costPerToken * 30

        return CostOptimizationTip(
            category: .tokenReduction,
            title: "Reduce prompt lengths for verbose requests",
            description: "Found \(highTokenCalls.count) calls with > 2000 input tokens. Optimizing prompts could reduce tokens by ~30%.",
            estimatedSavings: savings,
            impact: savings > 0.5 ? .medium : .low
        )
    }

    /// Detect similar queries that could benefit from caching
    private func analyzeCachingOpportunities(_ metrics: [APICallMetrics]) -> CostOptimizationTip? {
        // Group by task type and count repetitions
        var taskTypeCounts: [String: Int] = [:]
        for metric in metrics {
            taskTypeCounts[metric.taskType, default: 0] += 1
        }

        let repeatedTasks = taskTypeCounts.filter { $0.value >= 5 }
        guard !repeatedTasks.isEmpty else { return nil }

        let totalRepeated = repeatedTasks.values.reduce(0, +)
        let avgCost = metrics.isEmpty ? 0 : metrics.reduce(0.0) { $0 + $1.costUSD } / Double(metrics.count)
        let savings = Double(totalRepeated) * avgCost * 0.5 * 30

        return CostOptimizationTip(
            category: .caching,
            title: "Cache repeated query patterns",
            description: "Found \(repeatedTasks.count) task types with 5+ repetitions. Implementing result caching could save significantly.",
            estimatedSavings: savings,
            impact: .medium
        )
    }

    /// Analyze if batch processing could reduce overhead
    private func analyzeBatchProcessing(_ metrics: [APICallMetrics]) -> CostOptimizationTip? {
        // Check for rapid-fire small calls
        let sortedByTime = metrics.sorted { $0.timestamp < $1.timestamp }
        var rapidSequenceCount = 0

        for i in 1..<sortedByTime.count {
            let interval = sortedByTime[i].timestamp.timeIntervalSince(sortedByTime[i - 1].timestamp)
            if interval < 2.0 && sortedByTime[i].totalTokens < 200 {
                rapidSequenceCount += 1
            }
        }

        guard rapidSequenceCount >= 10 else { return nil }

        let savings = Double(rapidSequenceCount) * 0.001 * 30 // Small per-call overhead savings

        return CostOptimizationTip(
            category: .batchProcessing,
            title: "Batch small sequential requests",
            description: "Found \(rapidSequenceCount) rapid-fire small requests. Batching these could reduce API overhead.",
            estimatedSavings: savings,
            impact: savings > 0.5 ? .medium : .low
        )
    }

    // MARK: - Performance Benchmarking

    /// Generate a benchmark comparison
    func createBenchmark(name: String, entries: [BenchmarkEntry], metric: BenchmarkMetric) -> PerformanceBenchmark {
        let benchmark = PerformanceBenchmark(name: name, entries: entries, metric: metric)
        benchmarks.append(benchmark)
        enforceBenchmarkLimit()
        save()
        return benchmark
    }

    /// Generate benchmark from API metrics grouped by model
    func benchmarkByModel(metrics: [APICallMetrics]) -> PerformanceBenchmark {
        var modelGroups: [String: [APICallMetrics]] = [:]
        for metric in metrics {
            modelGroups[metric.model, default: []].append(metric)
        }

        let entries: [BenchmarkEntry] = modelGroups.map { model, calls in
            let avgLatency = calls.reduce(0.0) { $0 + $1.latencyMs } / Double(calls.count)
            let errorRate = Double(calls.filter(\.isError).count) / Double(calls.count)
            let avgCost = calls.reduce(0.0) { $0 + $1.costUSD } / Double(calls.count)
            let successRate = 1.0 - errorRate

            return BenchmarkEntry(
                label: model,
                score: successRate,
                details: [
                    "avgLatencyMs": avgLatency,
                    "errorRate": errorRate,
                    "avgCostUSD": avgCost,
                    "totalCalls": Double(calls.count)
                ]
            )
        }

        return createBenchmark(name: "Model Comparison", entries: entries, metric: .taskSuccessRate)
    }

    // MARK: - Time Series Data

    /// Aggregate data points by day for a given metric
    func aggregateByDay(dataPoints: [AnalyticsDataPoint]) -> [AnalyticsDataPoint] {
        let calendar = Calendar.current
        var dailyGroups: [DateComponents: [Double]] = [:]

        for point in dataPoints {
            let components = calendar.dateComponents([.year, .month, .day], from: point.timestamp)
            dailyGroups[components, default: []].append(point.value)
        }

        return dailyGroups.compactMap { components, values in
            guard let date = calendar.date(from: components) else { return nil }
            let avg = values.reduce(0, +) / Double(values.count)
            return AnalyticsDataPoint(timestamp: date, value: avg)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(encoded, forKey: Self.reportsKey)
        }
        if let encoded = try? JSONEncoder().encode(optimizationTips) {
            UserDefaults.standard.set(encoded, forKey: Self.tipsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.reportsKey),
           let decoded = try? JSONDecoder().decode([DashboardReport].self, from: data) {
            reports = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.tipsKey),
           let decoded = try? JSONDecoder().decode([CostOptimizationTip].self, from: data) {
            optimizationTips = decoded
        }
    }

    private func generateDefaultReportIfNeeded() {
        guard reports.isEmpty else { return }
        _ = createReport(
            name: "Overview Dashboard",
            description: "Default analytics overview",
            widgets: [
                ReportWidget(type: .lineChart, title: "Token Usage Trend", dataSource: .tokenUsage, size: .large, position: 0),
                ReportWidget(type: .metric, title: "Total Cost", dataSource: .costOverTime, size: .small, position: 1),
                ReportWidget(type: .pieChart, title: "Model Distribution", dataSource: .modelDistribution, size: .medium, position: 2),
                ReportWidget(type: .barChart, title: "Task Completion", dataSource: .taskCompletion, size: .medium, position: 3)
            ]
        )
    }

    // MARK: - Memory Limits

    private func enforceReportLimit() {
        if reports.count > Self.maxReports {
            reports = Array(reports.suffix(Self.maxReports))
        }
    }

    private func enforceForcastLimit() {
        if forecasts.count > Self.maxForecasts {
            forecasts = Array(forecasts.suffix(Self.maxForecasts))
        }
    }

    private func enforeTipsLimit() {
        if optimizationTips.count > Self.maxTips {
            optimizationTips = Array(optimizationTips.suffix(Self.maxTips))
        }
    }

    private func enforceBenchmarkLimit() {
        if benchmarks.count > Self.maxBenchmarks {
            benchmarks = Array(benchmarks.suffix(Self.maxBenchmarks))
        }
    }
}
