import Foundation
import Combine

// MARK: - M2: Export & Reporting Manager

/// Manages report export jobs, templates, schedules, and report data generation
@MainActor
class ReportExportManager: ObservableObject {

    // MARK: - Published State

    @Published var templates: [ReportTemplate] = []
    @Published var schedules: [ReportSchedule] = []
    @Published var exportJobs: [ExportJob] = []
    @Published var generatedReports: [ReportData] = []
    @Published var isExporting: Bool = false

    // MARK: - Memory Limits

    private static let maxJobs = 50
    private static let maxReports = 20

    // MARK: - Dependencies

    weak var appState: AppState?
    private var scheduleTimer: Timer?

    deinit {
        scheduleTimer?.invalidate()
    }

    // MARK: - Template Management

    /// Create a new report template
    func createTemplate(name: String, description: String, sections: [ReportSection]) {
        let template = ReportTemplate(
            name: name,
            description: description,
            sections: sections,
            includeCharts: true,
            includeSummary: true
        )
        templates.append(template)
    }

    /// Delete a template by ID
    func deleteTemplate(_ templateId: String) {
        templates.removeAll { $0.id == templateId }
    }

    // MARK: - Schedule Management

    /// Create a new report schedule
    func createSchedule(name: String, templateId: String, frequency: ReportSchedule.ScheduleFrequency, format: ExportFormat) {
        let schedule = ReportSchedule(
            name: name,
            templateId: templateId,
            frequency: frequency,
            exportFormat: format
        )
        schedules.append(schedule)
    }

    /// Toggle a schedule's active state
    func toggleSchedule(_ scheduleId: String) {
        guard let index = schedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        schedules[index].isActive.toggle()
    }

    /// Delete a schedule by ID
    func deleteSchedule(_ scheduleId: String) {
        schedules.removeAll { $0.id == scheduleId }
    }

