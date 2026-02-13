import SwiftUI

// MARK: - M1: Analytics Dashboard Detail View (Sheet)

struct AnalyticsDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var newReportName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#00BCD4").opacity(0.3))

            TabView(selection: $selectedTab) {
                reportsTab.tag(0)
                forecastsTab.tag(1)
                optimizationsTab.tag(2)
                benchmarksTab.tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if appState.analyticsDashboardManager.reports.isEmpty {
                appState.analyticsDashboardManager.loadSampleData()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.adAnalyticsDashboard))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.adReports)).tag(0)
                Text(localization.localized(.adForecasts)).tag(1)
                Text(localization.localized(.adOptimizations)).tag(2)
                Text(localization.localized(.adBenchmarks)).tag(3)
            }
            .pickerStyle(.segmented)
            .frame(width: 380)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Reports Tab

    private var reportsTab: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField(localization.localized(.adCreateReport), text: $newReportName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Button(localization.localized(.adCreateReport)) {
                    guard !newReportName.isEmpty else { return }
                    appState.analyticsDashboardManager.createReport(name: newReportName)
                    newReportName = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#00BCD4"))
                .disabled(newReportName.isEmpty)

                Spacer()

                savingsLabel
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.analyticsDashboardManager.reports.isEmpty {
                emptyState(localization.localized(.adNoReports), icon: "chart.bar.xaxis")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.analyticsDashboardManager.reports) { report in
                            reportCard(report)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func reportCard(_ report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(report.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                if report.isDefault {
                    Text("Default")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#00BCD4"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#00BCD4").opacity(0.15))
                        .cornerRadius(4)
                }
                Spacer()
                Text(report.createdAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Button(action: { appState.analyticsDashboardManager.deleteReport(report.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.borderless)
            }

            if !report.description.isEmpty {
                Text(report.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                Label("\(report.widgets.count) widgets", systemImage: "square.grid.2x2")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Text("Updated: \(report.updatedAt, style: .relative)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#00BCD4").opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var savingsLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#4CAF50"))
            Text(localization.localized(.adPotentialSavings))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
            Text(String(format: "$%.2f", appState.analyticsDashboardManager.totalPotentialSavings))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#4CAF50"))
        }
    }

    // MARK: - Forecasts Tab

    private var forecastsTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(localization.localized(.adGenerateForecast)) {
                    appState.analyticsDashboardManager.generateForecast(for: .cost)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.analyticsDashboardManager.forecasts.isEmpty {
                emptyState(localization.localized(.adNoForecasts), icon: "chart.line.uptrend.xyaxis")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.analyticsDashboardManager.forecasts) { forecast in
                            forecastCard(forecast)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func forecastCard(_ forecast: TrendForecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(forecast.metric.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Confidence: \(Int(forecast.confidence * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: forecast.confidence > 0.7 ? "#4CAF50" : "#FF9800"))
            }

            // Mini chart representation
            HStack(spacing: 2) {
                ForEach(forecast.dataPoints.suffix(14)) { point in
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: point.isActual ? "#00BCD4" : "#00BCD4").opacity(point.isActual ? 0.8 : 0.4))
                            .frame(width: 12, height: max(4, CGFloat(point.value / (forecast.dataPoints.map(\.value).max() ?? 1)) * 40))
                    }
                    .frame(height: 45)
                }
            }

            HStack {
                Text("\(forecast.dataPoints.count) data points")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(forecast.generatedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Optimizations Tab

    private var optimizationsTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(localization.localized(.adAnalyzeOptimizations)) {
                    appState.analyticsDashboardManager.analyzeOptimizations()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.analyticsDashboardManager.optimizations.isEmpty {
                emptyState(localization.localized(.adNoOptimizations), icon: "lightbulb")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.analyticsDashboardManager.optimizations) { tip in
                            optimizationCard(tip)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func optimizationCard(_ tip: CostOptimizationTip) -> some View {
        HStack(spacing: 8) {
            Image(systemName: tip.category.iconName)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: tip.impact.colorHex))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tip.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    if tip.isApplied {
                        Text(localization.localized(.adAppliedSavings))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "#4CAF50"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#4CAF50").opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Text(tip.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(tip.formattedSavings)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))

                if !tip.isApplied {
                    Button("Apply") {
                        appState.analyticsDashboardManager.applyOptimization(tip.id)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#00BCD4"))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(tip.isApplied ? 0.02 : 0.05))
        )
        .opacity(tip.isApplied ? 0.6 : 1.0)
    }

    // MARK: - Benchmarks Tab

    private var benchmarksTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Menu("Generate Benchmark") {
                    ForEach(BenchmarkMetric.allCases, id: \.self) { metric in
                        Button(metric.displayName) {
                            appState.analyticsDashboardManager.generateBenchmark(metric: metric)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 180)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.analyticsDashboardManager.benchmarks.isEmpty {
                emptyState("No benchmarks generated", icon: "speedometer")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.analyticsDashboardManager.benchmarks) { benchmark in
                            benchmarkCard(benchmark)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func benchmarkCard(_ benchmark: PerformanceBenchmark) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(benchmark.metric.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(benchmark.generatedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            ForEach(benchmark.entries) { entry in
                HStack {
                    Text(entry.label)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#00BCD4").opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(entry.score)), height: 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 120, height: 8)

                    Text(String(format: "%.1f", entry.score * 100))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Empty State

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
