import XCTest
@testable import AgentCommand

// MARK: - M2: Report Export Manager Unit Tests

@MainActor
final class ReportExportManagerTests: XCTestCase {

    private var manager: ReportExportManager!

    override func setUp() {
        super.setUp()
        manager = ReportExportManager()
    }

    override func tearDown() {
        manager.stopScheduleMonitoring()
        manager = nil
        super.tearDown()
    }

    // MARK: - Create Template

    func testCreateTemplate_Basic() {
        let sections = [
            ReportSection(type: .executiveSummary),
            ReportSection(type: .tokenUsage)
        ]
        manager.createTemplate(name: "Weekly Report", description: "Weekly overview", sections: sections)

        XCTAssertEqual(manager.templates.count, 1)
        XCTAssertEqual(manager.templates[0].name, "Weekly Report")
        XCTAssertEqual(manager.templates[0].description, "Weekly overview")
        XCTAssertTrue(manager.templates[0].includeCharts)
        XCTAssertTrue(manager.templates[0].includeSummary)
    }

    func testCreateTemplate_SectionsPreserved() {
        let sections = [
            ReportSection(type: .executiveSummary, isEnabled: true, sortOrder: 0),
            ReportSection(type: .costAnalysis, isEnabled: false, sortOrder: 1),
            ReportSection(type: .errorAnalysis, isEnabled: true, sortOrder: 2)
        ]
        manager.createTemplate(name: "Custom", description: "Custom report", sections: sections)

        XCTAssertEqual(manager.templates[0].sections.count, 3)
        XCTAssertEqual(manager.templates[0].sections[0].type, .executiveSummary)
        XCTAssertEqual(manager.templates[0].sections[1].type, .costAnalysis)
        XCTAssertFalse(manager.templates[0].sections[1].isEnabled)
        XCTAssertEqual(manager.templates[0].sections[2].type, .errorAnalysis)
    }

    func testCreateTemplate_MultipleTemplates() {
        manager.createTemplate(name: "Template A", description: "First", sections: [])
        manager.createTemplate(name: "Template B", description: "Second", sections: [])

        XCTAssertEqual(manager.templates.count, 2)
        XCTAssertEqual(manager.templates[0].name, "Template A")
        XCTAssertEqual(manager.templates[1].name, "Template B")
    }

    // MARK: - Delete Template

    func testDeleteTemplate_ById() {
        manager.createTemplate(name: "To Delete", description: "", sections: [])
        let templateId = manager.templates[0].id
        XCTAssertEqual(manager.templates.count, 1)

        manager.deleteTemplate(templateId)
        XCTAssertTrue(manager.templates.isEmpty)
    }

    func testDeleteTemplate_NonExistentId() {
        manager.createTemplate(name: "Keep", description: "", sections: [])
        XCTAssertEqual(manager.templates.count, 1)

        manager.deleteTemplate("non-existent-id")
        XCTAssertEqual(manager.templates.count, 1)
        XCTAssertEqual(manager.templates[0].name, "Keep")
    }

    func testDeleteTemplate_OnlyRemovesTargeted() {
        manager.createTemplate(name: "Template A", description: "", sections: [])
        manager.createTemplate(name: "Template B", description: "", sections: [])
        let idToDelete = manager.templates[0].id

        manager.deleteTemplate(idToDelete)
        XCTAssertEqual(manager.templates.count, 1)
        XCTAssertEqual(manager.templates[0].name, "Template B")
    }

    // MARK: - Create Schedule

    func testCreateSchedule_Basic() {
        manager.createSchedule(name: "Daily Summary", templateId: "t1", frequency: .daily, format: .json)

        XCTAssertEqual(manager.schedules.count, 1)
        XCTAssertEqual(manager.schedules[0].name, "Daily Summary")
        XCTAssertEqual(manager.schedules[0].templateId, "t1")
        XCTAssertTrue(manager.schedules[0].isActive)
    }

