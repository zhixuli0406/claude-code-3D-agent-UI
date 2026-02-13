import Foundation
import Combine

// MARK: - M3: API Usage Analytics Manager

@MainActor
class APIUsageAnalyticsManager: ObservableObject {
    @Published var callRecords: [APICallMetrics] = []
    @Published var costBreakdowns: [CostBreakdown] = []
    @Published var modelStats: [ModelUsageStats] = []
    @Published var budgetAlert: BudgetAlert?
    @Published var usageForecast: UsageForecast?
    @Published var summary: APIUsageSummary = .empty
    @Published var isMonitoring: Bool = false

    // Memory optimization: cap collection sizes to prevent unbounded growth
    private static let maxRecords = 500
    private static let maxBreakdowns = 10

    /// Back-reference to AppState for reading live data
    weak var appState: AppState?
    private var monitorTimer: Timer?

    deinit {
        monitorTimer?.invalidate()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        isMonitoring = true
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSummary()
                self?.updateModelStats()
                self?.generateForecast()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - Record API Calls

    func recordAPICall(model: String, inputTokens: Int, outputTokens: Int, latencyMs: Double, costUSD: Double, taskType: String, isError: Bool = false, errorType: String? = nil) {
        let record = APICallMetrics(
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            latencyMs: latencyMs,
            costUSD: costUSD,
            isError: isError,
            errorType: errorType,
            taskType: taskType
        )
        callRecords.insert(record, at: 0)

        // Evict oldest records when exceeding cap
        if callRecords.count > Self.maxRecords {
            callRecords = Array(callRecords.prefix(Self.maxRecords))
        }

        // Update budget spend tracking
        updateBudgetSpend(costUSD)
        updateSummary()
    }

    // MARK: - Cost Analysis

    func generateCostBreakdown(period: String) {
        guard !callRecords.isEmpty else { return }

        // Group records by model to build cost breakdown entries
        var modelGroups: [String: [APICallMetrics]] = [:]
        for record in callRecords {
            modelGroups[record.model, default: []].append(record)
        }

        let totalCost = callRecords.reduce(0.0) { $0 + $1.costUSD }

        let entries: [CostBreakdownEntry] = modelGroups.map { model, records in
            let cost = records.reduce(0.0) { $0 + $1.costUSD }
            let tokens = records.reduce(0) { $0 + $1.totalTokens }
            return CostBreakdownEntry(
                category: model,
                cost: cost,
                tokenCount: tokens,
                callCount: records.count,
                totalCost: totalCost
            )
        }.sorted { $0.cost > $1.cost }

        let breakdown = CostBreakdown(entries: entries, period: period)
        costBreakdowns.insert(breakdown, at: 0)

        // Evict oldest breakdowns when exceeding cap
        if costBreakdowns.count > Self.maxBreakdowns {
            costBreakdowns = Array(costBreakdowns.prefix(Self.maxBreakdowns))
        }
    }

    // MARK: - Budget Management

    func setBudget(monthly: Double, alertThreshold: Double = 0.8) {
        var alert = BudgetAlert(monthlyBudget: monthly, alertThreshold: alertThreshold)
        // Carry forward current spend if replacing an existing budget
        if let existing = budgetAlert {
            alert.currentSpend = existing.currentSpend
        }
        budgetAlert = alert
    }

    func updateBudgetSpend(_ cost: Double) {
        guard var alert = budgetAlert, alert.isActive else { return }
        let previousLevel = alert.alertLevel
        alert.currentSpend += cost

        // Check if we crossed a threshold
        if alert.alertLevel != .normal && alert.alertLevel != previousLevel {
            alert.lastTriggeredAt = Date()
        }

        budgetAlert = alert
    }

    func removeBudget() {
        budgetAlert = nil
    }

    // MARK: - Forecasting

    func generateForecast() {
        guard callRecords.count >= 3 else { return }

        let calendar = Calendar.current
        let now = Date()

        // Group costs by day
        var dailyCosts: [DateComponents: Double] = [:]
        for record in callRecords {
            let components = calendar.dateComponents([.year, .month, .day], from: record.timestamp)
            dailyCosts[components, default: 0] += record.costUSD
        }

        let sortedDays = dailyCosts.sorted { lhs, rhs in
            let lhsDate = calendar.date(from: lhs.key) ?? .distantPast
            let rhsDate = calendar.date(from: rhs.key) ?? .distantPast
            return lhsDate < rhsDate
        }

        let dailyValues = sortedDays.map(\.value)
        guard !dailyValues.isEmpty else { return }

        let dailyAverage = dailyValues.reduce(0, +) / Double(dailyValues.count)

        // Calculate days remaining in month
        let currentDay = calendar.component(.day, from: now)
        let range = calendar.range(of: .day, in: .month, for: now) ?? (1..<31)
        let daysInMonth = range.count
        let daysRemaining = max(1, daysInMonth - currentDay)

        // Current month spend
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let currentMonthSpend = callRecords
            .filter { $0.timestamp >= currentMonthStart }
            .reduce(0.0) { $0 + $1.costUSD }

        let forecastedCost = currentMonthSpend + dailyAverage * Double(daysRemaining)

        // Determine trend from recent daily values
        let trend: UsageForecast.UsageTrend
        if dailyValues.count >= 2 {
            let recentHalf = Array(dailyValues.suffix(dailyValues.count / 2))
            let olderHalf = Array(dailyValues.prefix(dailyValues.count / 2))
            let recentAvg = recentHalf.isEmpty ? 0 : recentHalf.reduce(0, +) / Double(recentHalf.count)
            let olderAvg = olderHalf.isEmpty ? 0 : olderHalf.reduce(0, +) / Double(olderHalf.count)

            if recentAvg > olderAvg * 1.15 {
                trend = .increasing
            } else if recentAvg < olderAvg * 0.85 {
                trend = .decreasing
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }

        // Total tokens forecast
        let totalTokensPerDay = callRecords.reduce(0) { $0 + $1.totalTokens } / max(1, dailyValues.count)
        let forecastedTokens = totalTokensPerDay * daysInMonth

        // Build forecast data points
        var dataPoints: [ForecastDataPoint] = []

        // Historical data points (actual)
        for (components, value) in sortedDays.suffix(14) {
            if let date = calendar.date(from: components) {
                dataPoints.append(ForecastDataPoint(
                    date: date,
                    value: value,
                    lowerBound: value,
                    upperBound: value,
                    isActual: true
                ))
            }
        }

        // Projected data points (forecast)
        let stdDev = standardDeviation(dailyValues)
        for dayOffset in 1...min(daysRemaining, 14) {
            if let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) {
                let uncertaintyFactor = 1.0 + Double(dayOffset) * 0.08
                dataPoints.append(ForecastDataPoint(
                    date: futureDate,
                    value: dailyAverage,
                    lowerBound: max(0, dailyAverage - stdDev * uncertaintyFactor),
                    upperBound: dailyAverage + stdDev * uncertaintyFactor,
                    isActual: false
                ))
            }
        }

        usageForecast = UsageForecast(
            forecastedMonthEndCost: forecastedCost,
            forecastedMonthEndTokens: forecastedTokens,
            dailyAverage: dailyAverage,
            trend: trend,
            dataPoints: dataPoints
        )
    }

    // MARK: - Stats Update

    func updateSummary() {
        guard !callRecords.isEmpty else {
            summary = .empty
            return
        }

        let totalCalls = callRecords.count
        let totalTokens = callRecords.reduce(0) { $0 + $1.totalTokens }
        let totalCostVal = callRecords.reduce(0.0) { $0 + $1.costUSD }
        let averageLatency = callRecords.reduce(0.0) { $0 + $1.latencyMs } / Double(totalCalls)
        let errorCount = callRecords.filter(\.isError).count
        let uniqueModels = Set(callRecords.map(\.model)).count

        let sortedByTime = callRecords.sorted { $0.timestamp < $1.timestamp }
        let periodStart = sortedByTime.first?.timestamp ?? Date()
        let periodEnd = sortedByTime.last?.timestamp ?? Date()

        summary = APIUsageSummary(
            totalCalls: totalCalls,
            totalTokens: totalTokens,
            totalCost: totalCostVal,
            averageLatencyMs: averageLatency,
            errorCount: errorCount,
            uniqueModels: uniqueModels,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }

    func updateModelStats() {
        var groups: [String: [APICallMetrics]] = [:]
        for record in callRecords {
            groups[record.model, default: []].append(record)
        }

        modelStats = groups.map { model, records in
            let totalCalls = records.count
            let totalTokens = records.reduce(0) { $0 + $1.totalTokens }
            let totalCostVal = records.reduce(0.0) { $0 + $1.costUSD }
            let avgLatency = records.reduce(0.0) { $0 + $1.latencyMs } / Double(totalCalls)
            let errors = records.filter(\.isError).count
            let errRate = Double(errors) / Double(totalCalls)
            let lastUsed = records.map(\.timestamp).max()

            var stats = ModelUsageStats(
                modelName: model,
                totalCalls: totalCalls,
                totalTokens: totalTokens,
                totalCost: totalCostVal,
                averageLatencyMs: avgLatency,
                errorRate: errRate
            )
            stats.lastUsedAt = lastUsed
            return stats
        }.sorted { $0.totalCost > $1.totalCost }
    }

    // MARK: - Sample Data

    func loadSampleData() {
        let now = Date()

        // Generate 25 varied API call records over the past 7 days
        let sampleEntries: [(model: String, inputTokens: Int, outputTokens: Int, latencyMs: Double, costUSD: Double, taskType: String, isError: Bool, errorType: String?, hoursAgo: Double)] = [
            // Opus calls - expensive, higher latency
            ("claude-opus-4", 4200, 3800, 4520.0, 0.1840, "code-generation", false, nil, 1.0),
            ("claude-opus-4", 6100, 5200, 6230.0, 0.2650, "refactoring", false, nil, 5.5),
            ("claude-opus-4", 3500, 2900, 3890.0, 0.1520, "debugging", false, nil, 12.0),
            ("claude-opus-4", 8200, 7100, 8450.0, 0.3580, "code-generation", false, nil, 24.0),
            ("claude-opus-4", 5600, 4800, 5670.0, 0.2430, "analysis", false, nil, 36.0),
            ("claude-opus-4", 2800, 2200, 3120.0, 0.1190, "code-review", true, "timeout", 48.0),
            ("claude-opus-4", 7300, 6500, 7890.0, 0.3210, "refactoring", false, nil, 72.0),
            ("claude-opus-4", 4500, 3600, 4780.0, 0.1920, "debugging", false, nil, 96.0),

            // Sonnet calls - mid-range
            ("claude-sonnet-4", 3200, 2800, 1850.0, 0.0420, "code-review", false, nil, 2.0),
            ("claude-sonnet-4", 4800, 4100, 2340.0, 0.0620, "documentation", false, nil, 8.0),
            ("claude-sonnet-4", 2100, 1800, 1420.0, 0.0280, "testing", false, nil, 15.0),
            ("claude-sonnet-4", 5500, 4600, 2890.0, 0.0710, "code-generation", false, nil, 28.0),
            ("claude-sonnet-4", 3800, 3200, 1960.0, 0.0490, "analysis", false, nil, 40.0),
            ("claude-sonnet-4", 2900, 2400, 1680.0, 0.0370, "code-review", false, nil, 56.0),
            ("claude-sonnet-4", 4200, 3500, 2150.0, 0.0540, "refactoring", true, "rate_limit", 80.0),
            ("claude-sonnet-4", 3600, 3000, 1790.0, 0.0460, "debugging", false, nil, 100.0),
            ("claude-sonnet-4", 2500, 2100, 1530.0, 0.0320, "testing", false, nil, 120.0),

            // Haiku calls - cheap, fast
            ("claude-haiku-3.5", 1200, 800, 420.0, 0.0025, "documentation", false, nil, 3.0),
            ("claude-haiku-3.5", 800, 600, 310.0, 0.0018, "testing", false, nil, 10.0),
            ("claude-haiku-3.5", 1500, 1100, 480.0, 0.0032, "code-review", false, nil, 20.0),
            ("claude-haiku-3.5", 600, 400, 250.0, 0.0012, "analysis", false, nil, 35.0),
            ("claude-haiku-3.5", 900, 700, 340.0, 0.0020, "documentation", false, nil, 50.0),
            ("claude-haiku-3.5", 1100, 900, 390.0, 0.0028, "testing", false, nil, 65.0),
            ("claude-haiku-3.5", 700, 500, 280.0, 0.0015, "code-review", true, "invalid_request", 90.0),
            ("claude-haiku-3.5", 1300, 1000, 440.0, 0.0030, "analysis", false, nil, 110.0),
        ]

        var records: [APICallMetrics] = []
        for entry in sampleEntries {
            var record = APICallMetrics(
                model: entry.model,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                latencyMs: entry.latencyMs,
                costUSD: entry.costUSD,
                isError: entry.isError,
                errorType: entry.errorType,
                taskType: entry.taskType
            )
            // Adjust the timestamp by shifting backward from now
            record.timestamp = now.addingTimeInterval(-entry.hoursAgo * 3600)
            records.append(record)
        }

        callRecords = records.sorted { $0.timestamp > $1.timestamp }

        // Generate cost breakdown by model
        generateCostBreakdown(period: "Last 7 Days")

        // Model usage stats - 3 entries (opus, sonnet, haiku)
        let opusRecords = callRecords.filter { $0.model == "claude-opus-4" }
        let sonnetRecords = callRecords.filter { $0.model == "claude-sonnet-4" }
        let haikuRecords = callRecords.filter { $0.model == "claude-haiku-3.5" }

        var opusStats = ModelUsageStats(
            modelName: "claude-opus-4",
            totalCalls: opusRecords.count,
            totalTokens: opusRecords.reduce(0) { $0 + $1.totalTokens },
            totalCost: opusRecords.reduce(0.0) { $0 + $1.costUSD },
            averageLatencyMs: opusRecords.reduce(0.0) { $0 + $1.latencyMs } / Double(opusRecords.count),
            errorRate: Double(opusRecords.filter(\.isError).count) / Double(opusRecords.count)
        )
        opusStats.lastUsedAt = opusRecords.map(\.timestamp).max()

        var sonnetStats = ModelUsageStats(
            modelName: "claude-sonnet-4",
            totalCalls: sonnetRecords.count,
            totalTokens: sonnetRecords.reduce(0) { $0 + $1.totalTokens },
            totalCost: sonnetRecords.reduce(0.0) { $0 + $1.costUSD },
            averageLatencyMs: sonnetRecords.reduce(0.0) { $0 + $1.latencyMs } / Double(sonnetRecords.count),
            errorRate: Double(sonnetRecords.filter(\.isError).count) / Double(sonnetRecords.count)
        )
        sonnetStats.lastUsedAt = sonnetRecords.map(\.timestamp).max()

        var haikuStats = ModelUsageStats(
            modelName: "claude-haiku-3.5",
            totalCalls: haikuRecords.count,
            totalTokens: haikuRecords.reduce(0) { $0 + $1.totalTokens },
            totalCost: haikuRecords.reduce(0.0) { $0 + $1.costUSD },
            averageLatencyMs: haikuRecords.reduce(0.0) { $0 + $1.latencyMs } / Double(haikuRecords.count),
            errorRate: Double(haikuRecords.filter(\.isError).count) / Double(haikuRecords.count)
        )
        haikuStats.lastUsedAt = haikuRecords.map(\.timestamp).max()

        modelStats = [opusStats, sonnetStats, haikuStats]

        // Budget alert: $50/month with ~60% usage ($30 spent)
        var budget = BudgetAlert(monthlyBudget: 50.0, alertThreshold: 0.8)
        budget.currentSpend = 30.0
        budgetAlert = budget

        // Usage forecast: increasing trend, projected ~$45 by month end
        let forecastDataPoints: [ForecastDataPoint] = [
            // Actual data points (past days)
            ForecastDataPoint(date: now.addingTimeInterval(-6 * 86400), value: 3.20, lowerBound: 3.20, upperBound: 3.20, isActual: true),
            ForecastDataPoint(date: now.addingTimeInterval(-5 * 86400), value: 3.80, lowerBound: 3.80, upperBound: 3.80, isActual: true),
            ForecastDataPoint(date: now.addingTimeInterval(-4 * 86400), value: 4.10, lowerBound: 4.10, upperBound: 4.10, isActual: true),
            ForecastDataPoint(date: now.addingTimeInterval(-3 * 86400), value: 4.50, lowerBound: 4.50, upperBound: 4.50, isActual: true),
            ForecastDataPoint(date: now.addingTimeInterval(-2 * 86400), value: 5.20, lowerBound: 5.20, upperBound: 5.20, isActual: true),
            ForecastDataPoint(date: now.addingTimeInterval(-1 * 86400), value: 4.80, lowerBound: 4.80, upperBound: 4.80, isActual: true),
            ForecastDataPoint(date: now, value: 5.40, lowerBound: 5.40, upperBound: 5.40, isActual: true),
            // Forecast data points (future days)
            ForecastDataPoint(date: now.addingTimeInterval(1 * 86400), value: 5.10, lowerBound: 4.20, upperBound: 6.00, isActual: false),
            ForecastDataPoint(date: now.addingTimeInterval(2 * 86400), value: 5.30, lowerBound: 4.10, upperBound: 6.50, isActual: false),
            ForecastDataPoint(date: now.addingTimeInterval(3 * 86400), value: 5.50, lowerBound: 4.00, upperBound: 7.00, isActual: false),
            ForecastDataPoint(date: now.addingTimeInterval(4 * 86400), value: 5.60, lowerBound: 3.80, upperBound: 7.40, isActual: false),
            ForecastDataPoint(date: now.addingTimeInterval(5 * 86400), value: 5.80, lowerBound: 3.60, upperBound: 8.00, isActual: false),
        ]

        usageForecast = UsageForecast(
            forecastedMonthEndCost: 45.0,
            forecastedMonthEndTokens: 850_000,
            dailyAverage: 4.43,
            trend: .increasing,
            dataPoints: forecastDataPoints
        )

        // Update summary
        updateSummary()
    }

    // MARK: - Computed Properties

    var errorRate: Double {
        guard !callRecords.isEmpty else { return 0 }
        return Double(callRecords.filter(\.isError).count) / Double(callRecords.count)
    }

    var avgLatency: Double {
        guard !callRecords.isEmpty else { return 0 }
        return callRecords.reduce(0.0) { $0 + $1.latencyMs } / Double(callRecords.count)
    }

    var totalCost: Double {
        callRecords.reduce(0.0) { $0 + $1.costUSD }
    }

    // MARK: - Private Helpers

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return sqrt(variance)
    }
}
