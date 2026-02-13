import SwiftUI

// MARK: - M3: API Usage Analytics Detail View (Sheet)

struct APIUsageAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var budgetAmount: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#FF9800").opacity(0.3))

            TabView(selection: $selectedTab) {
                overviewTab.tag(0)
                callHistoryTab.tag(1)
                costBreakdownTab.tag(2)
                budgetTab.tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if appState.apiUsageAnalyticsManager.callRecords.isEmpty {
                appState.apiUsageAnalyticsManager.loadSampleData()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(Color(hex: "#FF9800"))
            Text(localization.localized(.auAPIUsageAnalytics))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Toggle(localization.localized(.auTotalCalls), isOn: Binding(
                get: { appState.apiUsageAnalyticsManager.isMonitoring },
                set: { $0 ? appState.apiUsageAnalyticsManager.startMonitoring() : appState.apiUsageAnalyticsManager.stopMonitoring() }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.7))

            Picker("", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Calls").tag(1)
                Text(localization.localized(.auCostAnalysis)).tag(2)
                Text(localization.localized(.auBudget)).tag(3)
            }
            .pickerStyle(.segmented)
            .frame(width: 340)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Summary cards
                HStack(spacing: 12) {
                    summaryCard(localization.localized(.auTotalCalls), value: "\(appState.apiUsageAnalyticsManager.summary.totalCalls)", color: "#FF9800", icon: "arrow.up.arrow.down")
                    summaryCard(localization.localized(.auTotalCost), value: appState.apiUsageAnalyticsManager.summary.formattedCost, color: "#4CAF50", icon: "dollarsign.circle")
                    summaryCard(localization.localized(.auErrorRate), value: "\(appState.apiUsageAnalyticsManager.summary.errorRatePercentage)%", color: appState.apiUsageAnalyticsManager.summary.errorRate > 0.1 ? "#F44336" : "#4CAF50", icon: "exclamationmark.triangle")
                    summaryCard(localization.localized(.auAvgLatency), value: String(format: "%.0fms", appState.apiUsageAnalyticsManager.summary.averageLatencyMs), color: "#2196F3", icon: "clock")
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Model stats
                if !appState.apiUsageAnalyticsManager.modelStats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.auModelBreakdown))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        ForEach(appState.apiUsageAnalyticsManager.modelStats) { stat in
                            modelStatRow(stat)
                        }
                    }
                    .padding(.horizontal)
                }

                // Forecast
                if let forecast = appState.apiUsageAnalyticsManager.usageForecast {
                    forecastSection(forecast)
                } else {
                    HStack {
                        Spacer()
                        Button(localization.localized(.auForecast)) {
                            appState.apiUsageAnalyticsManager.generateForecast()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }

    private func summaryCard(_ title: String, value: String, color: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: color).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func modelStatRow(_ stat: ModelUsageStats) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(modelColor(stat.modelName))
                .frame(width: 8, height: 8)
            Text(stat.modelName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { geo in
                    let maxCalls = appState.apiUsageAnalyticsManager.modelStats.map(\.totalCalls).max() ?? 1
                    RoundedRectangle(cornerRadius: 2)
                        .fill(modelColor(stat.modelName).opacity(0.6))
                        .frame(width: max(4, geo.size.width * CGFloat(stat.totalCalls) / CGFloat(maxCalls)))
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)

            Text("\(stat.totalCalls) calls")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 70, alignment: .trailing)

            Text(stat.formattedCost)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
    }

    private func forecastSection(_ forecast: UsageForecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localization.localized(.auForecast))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: forecast.trend.iconName)
                    .foregroundColor(Color(hex: forecast.trend.colorHex))
                Text(forecast.trend.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: forecast.trend.colorHex))
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("End-of-Month Cost")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "$%.2f", forecast.forecastedMonthEndCost))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF9800"))
                }
                VStack(spacing: 2) {
                    Text("End-of-Month Tokens")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(forecast.forecastedMonthEndTokens)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF9800").opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Call History Tab

    private var callHistoryTab: some View {
        VStack(spacing: 0) {
            if appState.apiUsageAnalyticsManager.callRecords.isEmpty {
                emptyState(localization.localized(.auNoRecords), icon: "arrow.up.arrow.down")
            } else {
                // Header row
                HStack(spacing: 0) {
                    Text("Model").frame(width: 80, alignment: .leading)
                    Text("Tokens").frame(width: 80, alignment: .trailing)
                    Text("Latency").frame(width: 70, alignment: .trailing)
                    Text("Cost").frame(width: 60, alignment: .trailing)
                    Text("Type").frame(width: 80, alignment: .leading)
                    Text("Time").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider().background(Color.white.opacity(0.1))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.apiUsageAnalyticsManager.callRecords) { record in
                            callRecordRow(record)
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
    }

    private func callRecordRow(_ record: APICallMetrics) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle()
                    .fill(modelColor(record.model))
                    .frame(width: 6, height: 6)
                Text(record.model)
                    .lineLimit(1)
            }
            .frame(width: 80, alignment: .leading)

            Text("\(record.totalTokens)")
                .frame(width: 80, alignment: .trailing)

            Text(record.formattedLatency)
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(Color(hex: record.latencyMs > 3000 ? "#F44336" : (record.latencyMs > 2000 ? "#FF9800" : "#4CAF50")))

            Text(record.formattedCost)
                .frame(width: 60, alignment: .trailing)

            HStack(spacing: 4) {
                if record.isError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color(hex: "#F44336"))
                        .font(.system(size: 8))
                }
                Text(record.taskType)
                    .lineLimit(1)
            }
            .frame(width: 80, alignment: .leading)

            Text(record.timestamp, style: .relative)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(record.isError ? .white.opacity(0.5) : .white.opacity(0.7))
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(record.isError ? Color(hex: "#F44336").opacity(0.05) : Color.clear)
    }

    // MARK: - Cost Breakdown Tab

    private var costBreakdownTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(localization.localized(.auCostAnalysis)) {
                    appState.apiUsageAnalyticsManager.generateCostBreakdown(period: "last_7_days")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.apiUsageAnalyticsManager.costBreakdowns.isEmpty {
                emptyState("No cost data", icon: "dollarsign.circle")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.apiUsageAnalyticsManager.costBreakdowns) { breakdown in
                            costBreakdownCard(breakdown)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func costBreakdownCard(_ breakdown: CostBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(breakdown.period)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(breakdown.formattedTotal)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF9800"))
            }

            ForEach(breakdown.entries) { entry in
                HStack {
                    Circle()
                        .fill(modelColor(entry.category))
                        .frame(width: 8, height: 8)
                    Text(entry.category)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(modelColor(entry.category).opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(entry.percentage)))
                    }
                    .frame(height: 8)

                    Text("\(Int(entry.percentage * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 35, alignment: .trailing)

                    Text(String(format: "$%.2f", entry.cost))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 55, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#FF9800").opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Budget Tab

    private var budgetTab: some View {
        VStack(spacing: 12) {
            // Budget setup
            HStack(spacing: 8) {
                TextField(localization.localized(.auSetBudget), text: $budgetAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button(localization.localized(.auSetBudget)) {
                    guard let amount = Double(budgetAmount), amount > 0 else { return }
                    appState.apiUsageAnalyticsManager.setBudget(monthly: amount)
                    budgetAmount = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#FF9800"))
                .disabled(budgetAmount.isEmpty || Double(budgetAmount) == nil)

                Spacer()

                if appState.apiUsageAnalyticsManager.budgetAlert != nil {
                    Button("Remove Budget") {
                        appState.apiUsageAnalyticsManager.removeBudget()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(Color(hex: "#F44336"))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let budget = appState.apiUsageAnalyticsManager.budgetAlert {
                budgetDetailCard(budget)
            } else {
                emptyState("No budget set", icon: "creditcard")
            }

            Spacer()
        }
    }

    private func budgetDetailCard(_ budget: BudgetAlert) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: budget.alertLevel.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: budget.alertLevel.colorHex))
                VStack(alignment: .leading) {
                    Text("Monthly Budget")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "$%.2f", budget.monthlyBudget))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(localization.localized(.auBudgetRemaining))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "$%.2f", budget.remainingBudget))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: budget.alertLevel.colorHex))
                }
            }

            ProgressView(value: budget.spendPercentage)
                .tint(Color(hex: budget.alertLevel.colorHex))

            HStack {
                Text("Spent: \(budget.spendPercentageDisplay)%")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "$%.2f / $%.2f", budget.currentSpend, budget.monthlyBudget))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: budget.alertLevel.colorHex).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func modelColor(_ name: String) -> Color {
        let lowered = name.lowercased()
        if lowered.contains("opus") { return Color(hex: "#9C27B0") }
        if lowered.contains("sonnet") { return Color(hex: "#2196F3") }
        if lowered.contains("haiku") { return Color(hex: "#4CAF50") }
        return Color(hex: "#FF9800")
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