    func testCreateSchedule_FrequencyPreserved() {
        manager.createSchedule(name: "Weekly", templateId: "t1", frequency: .weekly, format: .csv)
        manager.createSchedule(name: "Monthly", templateId: "t2", frequency: .monthly, format: .pdf)

        XCTAssertEqual(manager.schedules[0].frequency, .weekly)
        XCTAssertEqual(manager.schedules[1].frequency, .monthly)
    }

    func testCreateSchedule_FormatPreserved() {
        manager.createSchedule(name: "PDF Report", templateId: "t1", frequency: .daily, format: .pdf)
        manager.createSchedule(name: "MD Report", templateId: "t2", frequency: .biweekly, format: .markdown)

        XCTAssertEqual(manager.schedules[0].exportFormat, .pdf)
        XCTAssertEqual(manager.schedules[1].exportFormat, .markdown)
    }

    func testCreateSchedule_HasNextRunAt() {
        manager.createSchedule(name: "Scheduled", templateId: "t1", frequency: .daily, format: .json)
        XCTAssertNotNil(manager.schedules[0].nextRunAt)
    }

    // MARK: - Toggle Schedule

    func testToggleSchedule_TogglesActiveState() {
        manager.createSchedule(name: "Toggle Me", templateId: "t1", frequency: .daily, format: .json)
        let scheduleId = manager.schedules[0].id
        XCTAssertTrue(manager.schedules[0].isActive)

        manager.toggleSchedule(scheduleId)
        XCTAssertFalse(manager.schedules[0].isActive)

        manager.toggleSchedule(scheduleId)
        XCTAssertTrue(manager.schedules[0].isActive)
    }

    func testToggleSchedule_NonExistentId() {
        manager.createSchedule(name: "Untouched", templateId: "t1", frequency: .daily, format: .json)
        let originalActive = manager.schedules[0].isActive

        manager.toggleSchedule("non-existent-id")
        XCTAssertEqual(manager.schedules[0].isActive, originalActive)
    }

    // MARK: - Delete Schedule

    func testDeleteSchedule_ById() {
        manager.createSchedule(name: "To Delete", templateId: "t1", frequency: .daily, format: .json)
        let scheduleId = manager.schedules[0].id

        manager.deleteSchedule(scheduleId)
        XCTAssertTrue(manager.schedules.isEmpty)
    }

    func testDeleteSchedule_NonExistentId() {
        manager.createSchedule(name: "Keep", templateId: "t1", frequency: .weekly, format: .csv)

        manager.deleteSchedule("non-existent-id")
        XCTAssertEqual(manager.schedules.count, 1)
    }

    func testDeleteSchedule_OnlyRemovesTargeted() {
        manager.createSchedule(name: "Schedule A", templateId: "t1", frequency: .daily, format: .json)
        manager.createSchedule(name: "Schedule B", templateId: "t2", frequency: .weekly, format: .csv)
        let idToDelete = manager.schedules[0].id

        manager.deleteSchedule(idToDelete)
        XCTAssertEqual(manager.schedules.count, 1)
        XCTAssertEqual(manager.schedules[0].name, "Schedule B")
    }

    // MARK: - Export Report

    func testExportReport_SetsIsExportingTrue() {
        manager.exportReport(format: .json, templateId: nil)

        XCTAssertTrue(manager.isExporting)
    }

    func testExportReport_AddsJobWithInProgressStatus() {
        manager.exportReport(format: .pdf, templateId: "t1")

        XCTAssertEqual(manager.exportJobs.count, 1)
        XCTAssertEqual(manager.exportJobs[0].status, .inProgress)
        XCTAssertEqual(manager.exportJobs[0].format, .pdf)
        XCTAssertEqual(manager.exportJobs[0].templateId, "t1")
    }

    func testExportReport_GuardsWhenAlreadyExporting() {
        manager.exportReport(format: .json, templateId: nil)
        XCTAssertTrue(manager.isExporting)
        XCTAssertEqual(manager.exportJobs.count, 1)

        // Second call should be guarded
        manager.exportReport(format: .csv, templateId: nil)
        XCTAssertEqual(manager.exportJobs.count, 1)
        XCTAssertEqual(manager.exportJobs[0].format, .json)
    }

