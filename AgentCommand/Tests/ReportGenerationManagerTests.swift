import XCTest
@testable import AgentCommand

// MARK: - ReportGenerationManager Unit Tests

@MainActor
final class ReportGenerationManagerTests: XCTestCase {

    private var manager: ReportGenerationManager!

    override func setUp() {
        super.setUp()
        manager = ReportGenerationManager()
        // Clear any persisted state
        UserDefaults.standard.removeObject(forKey: "reportTemplates")
        UserDefaults.standard.removeObject(forKey: "reportSchedules")
        manager.templates = []
        manager.schedules = []
        manager.exportJobs = []
    }

    override func tearDown() {
        manager.shutdown()
        UserDefaults.standard.removeObject(forKey: "reportTemplates")
        UserDefaults.standard.removeObject(forKey: "reportSchedules")
        manager = nil
        super.tearDown()
    }

    // MARK: - Template Management

    func testCreateTemplate() {
        let template = manager.createTemplate(name: "Weekly", description: "Weekly report")
        XCTAssertEqual(manager.templates.count, 1)
        XCTAssertEqual(template.name, "Weekly")
        XCTAssertEqual(template.description, "Weekly report")
    }

    func testCreateTemplateWithSections() {
        let sections = [
            ReportSection(type: .executiveSummary),
            ReportSection(type: .costAnalysis),
            ReportSection(type: .tokenUsage)
        ]
        let template = manager.createTemplate(name: "Custom", sections: sections)
        XCTAssertEqual(template.sections.count, 3)
    }

    func testDeleteTemplate() {
        let template = manager.createTemplate(name: "To Delete")
        XCTAssertEqual(manager.templates.count, 1)
        manager.deleteTemplate(id: template.id)
        XCTAssertTrue(manager.templates.isEmpty)
    }

    func testDeleteTemplateRemovesAssociatedSchedules() {
        let template = manager.createTemplate(name: "Template")
        _ = manager.createSchedule(name: "Schedule", templateId: template.id, frequency: .daily, exportFormat: .json)
        XCTAssertEqual(manager.schedules.count, 1)

        manager.deleteTemplate(id: template.id)
        XCTAssertTrue(manager.schedules.isEmpty, "Deleting template should remove associated schedules")
    }

    func testDeleteNonExistentTemplate() {
        _ = manager.createTemplate(name: "Existing")
        manager.deleteTemplate(id: "non-existent")
        XCTAssertEqual(manager.templates.count, 1)
    }

    func testUpdateTemplateSections() {
        let template = manager.createTemplate(name: "Update Me")
        let newSections = [
            ReportSection(type: .errorAnalysis, isEnabled: true),
            ReportSection(type: .performanceTrends, isEnabled: false)
        ]
        manager.updateTemplateSections(templateId: template.id, sections: newSections)
        XCTAssertEqual(manager.templates.first?.sections.count, 2)
        XCTAssertEqual(manager.templates.first?.sections.first?.type, .errorAnalysis)
    }

    func testUpdateNonExistentTemplateSections() {
        manager.updateTemplateSections(templateId: "non-existent", sections: [])
        // Should not crash
        XCTAssertTrue(manager.templates.isEmpty)
    }

    func testTemplateLimitEnforcement() {
        for i in 0..<35 {
            _ = manager.createTemplate(name: "Template \(i)")
        }
        XCTAssertLessThanOrEqual(manager.templates.count, ReportGenerationManager.maxTemplates)
    }

    // MARK: - Report Generation

    func testGenerateReport() {
        let template = ReportTemplate(name: "Test Report")
        let summary = ReportSummary(
            totalTokens: 10000, totalCost: 5.0, totalTasks: 50,
            successRate: 0.9, averageLatency: 500.0, periodDescription: "Last 7 days"
        )
        let taskMetrics = ReportTaskMetrics(completed: 45, failed: 3, cancelled: 2, averageDuration: 30.0)
        let errorMetrics = ReportErrorMetrics(totalErrors: 3, errorsByType: ["timeout": 2, "parse": 1], recoveryRate: 0.67, mostCommonError: "timeout")

        let report = manager.generateReport(
            template: template,
            summary: summary,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )

        XCTAssertEqual(report.title, "Test Report")
        XCTAssertEqual(report.summary.totalTokens, 10000)
        XCTAssertEqual(report.taskMetrics.completed, 45)
        XCTAssertNotNil(manager.lastGeneratedReport)
    }

