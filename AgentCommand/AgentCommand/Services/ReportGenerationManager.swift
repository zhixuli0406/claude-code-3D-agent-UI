import Foundation
import Combine

// MARK: - M2: Report Generation Manager

/// Manages report generation, export, scheduling, and format conversion
@MainActor
class ReportGenerationManager: ObservableObject {

    // MARK: - Published State

    @Published var templates: [ReportTemplate] = []
    @Published var schedules: [ReportSchedule] = []
    @Published var exportJobs: [ExportJob] = []
    @Published var isGenerating: Bool = false
    @Published var lastGeneratedReport: ReportData?

    // MARK: - Persistence Keys

    private static let templatesKey = "reportTemplates"
    private static let schedulesKey = "reportSchedules"

    // MARK: - Memory Limits

    static let maxTemplates = 30
    static let maxSchedules = 20
    static let maxExportJobs = 50

    // MARK: - Schedule Timer

    private var scheduleTimer: Timer?

    // MARK: - Initialization

    init() {
        load()
    }

    func initialize() {
        load()
        createDefaultTemplateIfNeeded()
        startScheduleMonitor()
    }

    func shutdown() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        save()
    }

    // MARK: - Template Management

    /// Create a new report template
    func createTemplate(name: String, description: String = "", sections: [ReportSection] = []) -> ReportTemplate {
        let template = ReportTemplate(name: name, description: description, sections: sections)
        templates.append(template)
        enforceTemplateLimit()
        save()
        return template
    }

    /// Delete a template by ID
    func deleteTemplate(id: String) {
        templates.removeAll { $0.id == id }
        // Remove associated schedules
        schedules.removeAll { $0.templateId == id }
        save()
    }

    /// Update template sections
    func updateTemplateSections(templateId: String, sections: [ReportSection]) {
        guard let index = templates.firstIndex(where: { $0.id == templateId }) else { return }
        templates[index].sections = sections
        save()
    }

    // MARK: - Report Generation

    /// Generate a report from a template with the given data
    func generateReport(template: ReportTemplate, summary: ReportSummary, tokenUsageData: [AnalyticsDataPoint] = [], costData: [AnalyticsDataPoint] = [], taskMetrics: ReportTaskMetrics, errorMetrics: ReportErrorMetrics) -> ReportData {
        isGenerating = true
        defer { isGenerating = false }

        let report = ReportData(
            title: template.name,
            timeRange: summary.periodDescription,
            summary: summary,
            tokenUsageData: tokenUsageData,
            costData: costData,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )

        lastGeneratedReport = report
        return report
    }

    // MARK: - Export

    /// Export report data to the specified format
    func exportReport(_ report: ReportData, format: ExportFormat) -> ExportJob {
        var job = ExportJob(format: format)
        job.status = .inProgress
        exportJobs.append(job)
        enforceExportJobLimit()

        let jobIndex = exportJobs.count - 1

        // Generate the export content
        let content: String
        switch format {
        case .json:
            content = generateJSON(from: report)
        case .csv:
            content = generateCSV(from: report)
        case .markdown:
            content = generateMarkdown(from: report)
        case .pdf:
            content = generateMarkdown(from: report) // PDF uses markdown as intermediate
        }

        // Write to temp file
        let fileName = "\(report.title.replacingOccurrences(of: " ", with: "_"))_\(dateFormatter.string(from: report.generatedAt)).\(format.fileExtension)"
        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent(fileName)

        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
            let fileSize = try FileManager.default.attributesOfItem(atPath: filePath.path)[.size] as? Int64

            exportJobs[jobIndex].status = .completed
            exportJobs[jobIndex].progress = 1.0
            exportJobs[jobIndex].outputPath = filePath.path
            exportJobs[jobIndex].fileSize = fileSize
            exportJobs[jobIndex].completedAt = Date()
        } catch {
            exportJobs[jobIndex].status = .failed
            exportJobs[jobIndex].errorMessage = error.localizedDescription
        }

        return exportJobs[jobIndex]
    }

    // MARK: - Format Converters

    /// Generate JSON string from report data
    func generateJSON(from report: ReportData) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(report),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    /// Generate CSV string from report data
    func generateCSV(from report: ReportData) -> String {
        var lines: [String] = []

        // Summary section
        lines.append("Section,Metric,Value")
        lines.append("Summary,Total Tokens,\(report.summary.totalTokens)")
        lines.append("Summary,Total Cost,\(String(format: "%.4f", report.summary.totalCost))")
        lines.append("Summary,Total Tasks,\(report.summary.totalTasks)")
        lines.append("Summary,Success Rate,\(String(format: "%.2f", report.summary.successRate))")
        lines.append("Summary,Average Latency (ms),\(String(format: "%.1f", report.summary.averageLatency))")
        lines.append("")

        // Task metrics
        lines.append("Task Metrics,Completed,\(report.taskMetrics.completed)")
        lines.append("Task Metrics,Failed,\(report.taskMetrics.failed)")
        lines.append("Task Metrics,Cancelled,\(report.taskMetrics.cancelled)")
        lines.append("Task Metrics,Average Duration (s),\(String(format: "%.1f", report.taskMetrics.averageDuration))")
        lines.append("")

        // Error metrics
        lines.append("Error Metrics,Total Errors,\(report.errorMetrics.totalErrors)")
        lines.append("Error Metrics,Recovery Rate,\(String(format: "%.2f", report.errorMetrics.recoveryRate))")
        if let commonError = report.errorMetrics.mostCommonError {
            lines.append("Error Metrics,Most Common Error,\(csvEscape(commonError))")
        }
        lines.append("")

        // Token usage time series
        if !report.tokenUsageData.isEmpty {
            lines.append("Date,Token Usage")
            for point in report.tokenUsageData {
                lines.append("\(isoDateFormatter.string(from: point.timestamp)),\(String(format: "%.0f", point.value))")
            }
            lines.append("")
        }

        // Cost time series
        if !report.costData.isEmpty {
            lines.append("Date,Cost (USD)")
            for point in report.costData {
                lines.append("\(isoDateFormatter.string(from: point.timestamp)),\(String(format: "%.4f", point.value))")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Generate Markdown string from report data
    func generateMarkdown(from report: ReportData) -> String {
        var md = ""

        md += "# \(report.title)\n\n"
        md += "**Generated:** \(dateFormatter.string(from: report.generatedAt))\n"
        md += "**Period:** \(report.timeRange)\n\n"
        md += "---\n\n"

        // Executive Summary
        md += "## Executive Summary\n\n"
        md += "| Metric | Value |\n"
        md += "|--------|-------|\n"
        md += "| Total Tokens | \(formatNumber(report.summary.totalTokens)) |\n"
        md += "| Total Cost | \(report.summary.formattedCost) |\n"
        md += "| Total Tasks | \(report.summary.totalTasks) |\n"
        md += "| Success Rate | \(report.summary.successRatePercentage)% |\n"
        md += "| Avg Latency | \(String(format: "%.0f", report.summary.averageLatency))ms |\n\n"

        // Task Metrics
        md += "## Task Metrics\n\n"
        md += "| Status | Count |\n"
        md += "|--------|-------|\n"
        md += "| Completed | \(report.taskMetrics.completed) |\n"
        md += "| Failed | \(report.taskMetrics.failed) |\n"
        md += "| Cancelled | \(report.taskMetrics.cancelled) |\n"
        md += "| **Total** | **\(report.taskMetrics.total)** |\n\n"

        // Error Analysis
        md += "## Error Analysis\n\n"
        md += "- **Total Errors:** \(report.errorMetrics.totalErrors)\n"
        md += "- **Recovery Rate:** \(report.errorMetrics.recoveryPercentage)%\n"
        if let commonError = report.errorMetrics.mostCommonError {
            md += "- **Most Common:** \(commonError)\n"
        }
        md += "\n"

        if !report.errorMetrics.errorsByType.isEmpty {
            md += "| Error Type | Count |\n"
            md += "|------------|-------|\n"
            for (errorType, count) in report.errorMetrics.errorsByType.sorted(by: { $0.value > $1.value }) {
                md += "| \(errorType) | \(count) |\n"
            }
            md += "\n"
        }

        return md
    }

    // MARK: - Schedule Management

    /// Create a new report schedule
    func createSchedule(name: String, templateId: String, frequency: ReportSchedule.ScheduleFrequency, exportFormat: ExportFormat) -> ReportSchedule {
        let schedule = ReportSchedule(name: name, templateId: templateId, frequency: frequency, exportFormat: exportFormat)
        schedules.append(schedule)
        enforceScheduleLimit()
        save()
        return schedule
    }

    /// Toggle a schedule on/off
    func toggleSchedule(id: String) {
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[index].isActive.toggle()
        save()
    }

    /// Delete a schedule
    func deleteSchedule(id: String) {
        schedules.removeAll { $0.id == id }
        save()
    }

    /// Check and run due schedules
    func checkSchedules() {
        let now = Date()
        for index in schedules.indices {
            guard schedules[index].isActive,
                  let nextRun = schedules[index].nextRunAt,
                  nextRun <= now else { continue }

            // Mark as run
            schedules[index].lastRunAt = now
            schedules[index].nextRunAt = schedules[index].frequency.nextOccurrence(from: now)
        }
        save()
    }

    // MARK: - Private Helpers

    private func startScheduleMonitor() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSchedules()
            }
        }
    }

    private func createDefaultTemplateIfNeeded() {
        guard templates.isEmpty else { return }
        _ = createTemplate(
            name: "Standard Performance Report",
            description: "Comprehensive performance overview",
            sections: ReportSection.SectionType.allCases.map {
                ReportSection(type: $0, isEnabled: true)
            }
        )
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private var isoDateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: Self.templatesKey)
        }
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: Self.schedulesKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.templatesKey),
           let decoded = try? JSONDecoder().decode([ReportTemplate].self, from: data) {
            templates = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.schedulesKey),
           let decoded = try? JSONDecoder().decode([ReportSchedule].self, from: data) {
            schedules = decoded
        }
    }

    // MARK: - Memory Limits

    private func enforceTemplateLimit() {
        if templates.count > Self.maxTemplates {
            templates = Array(templates.suffix(Self.maxTemplates))
        }
    }

    private func enforceScheduleLimit() {
        if schedules.count > Self.maxSchedules {
            schedules = Array(schedules.suffix(Self.maxSchedules))
        }
    }

    private func enforceExportJobLimit() {
        if exportJobs.count > Self.maxExportJobs {
            exportJobs = Array(exportJobs.suffix(Self.maxExportJobs))
        }
    }
}