    func testExportReport_JobHasCorrectFormat() {
        manager.exportReport(format: .markdown, templateId: nil)

        XCTAssertEqual(manager.exportJobs[0].format, .markdown)
    }

    // MARK: - Cancel Export

    func testCancelExport_SetsStatusToFailed() {
        manager.exportReport(format: .json, templateId: nil)
        let jobId = manager.exportJobs[0].id

        manager.cancelExport(jobId)

        XCTAssertEqual(manager.exportJobs[0].status, .failed)
        XCTAssertEqual(manager.exportJobs[0].errorMessage, "Export cancelled by user")
        XCTAssertNotNil(manager.exportJobs[0].completedAt)
        XCTAssertFalse(manager.isExporting)
    }

    func testCancelExport_OnlyCancelsPendingOrInProgressJobs() {
        // Manually create a completed job
        var completedJob = ExportJob(format: .json)
        completedJob.status = .completed
        completedJob.progress = 1.0
        manager.exportJobs.append(completedJob)

        manager.cancelExport(completedJob.id)

        // Status should remain completed since it's not pending/inProgress
        XCTAssertEqual(manager.exportJobs[0].status, .completed)
    }

    func testCancelExport_DoesNotCrashOnNonExistentId() {
        manager.cancelExport("non-existent-id")
        // Should not crash; no jobs to modify
        XCTAssertTrue(manager.exportJobs.isEmpty)
    }

    func testCancelExport_PendingJob() {
        var pendingJob = ExportJob(format: .csv)
        pendingJob.status = .pending
        manager.exportJobs.append(pendingJob)

        manager.cancelExport(pendingJob.id)

        XCTAssertEqual(manager.exportJobs[0].status, .failed)
        XCTAssertEqual(manager.exportJobs[0].errorMessage, "Export cancelled by user")
    }

    // MARK: - Delete Export Job

    func testDeleteExportJob_RemovesById() {
        var job = ExportJob(format: .json)
        job.status = .completed
        manager.exportJobs.append(job)
        XCTAssertEqual(manager.exportJobs.count, 1)

        manager.deleteExportJob(job.id)
        XCTAssertTrue(manager.exportJobs.isEmpty)
    }

    func testDeleteExportJob_NonExistentId() {
        var job = ExportJob(format: .csv)
        job.status = .completed
        manager.exportJobs.append(job)

        manager.deleteExportJob("non-existent-id")
        XCTAssertEqual(manager.exportJobs.count, 1)
    }

    func testDeleteExportJob_OnlyRemovesTargeted() {
        var jobA = ExportJob(format: .json)
        jobA.status = .completed
        var jobB = ExportJob(format: .csv)
        jobB.status = .failed

        manager.exportJobs.append(jobA)
        manager.exportJobs.append(jobB)

        manager.deleteExportJob(jobA.id)
        XCTAssertEqual(manager.exportJobs.count, 1)
        XCTAssertEqual(manager.exportJobs[0].id, jobB.id)
    }

    // MARK: - Generate Report Data

    func testGenerateReportData_ReturnsValidReport() {
        let report = manager.generateReportData(title: "Test Report", timeRange: "Last 7 Days")

        XCTAssertFalse(report.id.isEmpty)
        XCTAssertEqual(report.title, "Test Report")
        XCTAssertEqual(report.timeRange, "Last 7 Days")
        XCTAssertNotNil(report.generatedAt)
    }

    func testGenerateReportData_HasSummary() {
        let report = manager.generateReportData(title: "Summary Test", timeRange: "Last 30 Days")

        XCTAssertGreaterThan(report.summary.totalTokens, 0)
        XCTAssertGreaterThan(report.summary.totalCost, 0)
        XCTAssertGreaterThan(report.summary.totalTasks, 0)
        XCTAssertGreaterThan(report.summary.successRate, 0)
        XCTAssertGreaterThan(report.summary.averageLatency, 0)
        XCTAssertEqual(report.summary.periodDescription, "Last 30 Days")
    }