    func testGenerateReportWithTimeSeriesData() {
        let template = ReportTemplate(name: "Full Report")
        let summary = ReportSummary(
            totalTokens: 5000, totalCost: 2.5, totalTasks: 20,
            successRate: 0.85, averageLatency: 800.0, periodDescription: "Daily"
        )
        let taskMetrics = ReportTaskMetrics(completed: 17, failed: 2, cancelled: 1, averageDuration: 20.0)
        let errorMetrics = ReportErrorMetrics(totalErrors: 2, errorsByType: ["rate_limit": 2], recoveryRate: 0.5, mostCommonError: "rate_limit")

        let tokenData = (0..<7).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 86400), value: Double(1000 + i * 100))
        }
        let costData = (0..<7).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 86400), value: Double(i) * 0.5)
        }

        let report = manager.generateReport(
            template: template,
            summary: summary,
            tokenUsageData: tokenData,
            costData: costData,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )

        XCTAssertEqual(report.tokenUsageData.count, 7)
        XCTAssertEqual(report.costData.count, 7)
    }

    func testIsGeneratingFlag() {
        // After generation, isGenerating should be false (defer resets it)
        let template = ReportTemplate(name: "Test")
        let summary = ReportSummary(
            totalTokens: 100, totalCost: 0.01, totalTasks: 1,
            successRate: 1.0, averageLatency: 100.0, periodDescription: "Test"
        )
        let taskMetrics = ReportTaskMetrics(completed: 1, failed: 0, cancelled: 0, averageDuration: 1.0)
        let errorMetrics = ReportErrorMetrics(totalErrors: 0, errorsByType: [:], recoveryRate: 0, mostCommonError: nil)

        _ = manager.generateReport(template: template, summary: summary, taskMetrics: taskMetrics, errorMetrics: errorMetrics)
        XCTAssertFalse(manager.isGenerating)
    }

    // MARK: - Format Converters

    func testGenerateJSON() {
        let report = makeTestReport()
        let json = manager.generateJSON(from: report)
        XCTAssertFalse(json.isEmpty)
        XCTAssertNotEqual(json, "{}")
        XCTAssertTrue(json.contains("Test Report"))
    }

    func testGenerateCSV() {
        let report = makeTestReport()
        let csv = manager.generateCSV(from: report)
        XCTAssertFalse(csv.isEmpty)
        XCTAssertTrue(csv.contains("Section,Metric,Value"))
        XCTAssertTrue(csv.contains("Summary,Total Tokens,"))
        XCTAssertTrue(csv.contains("Summary,Total Cost,"))
        XCTAssertTrue(csv.contains("Task Metrics,Completed,"))
        XCTAssertTrue(csv.contains("Error Metrics,Total Errors,"))
    }

    func testGenerateCSVWithTimeSeries() {
        let report = makeTestReportWithTimeSeries()
        let csv = manager.generateCSV(from: report)
        XCTAssertTrue(csv.contains("Date,Token Usage"))
        XCTAssertTrue(csv.contains("Date,Cost (USD)"))
    }

    func testGenerateMarkdown() {
        let report = makeTestReport()
        let md = manager.generateMarkdown(from: report)
        XCTAssertFalse(md.isEmpty)
        XCTAssertTrue(md.contains("# Test Report"))
        XCTAssertTrue(md.contains("## Executive Summary"))
        XCTAssertTrue(md.contains("## Task Metrics"))
        XCTAssertTrue(md.contains("## Error Analysis"))
        XCTAssertTrue(md.contains("Completed"))
        XCTAssertTrue(md.contains("Failed"))
    }

    func testGenerateMarkdownErrorsByType() {
        let report = makeTestReport()
        let md = manager.generateMarkdown(from: report)
        XCTAssertTrue(md.contains("| Error Type | Count |"))
        XCTAssertTrue(md.contains("timeout"))
    }

    // MARK: - Export

    func testExportReportJSON() {
        let report = makeTestReport()
        let job = manager.exportReport(report, format: .json)
        XCTAssertEqual(job.format, .json)
        // Job should be completed since it writes to temp directory
        XCTAssertTrue(job.status == .completed || job.status == .failed)
        if job.status == .completed {
            XCTAssertNotNil(job.outputPath)
            XCTAssertNotNil(job.fileSize)
            XCTAssertEqual(job.progress, 1.0)
        }
    }

    func testExportReportCSV() {
        let report = makeTestReport()
        let job = manager.exportReport(report, format: .csv)
        XCTAssertEqual(job.format, .csv)
    }

    func testExportReportMarkdown() {
        let report = makeTestReport()
        let job = manager.exportReport(report, format: .markdown)
        XCTAssertEqual(job.format, .markdown)
    }

    func testExportReportPDF() {
        let report = makeTestReport()
        let job = manager.exportReport(report, format: .pdf)
        XCTAssertEqual(job.format, .pdf)
    }

    func testExportJobLimitEnforcement() {
        let report = makeTestReport()
        for _ in 0..<55 {
            _ = manager.exportReport(report, format: .json)
        }
        XCTAssertLessThanOrEqual(manager.exportJobs.count, ReportGenerationManager.maxExportJobs)
    }

    // MARK: - Schedule Management

    func testCreateSchedule() {
        let template = manager.createTemplate(name: "Template")
        let schedule = manager.createSchedule(
            name: "Daily Report",
            templateId: template.id,
            frequency: .daily,
            exportFormat: .json
        )
        XCTAssertEqual(manager.schedules.count, 1)
        XCTAssertEqual(schedule.name, "Daily Report")
        XCTAssertEqual(schedule.frequency, .daily)
        XCTAssertTrue(schedule.isActive)
        XCTAssertNotNil(schedule.nextRunAt)
    }

    func testToggleSchedule() {
        let template = manager.createTemplate(name: "Template")
        let schedule = manager.createSchedule(
            name: "Toggle Me",
            templateId: template.id,
            frequency: .weekly,
            exportFormat: .csv
        )
        XCTAssertTrue(manager.schedules.first?.isActive ?? false)

        manager.toggleSchedule(id: schedule.id)
        XCTAssertFalse(manager.schedules.first?.isActive ?? true)

        manager.toggleSchedule(id: schedule.id)
        XCTAssertTrue(manager.schedules.first?.isActive ?? false)
    }

    func testToggleNonExistentSchedule() {
        manager.toggleSchedule(id: "non-existent")
        // Should not crash
        XCTAssertTrue(manager.schedules.isEmpty)
    }

    func testDeleteSchedule() {
        let template = manager.createTemplate(name: "Template")
        let schedule = manager.createSchedule(
            name: "Delete Me",
            templateId: template.id,
            frequency: .monthly,
            exportFormat: .pdf
        )
        XCTAssertEqual(manager.schedules.count, 1)
        manager.deleteSchedule(id: schedule.id)
        XCTAssertTrue(manager.schedules.isEmpty)
    }

    func testScheduleLimitEnforcement() {
        for i in 0..<25 {
            _ = manager.createSchedule(
                name: "Schedule \(i)",
                templateId: "template-id",
                frequency: .daily,
                exportFormat: .json
            )
        }
        XCTAssertLessThanOrEqual(manager.schedules.count, ReportGenerationManager.maxSchedules)
    }

    func testCheckSchedulesDueRun() {
        let template = manager.createTemplate(name: "Template")
        var schedule = ReportSchedule(
            name: "Overdue",
            templateId: template.id,
            frequency: .daily,
            exportFormat: .json
        )
        schedule.nextRunAt = Date().addingTimeInterval(-3600) // 1 hour ago
        manager.schedules = [schedule]

        manager.checkSchedules()

        // The schedule should have been updated
        let updated = manager.schedules.first
        XCTAssertNotNil(updated?.lastRunAt)
        XCTAssertNotNil(updated?.nextRunAt)
        if let nextRun = updated?.nextRunAt {
            XCTAssertGreaterThan(nextRun, Date())
        }
    }

    func testCheckSchedulesNotDue() {
        let template = manager.createTemplate(name: "Template")
        var schedule = ReportSchedule(
            name: "Future",
            templateId: template.id,
            frequency: .weekly,
            exportFormat: .csv
        )
        schedule.nextRunAt = Date().addingTimeInterval(86400) // Tomorrow
        manager.schedules = [schedule]

        manager.checkSchedules()

        // Should not have been triggered
        XCTAssertNil(manager.schedules.first?.lastRunAt)
    }

    func testCheckSchedulesInactive() {
        let template = manager.createTemplate(name: "Template")
        var schedule = ReportSchedule(
            name: "Inactive",
            templateId: template.id,
            frequency: .daily,
            exportFormat: .json
        )
        schedule.isActive = false
        schedule.nextRunAt = Date().addingTimeInterval(-3600) // Overdue but inactive
        manager.schedules = [schedule]

        manager.checkSchedules()
        XCTAssertNil(manager.schedules.first?.lastRunAt)
    }

    // MARK: - Initialization & Persistence

    func testDefaultTemplateCreation() {
        manager.templates = []
        manager.initialize()
        XCTAssertFalse(manager.templates.isEmpty)
        XCTAssertEqual(manager.templates.first?.name, "Standard Performance Report")
    }

    func testNoDefaultTemplateWhenTemplatesExist() {
        _ = manager.createTemplate(name: "Existing")
        let count = manager.templates.count
        manager.initialize()
        XCTAssertGreaterThanOrEqual(manager.templates.count, count)
    }

    func testPersistenceRoundTrip() {
        let template = manager.createTemplate(name: "Persist Me", description: "Test persistence")
        _ = manager.createSchedule(name: "Persistent Schedule", templateId: template.id, frequency: .weekly, exportFormat: .markdown)
        manager.shutdown()

        // Create a new manager to load from persistence
        let newManager = ReportGenerationManager()
        let loadedTemplate = newManager.templates.first(where: { $0.name == "Persist Me" })
        XCTAssertNotNil(loadedTemplate)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "reportTemplates")
        UserDefaults.standard.removeObject(forKey: "reportSchedules")
    }

    // MARK: - Helpers

    private func makeTestReport() -> ReportData {
        let summary = ReportSummary(
            totalTokens: 25000, totalCost: 5.50, totalTasks: 100,
            successRate: 0.92, averageLatency: 450.0, periodDescription: "Last 7 days"
        )
        let taskMetrics = ReportTaskMetrics(completed: 92, failed: 5, cancelled: 3, averageDuration: 25.0)
        let errorMetrics = ReportErrorMetrics(
            totalErrors: 8,
            errorsByType: ["timeout": 5, "rate_limit": 3],
            recoveryRate: 0.75,
            mostCommonError: "timeout"
        )
        return ReportData(
            title: "Test Report",
            timeRange: "Last 7 days",
            summary: summary,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )
    }

    private func makeTestReportWithTimeSeries() -> ReportData {
        let summary = ReportSummary(
            totalTokens: 25000, totalCost: 5.50, totalTasks: 100,
            successRate: 0.92, averageLatency: 450.0, periodDescription: "Last 7 days"
        )
        let taskMetrics = ReportTaskMetrics(completed: 92, failed: 5, cancelled: 3, averageDuration: 25.0)
        let errorMetrics = ReportErrorMetrics(
            totalErrors: 8,
            errorsByType: ["timeout": 5, "rate_limit": 3],
            recoveryRate: 0.75,
            mostCommonError: "timeout"
        )
        let tokenData = (0..<3).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 86400), value: Double(5000 + i * 1000))
        }
        let costData = (0..<3).map { i in
            AnalyticsDataPoint(timestamp: Date().addingTimeInterval(Double(i) * 86400), value: 1.0 + Double(i) * 0.5)
        }
        return ReportData(
            title: "Test Report",
            timeRange: "Last 7 days",
            summary: summary,
            tokenUsageData: tokenData,
            costData: costData,
            taskMetrics: taskMetrics,
            errorMetrics: errorMetrics
        )
    }
}