    /// Start monitoring schedules for auto-generation
    func startScheduleMonitoring() {
        scheduleTimer?.invalidate()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkScheduledReports()
            }
        }
    }

    /// Stop monitoring schedules
    func stopScheduleMonitoring() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
    }

    /// Check if any scheduled reports are due and trigger export
    private func checkScheduledReports() {
        let now = Date()
        for i in schedules.indices {
            guard schedules[i].isActive,
                  let nextRun = schedules[i].nextRunAt,
                  nextRun <= now else { continue }

            // Trigger export for this schedule
            exportReport(format: schedules[i].exportFormat, templateId: schedules[i].templateId)

            // Update schedule timestamps
            schedules[i].lastRunAt = now
            schedules[i].nextRunAt = schedules[i].frequency.nextOccurrence(from: now)
        }
    }

    // MARK: - Export Operations

    /// Start an export job, simulating progress and generating report data on completion
    func exportReport(format: ExportFormat, templateId: String?) {
        guard !isExporting else { return }
        isExporting = true

        var job = ExportJob(format: format, templateId: templateId)
        job.status = .inProgress
        exportJobs.append(job)
        enforceJobLimit()

        let jobId = job.id

        // Simulate export progress
        Task { [weak self] in
            guard let self = self else { return }

            let steps = 5
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s per step
                guard let index = self.exportJobs.firstIndex(where: { $0.id == jobId }) else { return }
                // Check if cancelled
                if self.exportJobs[index].status == .failed {
                    self.isExporting = false
                    return
                }
                self.exportJobs[index].progress = Double(step) / Double(steps)
            }

            guard let index = self.exportJobs.firstIndex(where: { $0.id == jobId }) else {
                self.isExporting = false
                return
            }

            // Generate report data
            let templateName = templateId.flatMap { tid in
                self.templates.first(where: { $0.id == tid })?.name
            } ?? "Report"
            let report = self.generateReportData(
                title: "\(templateName) - \(format.displayName)",
                timeRange: "Last 7 Days"
            )
            self.generatedReports.append(report)
            self.enforceReportLimit()

            // Finalize job
            self.exportJobs[index].status = .completed
            self.exportJobs[index].progress = 1.0
            self.exportJobs[index].completedAt = Date()
            self.exportJobs[index].outputPath = "~/Reports/\(report.title).\(format.fileExtension)"
            self.exportJobs[index].fileSize = Int64.random(in: 1024...524_288)

            self.isExporting = false
        }
    }

    /// Cancel an in-progress export job
    func cancelExport(_ jobId: String) {
        guard let index = exportJobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard exportJobs[index].status == .pending || exportJobs[index].status == .inProgress else { return }
        exportJobs[index].status = .failed
        exportJobs[index].errorMessage = "Export cancelled by user"
        exportJobs[index].completedAt = Date()
        isExporting = false
    }

    /// Delete an export job from history
    func deleteExportJob(_ jobId: String) {
        exportJobs.removeAll { $0.id == jobId }
    }

    // MARK: - Report Generation

    /// Generate a ReportData instance with realistic sample metrics
    func generateReportData(title: String, timeRange: String) -> ReportData {
        let totalTokens = Int.random(in: 50_000...500_000)
        let totalCost = Double(totalTokens) * 0.000003
        let completedTasks = Int.random(in: 80...200)
        let failedTasks = Int.random(in: 2...15)
        let cancelledTasks = Int.random(in: 0...5)
        let totalTasks = completedTasks + failedTasks + cancelledTasks
        let successRate = Double(completedTasks) / Double(totalTasks)

        let summary = ReportSummary(
            totalTokens: totalTokens,
            totalCost: totalCost,
            totalTasks: totalTasks,
            successRate: successRate,
            averageLatency: Double.random(in: 200...1500),
            periodDescription: timeRange
        )

        let taskMetrics = ReportTaskMetrics(
            completed: completedTasks,
            failed: failedTasks,
            cancelled: cancelledTasks,
            averageDuration: Double.random(in: 30...300)
        )

        let errorMetrics = ReportErrorMetrics(
            totalErrors: failedTasks + Int.random(in: 0...10),
            errorsByType: [
                "Timeout": Int.random(in: 1...5),
                "RateLimit": Int.random(in: 0...3),
                "ParseError": Int.random(in: 0...4),
                "NetworkError": Int.random(in: 0...2)
            ],
            recoveryRate: Double.random(in: 0.5...0.95),
            mostCommonError: "Timeout"
        )

        // Generate token usage data points over 7 days
        let calendar = Calendar.current
        let now = Date()
        let tokenUsageData: [AnalyticsDataPoint] = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            return AnalyticsDataPoint(
                timestamp: date,
                value: Double.random(in: 5000...80000),
                label: "Day \(7 - dayOffset)"
            )
        }.reversed()

        // Generate cost data points over 7 days
        let costData: [AnalyticsDataPoint] = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            return AnalyticsDataPoint(
                timestamp: date,
                value: Double.random(in: 0.05...2.50),
                label: "Day \(7 - dayOffset)"
            )
        }.reversed()

        return ReportData(
            title: title,
            timeRange: timeRange,
            summary: summary,
            tokenUsageData: Array(tokenUsageData),
            costData: Array(costData),
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )
    }

    // MARK: - Sample Data

    func loadSampleData() {
        // Default template + 1 custom template
        let defaultTemplate = ReportTemplate.defaultTemplate
        templates = [
            defaultTemplate,
            ReportTemplate(
                name: "Cost Analysis Report",
                description: "Focused report on token costs and optimization opportunities",
                sections: [
                    ReportSection(type: .executiveSummary, isEnabled: true, sortOrder: 0),
                    ReportSection(type: .costAnalysis, isEnabled: true, sortOrder: 1),
                    ReportSection(type: .tokenUsage, isEnabled: true, sortOrder: 2),
                    ReportSection(type: .performanceTrends, isEnabled: true, sortOrder: 3)
                ],
                includeCharts: true,
                includeSummary: true
            )
        ]

        // 2 schedules: one daily active, one weekly inactive
        var dailySchedule = ReportSchedule(
            name: "Daily Performance Summary",
            templateId: defaultTemplate.id,
            frequency: .daily,
            exportFormat: .json
        )
        dailySchedule.isActive = true
        dailySchedule.lastRunAt = Date().addingTimeInterval(-86400)

        var weeklySchedule = ReportSchedule(
            name: "Weekly Cost Report",
            templateId: templates[1].id,
            frequency: .weekly,
            exportFormat: .csv
        )
        weeklySchedule.isActive = false

        schedules = [dailySchedule, weeklySchedule]

        // 3 export jobs: completed, in progress, failed
        var completedJob = ExportJob(format: .json, templateId: defaultTemplate.id)
        completedJob.status = .completed
        completedJob.progress = 1.0
        completedJob.outputPath = "~/Reports/Default Report - JSON.json"
        completedJob.fileSize = 245_760
        completedJob.completedAt = Date().addingTimeInterval(-3600)

        var inProgressJob = ExportJob(format: .pdf, templateId: templates[1].id)
        inProgressJob.status = .inProgress
        inProgressJob.progress = 0.6

        var failedJob = ExportJob(format: .csv)
        failedJob.status = .failed
        failedJob.progress = 0.3
        failedJob.errorMessage = "Insufficient data for the requested time range"
        failedJob.completedAt = Date().addingTimeInterval(-7200)

        exportJobs = [completedJob, inProgressJob, failedJob]

        // 1 generated report with sample data
        let report = generateReportData(
            title: "Weekly Performance Report",
            timeRange: "Last 7 Days"
        )
        generatedReports = [report]
    }

    // MARK: - Computed Properties

    /// All export jobs that have completed successfully
    var completedExports: [ExportJob] {
        exportJobs.filter { $0.status == .completed }
    }

    /// Number of schedules that are currently active
    var activeScheduleCount: Int {
        schedules.filter(\.isActive).count
    }

    // MARK: - Memory Limits

    private func enforceJobLimit() {
        if exportJobs.count > Self.maxJobs {
            exportJobs = Array(exportJobs.suffix(Self.maxJobs))
        }
    }

    private func enforceReportLimit() {
        if generatedReports.count > Self.maxReports {
            generatedReports = Array(generatedReports.suffix(Self.maxReports))
        }
    }
}