    func testGenerateReportData_HasTaskMetrics() {
        let report = manager.generateReportData(title: "Metrics Test", timeRange: "Last 7 Days")

        XCTAssertGreaterThan(report.taskMetrics.completed, 0)
        XCTAssertGreaterThanOrEqual(report.taskMetrics.failed, 0)
        XCTAssertGreaterThanOrEqual(report.taskMetrics.cancelled, 0)
        XCTAssertGreaterThan(report.taskMetrics.averageDuration, 0)
        XCTAssertEqual(report.taskMetrics.total, report.taskMetrics.completed + report.taskMetrics.failed + report.taskMetrics.cancelled)
    }

    func testGenerateReportData_HasErrorMetrics() {
        let report = manager.generateReportData(title: "Error Test", timeRange: "Last 7 Days")

        XCTAssertGreaterThan(report.errorMetrics.totalErrors, 0)
        XCTAssertFalse(report.errorMetrics.errorsByType.isEmpty)
        XCTAssertGreaterThan(report.errorMetrics.recoveryRate, 0)
        XCTAssertEqual(report.errorMetrics.mostCommonError, "Timeout")
    }

    func testGenerateReportData_HasTokenUsageData() {
        let report = manager.generateReportData(title: "Token Data Test", timeRange: "Last 7 Days")

        XCTAssertEqual(report.tokenUsageData.count, 7)
        for point in report.tokenUsageData {
            XCTAssertGreaterThan(point.value, 0)
            XCTAssertNotNil(point.label)
        }
    }

    func testGenerateReportData_HasCostData() {
        let report = manager.generateReportData(title: "Cost Data Test", timeRange: "Last 7 Days")

        XCTAssertEqual(report.costData.count, 7)
        for point in report.costData {
            XCTAssertGreaterThan(point.value, 0)
            XCTAssertNotNil(point.label)
        }
    }

    // MARK: - Load Sample Data

    func testLoadSampleData_TemplateCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.templates.count, 2)
    }

    func testLoadSampleData_ScheduleCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.schedules.count, 2)
    }

    func testLoadSampleData_ExportJobCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.exportJobs.count, 3)
    }

    func testLoadSampleData_GeneratedReportCount() {
        manager.loadSampleData()
        XCTAssertEqual(manager.generatedReports.count, 1)
    }

    func testLoadSampleData_TemplateNames() {
        manager.loadSampleData()
        XCTAssertEqual(manager.templates[0].name, "Default Report")
        XCTAssertEqual(manager.templates[1].name, "Cost Analysis Report")
    }

    func testLoadSampleData_ScheduleStates() {
        manager.loadSampleData()
        // First schedule is active daily
        XCTAssertTrue(manager.schedules[0].isActive)
        XCTAssertEqual(manager.schedules[0].frequency, .daily)
        // Second schedule is inactive weekly
        XCTAssertFalse(manager.schedules[1].isActive)
        XCTAssertEqual(manager.schedules[1].frequency, .weekly)
    }

    func testLoadSampleData_ExportJobStatuses() {
        manager.loadSampleData()
        XCTAssertEqual(manager.exportJobs[0].status, .completed)
        XCTAssertEqual(manager.exportJobs[1].status, .inProgress)
        XCTAssertEqual(manager.exportJobs[2].status, .failed)
    }

    // MARK: - Computed: completedExports

    func testCompletedExports_Empty() {
        XCTAssertTrue(manager.completedExports.isEmpty)
    }

    func testCompletedExports_FiltersCorrectly() {
        var completedJob = ExportJob(format: .json)
        completedJob.status = .completed

        var failedJob = ExportJob(format: .csv)
        failedJob.status = .failed

        var inProgressJob = ExportJob(format: .pdf)
        inProgressJob.status = .inProgress

        var pendingJob = ExportJob(format: .markdown)
        pendingJob.status = .pending

        manager.exportJobs = [completedJob, failedJob, inProgressJob, pendingJob]

        XCTAssertEqual(manager.completedExports.count, 1)
        XCTAssertEqual(manager.completedExports[0].id, completedJob.id)
    }

    func testCompletedExports_MultipleCompleted() {
        var job1 = ExportJob(format: .json)
        job1.status = .completed
        var job2 = ExportJob(format: .csv)
        job2.status = .completed
        var job3 = ExportJob(format: .pdf)
        job3.status = .failed

        manager.exportJobs = [job1, job2, job3]

        XCTAssertEqual(manager.completedExports.count, 2)
    }

    func testCompletedExports_AfterLoadSampleData() {
        manager.loadSampleData()
        // Sample data has 1 completed, 1 inProgress, 1 failed
        XCTAssertEqual(manager.completedExports.count, 1)
        XCTAssertEqual(manager.completedExports[0].status, .completed)
    }

    // MARK: - Computed: activeScheduleCount

    func testActiveScheduleCount_Empty() {
        XCTAssertEqual(manager.activeScheduleCount, 0)
    }

    func testActiveScheduleCount_AllActive() {
        manager.createSchedule(name: "A", templateId: "t1", frequency: .daily, format: .json)
        manager.createSchedule(name: "B", templateId: "t2", frequency: .weekly, format: .csv)

        XCTAssertEqual(manager.activeScheduleCount, 2)
    }

    func testActiveScheduleCount_MixedStates() {
        manager.createSchedule(name: "Active", templateId: "t1", frequency: .daily, format: .json)
        manager.createSchedule(name: "Inactive", templateId: "t2", frequency: .weekly, format: .csv)
        let inactiveId = manager.schedules[1].id
        manager.toggleSchedule(inactiveId)

        XCTAssertEqual(manager.activeScheduleCount, 1)
    }

    func testActiveScheduleCount_AfterLoadSampleData() {
        manager.loadSampleData()
        // Sample data: 1 active, 1 inactive
        XCTAssertEqual(manager.activeScheduleCount, 1)
    }

    func testActiveScheduleCount_AfterToggle() {
        manager.createSchedule(name: "A", templateId: "t1", frequency: .daily, format: .json)
        XCTAssertEqual(manager.activeScheduleCount, 1)

        manager.toggleSchedule(manager.schedules[0].id)
        XCTAssertEqual(manager.activeScheduleCount, 0)

        manager.toggleSchedule(manager.schedules[0].id)
        XCTAssertEqual(manager.activeScheduleCount, 1)
    }

    // MARK: - Schedule Monitoring

    func testStartScheduleMonitoring_DoesNotCrash() {
        manager.startScheduleMonitoring()
        // Should not crash; timer is set up internally
        XCTAssertTrue(true)
    }

    func testStopScheduleMonitoring_DoesNotCrash() {
        manager.startScheduleMonitoring()
        manager.stopScheduleMonitoring()
        // Should not crash; timer is invalidated
        XCTAssertTrue(true)
    }

    func testStopScheduleMonitoring_WithoutStart() {
        // Stopping without starting should not crash
        manager.stopScheduleMonitoring()
        XCTAssertTrue(true)
    }

    func testStartScheduleMonitoring_CalledTwice() {
        // Calling start twice should not crash; replaces existing timer
        manager.startScheduleMonitoring()
        manager.startScheduleMonitoring()
        XCTAssertTrue(true)
    }

    // MARK: - Initial State

    func testInitialState_AllEmpty() {
        XCTAssertTrue(manager.templates.isEmpty)
        XCTAssertTrue(manager.schedules.isEmpty)
        XCTAssertTrue(manager.exportJobs.isEmpty)
        XCTAssertTrue(manager.generatedReports.isEmpty)
        XCTAssertFalse(manager.isExporting)
    }
}
