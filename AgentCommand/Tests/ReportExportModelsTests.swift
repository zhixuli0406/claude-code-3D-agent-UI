import XCTest
@testable import AgentCommand

// MARK: - M2: Report Export Models Unit Tests

// MARK: - ExportFormat Tests

final class ExportFormatTests: XCTestCase {

    func testAllFormatsHaveDisplayName() {
        for format in ExportFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty, "\(format) should have a displayName")
        }
    }

    func testAllFormatsHaveFileExtension() {
        for format in ExportFormat.allCases {
            XCTAssertFalse(format.fileExtension.isEmpty, "\(format) should have a fileExtension")
        }
    }

    func testAllFormatsHaveMimeType() {
        for format in ExportFormat.allCases {
            XCTAssertTrue(format.mimeType.contains("/"), "\(format) mimeType should contain /")
        }
    }

    func testAllFormatsHaveIconName() {
        for format in ExportFormat.allCases {
            XCTAssertFalse(format.iconName.isEmpty, "\(format) should have an iconName")
        }
    }

    func testJSONFormat() {
        XCTAssertEqual(ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportFormat.json.mimeType, "application/json")
    }

    func testCSVFormat() {
        XCTAssertEqual(ExportFormat.csv.fileExtension, "csv")
        XCTAssertEqual(ExportFormat.csv.mimeType, "text/csv")
    }

    func testMarkdownFormat() {
        XCTAssertEqual(ExportFormat.markdown.fileExtension, "md")
        XCTAssertEqual(ExportFormat.markdown.mimeType, "text/markdown")
    }

    func testPDFFormat() {
        XCTAssertEqual(ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportFormat.pdf.mimeType, "application/pdf")
    }

    func testFormatCodable() throws {
        for format in ExportFormat.allCases {
            let data = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(ExportFormat.self, from: data)
            XCTAssertEqual(decoded, format)
        }
    }
}

// MARK: - ReportTemplate Tests

final class ReportTemplateTests: XCTestCase {

    func testTemplateCreation() {
        let template = ReportTemplate(name: "Weekly Report", description: "Weekly overview")
        XCTAssertFalse(template.id.isEmpty)
        XCTAssertEqual(template.name, "Weekly Report")
        XCTAssertEqual(template.description, "Weekly overview")
        XCTAssertTrue(template.includeCharts)
        XCTAssertTrue(template.includeSummary)
    }

    func testTemplateWithSections() {
        let sections = [
            ReportSection(type: .executiveSummary),
            ReportSection(type: .tokenUsage)
        ]
        let template = ReportTemplate(name: "Custom", sections: sections)
        XCTAssertEqual(template.sections.count, 2)
    }

    func testDefaultTemplate() {
        let defaultTemplate = ReportTemplate.defaultTemplate
        XCTAssertEqual(defaultTemplate.name, "Default Report")
        XCTAssertEqual(defaultTemplate.sections.count, ReportSection.SectionType.allCases.count)
        XCTAssertTrue(defaultTemplate.sections.allSatisfy(\.isEnabled))
    }

    func testTemplateCodable() throws {
        let template = ReportTemplate(name: "Coded", description: "Test")
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(ReportTemplate.self, from: data)
        XCTAssertEqual(decoded.name, "Coded")
        XCTAssertEqual(decoded.id, template.id)
    }
}

// MARK: - ReportSection Tests

final class ReportSectionTests: XCTestCase {

    func testSectionCreation() {
        let section = ReportSection(type: .costAnalysis, isEnabled: true, sortOrder: 3)
        XCTAssertFalse(section.id.isEmpty)
        XCTAssertEqual(section.type, .costAnalysis)
        XCTAssertTrue(section.isEnabled)
        XCTAssertEqual(section.sortOrder, 3)
    }

    func testAllSectionTypesHaveDisplayName() {
        for type in ReportSection.SectionType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) should have a displayName")
        }
    }

    func testAllSectionTypesHaveIconName() {
        for type in ReportSection.SectionType.allCases {
            XCTAssertFalse(type.iconName.isEmpty, "\(type) should have an iconName")
        }
    }

    func testSectionCodable() throws {
        let section = ReportSection(type: .errorAnalysis, isEnabled: false)
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(ReportSection.self, from: data)
        XCTAssertEqual(decoded.type, .errorAnalysis)
        XCTAssertFalse(decoded.isEnabled)
    }
}

// MARK: - ReportSchedule Tests

final class ReportScheduleTests: XCTestCase {

    func testScheduleCreation() {
        let schedule = ReportSchedule(name: "Daily Report", templateId: "t1", frequency: .daily, exportFormat: .pdf)
        XCTAssertFalse(schedule.id.isEmpty)
        XCTAssertEqual(schedule.name, "Daily Report")
        XCTAssertEqual(schedule.frequency, .daily)
        XCTAssertEqual(schedule.exportFormat, .pdf)
        XCTAssertTrue(schedule.isActive)
        XCTAssertNotNil(schedule.nextRunAt)
    }

    func testAllFrequenciesHaveDisplayName() {
        for freq in ReportSchedule.ScheduleFrequency.allCases {
            XCTAssertFalse(freq.displayName.isEmpty, "\(freq) should have a displayName")
        }
    }

    func testFrequencyIntervalDays() {
        XCTAssertEqual(ReportSchedule.ScheduleFrequency.daily.intervalDays, 1)
        XCTAssertEqual(ReportSchedule.ScheduleFrequency.weekly.intervalDays, 7)
        XCTAssertEqual(ReportSchedule.ScheduleFrequency.biweekly.intervalDays, 14)
        XCTAssertEqual(ReportSchedule.ScheduleFrequency.monthly.intervalDays, 30)
    }

    func testNextOccurrence() {
        let now = Date()
        let next = ReportSchedule.ScheduleFrequency.weekly.nextOccurrence(from: now)
        let interval = next.timeIntervalSince(now)
        XCTAssertEqual(interval, 7 * 86400, accuracy: 60)
    }

    func testScheduleCodable() throws {
        let schedule = ReportSchedule(name: "Test", templateId: "t1", frequency: .monthly, exportFormat: .csv)
        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(ReportSchedule.self, from: data)
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.frequency, .monthly)
    }
}

// MARK: - ExportJob Tests

final class ExportJobTests: XCTestCase {

    func testJobCreation() {
        let job = ExportJob(format: .json)
        XCTAssertFalse(job.id.isEmpty)
        XCTAssertEqual(job.format, .json)
        XCTAssertEqual(job.status, .pending)
        XCTAssertEqual(job.progress, 0)
        XCTAssertNil(job.outputPath)
    }

    func testJobProgressPercentage() {
        var job = ExportJob(format: .csv)
        job.progress = 0.75
        XCTAssertEqual(job.progressPercentage, 75)
    }

    func testJobFormattedFileSize() {
        var job = ExportJob(format: .pdf)
        job.fileSize = 1024 * 100 // 100 KB
        XCTAssertNotNil(job.formattedFileSize)
    }

    func testJobFileSizeNilWhenNoSize() {
        let job = ExportJob(format: .json)
        XCTAssertNil(job.formattedFileSize)
    }

    func testJobDuration() {
        var job = ExportJob(format: .markdown)
        job.completedAt = job.startedAt.addingTimeInterval(5.5)
        XCTAssertEqual(job.duration ?? 0, 5.5, accuracy: 0.01)
    }

    func testJobDurationNilWhenIncomplete() {
        let job = ExportJob(format: .csv)
        XCTAssertNil(job.duration)
    }

    func testExportStatusDisplayNames() {
        XCTAssertEqual(ExportJob.ExportStatus.pending.displayName, "Pending")
        XCTAssertEqual(ExportJob.ExportStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(ExportJob.ExportStatus.completed.displayName, "Completed")
        XCTAssertEqual(ExportJob.ExportStatus.failed.displayName, "Failed")
    }

    func testExportStatusColors() {
        XCTAssertEqual(ExportJob.ExportStatus.completed.colorHex, "#4CAF50")
        XCTAssertEqual(ExportJob.ExportStatus.failed.colorHex, "#F44336")
        XCTAssertEqual(ExportJob.ExportStatus.inProgress.colorHex, "#2196F3")
        XCTAssertEqual(ExportJob.ExportStatus.pending.colorHex, "#9E9E9E")
    }
}

// MARK: - ReportData Tests

final class ReportDataTests: XCTestCase {

    private func makeSummary() -> ReportSummary {
        ReportSummary(
            totalTokens: 10000,
            totalCost: 1.50,
            totalTasks: 25,
            successRate: 0.92,
            averageLatency: 450.0,
            periodDescription: "Last 7 days"
        )
    }

    private func makeTaskMetrics() -> ReportTaskMetrics {
        ReportTaskMetrics(completed: 20, failed: 3, cancelled: 2, averageDuration: 30.5)
    }

    private func makeErrorMetrics() -> ReportErrorMetrics {
        ReportErrorMetrics(totalErrors: 5, errorsByType: ["timeout": 3, "rate_limit": 2], recoveryRate: 0.8, mostCommonError: "timeout")
    }

    func testReportDataCreation() {
        let report = ReportData(
            title: "Weekly Report",
            timeRange: "Last 7 days",
            summary: makeSummary(),
            taskMetrics: makeTaskMetrics(),
            errorMetrics: makeErrorMetrics()
        )
        XCTAssertFalse(report.id.isEmpty)
        XCTAssertEqual(report.title, "Weekly Report")
    }

    func testReportSummaryFormattedCost() {
        let summary = makeSummary()
        XCTAssertEqual(summary.formattedCost, "$1.50")
    }

    func testReportSummarySuccessRate() {
        let summary = makeSummary()
        XCTAssertEqual(summary.successRatePercentage, 92)
    }

    func testTaskMetricsTotal() {
        let metrics = makeTaskMetrics()
        XCTAssertEqual(metrics.total, 25)
    }

    func testTaskMetricsSuccessRate() {
        let metrics = makeTaskMetrics()
        XCTAssertEqual(metrics.successRate, 0.8, accuracy: 0.001)
    }

    func testTaskMetricsSuccessRateZeroDivision() {
        let metrics = ReportTaskMetrics(completed: 0, failed: 0, cancelled: 0, averageDuration: 0)
        XCTAssertEqual(metrics.successRate, 0)
    }

    func testErrorMetricsRecoveryPercentage() {
        let metrics = makeErrorMetrics()
        XCTAssertEqual(metrics.recoveryPercentage, 80)
    }
}

// MARK: - Edge Case & Boundary Tests

final class ReportExportEdgeCaseTests: XCTestCase {

    // MARK: - ExportFormat Exhaustiveness

    func testAllFormatsCount() {
        XCTAssertEqual(ExportFormat.allCases.count, 4)
    }

    func testFormatRawValues() {
        XCTAssertEqual(ExportFormat.json.rawValue, "json")
        XCTAssertEqual(ExportFormat.csv.rawValue, "csv")
        XCTAssertEqual(ExportFormat.markdown.rawValue, "markdown")
        XCTAssertEqual(ExportFormat.pdf.rawValue, "pdf")
    }

    // MARK: - ReportTemplate Edge Cases

    func testTemplateWithNoCharts() {
        let template = ReportTemplate(name: "No Charts", sections: [], includeCharts: false, includeSummary: false)
        XCTAssertFalse(template.includeCharts)
        XCTAssertFalse(template.includeSummary)
    }

    func testTemplateEmptySections() {
        let template = ReportTemplate(name: "Empty")
        XCTAssertTrue(template.sections.isEmpty)
    }

    func testTemplateUniqueIDs() {
        let t1 = ReportTemplate(name: "A")
        let t2 = ReportTemplate(name: "A")
        XCTAssertNotEqual(t1.id, t2.id)
    }

    // MARK: - ReportSection Edge Cases

    func testAllSectionTypesCount() {
        XCTAssertEqual(ReportSection.SectionType.allCases.count, 6)
    }

    func testSectionDefaultValues() {
        let section = ReportSection(type: .tokenUsage)
        XCTAssertTrue(section.isEnabled)
        XCTAssertEqual(section.sortOrder, 0)
    }

    func testSectionDisabled() {
        let section = ReportSection(type: .errorAnalysis, isEnabled: false)
        XCTAssertFalse(section.isEnabled)
    }

    // MARK: - ReportSchedule Edge Cases

    func testScheduleDefaultActive() {
        let schedule = ReportSchedule(name: "Test", templateId: "t1", frequency: .daily, exportFormat: .json)
        XCTAssertTrue(schedule.isActive)
        XCTAssertNil(schedule.lastRunAt)
    }

    func testScheduleAllFrequenciesCount() {
        XCTAssertEqual(ReportSchedule.ScheduleFrequency.allCases.count, 4)
    }

    func testScheduleNextOccurrenceDaily() {
        let now = Date()
        let next = ReportSchedule.ScheduleFrequency.daily.nextOccurrence(from: now)
        let interval = next.timeIntervalSince(now)
        XCTAssertEqual(interval, 86400, accuracy: 60)
    }

    func testScheduleNextOccurrenceBiweekly() {
        let now = Date()
        let next = ReportSchedule.ScheduleFrequency.biweekly.nextOccurrence(from: now)
        let interval = next.timeIntervalSince(now)
        XCTAssertEqual(interval, 14 * 86400, accuracy: 60)
    }

    func testScheduleNextOccurrenceMonthly() {
        let now = Date()
        let next = ReportSchedule.ScheduleFrequency.monthly.nextOccurrence(from: now)
        let interval = next.timeIntervalSince(now)
        XCTAssertEqual(interval, 30 * 86400, accuracy: 60)
    }

    // MARK: - ExportJob Edge Cases

    func testJobWithTemplateId() {
        let job = ExportJob(format: .pdf, templateId: "template-123")
        XCTAssertEqual(job.templateId, "template-123")
    }

    func testJobWithoutTemplateId() {
        let job = ExportJob(format: .csv)
        XCTAssertNil(job.templateId)
    }

    func testJobProgressPercentageAtZero() {
        let job = ExportJob(format: .json)
        XCTAssertEqual(job.progressPercentage, 0)
    }

    func testJobProgressPercentageAtFull() {
        var job = ExportJob(format: .json)
        job.progress = 1.0
        XCTAssertEqual(job.progressPercentage, 100)
    }

    func testJobCodable() throws {
        var job = ExportJob(format: .markdown)
        job.status = .completed
        job.progress = 1.0
        job.outputPath = "/tmp/report.md"
        job.fileSize = 2048
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(ExportJob.self, from: data)
        XCTAssertEqual(decoded.format, .markdown)
        XCTAssertEqual(decoded.status, .completed)
        XCTAssertEqual(decoded.fileSize, 2048)
    }

    // MARK: - ReportSummary Edge Cases

    func testSummaryZeroCost() {
        let summary = ReportSummary(
            totalTokens: 0, totalCost: 0, totalTasks: 0,
            successRate: 0, averageLatency: 0, periodDescription: "Empty"
        )
        XCTAssertEqual(summary.formattedCost, "$0.00")
        XCTAssertEqual(summary.successRatePercentage, 0)
    }

    func testSummaryHighCost() {
        let summary = ReportSummary(
            totalTokens: 1_000_000, totalCost: 999.99, totalTasks: 5000,
            successRate: 0.999, averageLatency: 50.0, periodDescription: "Heavy usage"
        )
        XCTAssertEqual(summary.formattedCost, "$999.99")
        XCTAssertEqual(summary.successRatePercentage, 99)
    }

    // MARK: - ReportTaskMetrics Edge Cases

    func testTaskMetricsAllCompleted() {
        let metrics = ReportTaskMetrics(completed: 100, failed: 0, cancelled: 0, averageDuration: 10.0)
        XCTAssertEqual(metrics.total, 100)
        XCTAssertEqual(metrics.successRate, 1.0, accuracy: 0.001)
    }

    func testTaskMetricsAllFailed() {
        let metrics = ReportTaskMetrics(completed: 0, failed: 50, cancelled: 0, averageDuration: 5.0)
        XCTAssertEqual(metrics.total, 50)
        XCTAssertEqual(metrics.successRate, 0.0, accuracy: 0.001)
    }

    // MARK: - ReportErrorMetrics Edge Cases

    func testErrorMetricsNoErrors() {
        let metrics = ReportErrorMetrics(totalErrors: 0, errorsByType: [:], recoveryRate: 0, mostCommonError: nil)
        XCTAssertEqual(metrics.recoveryPercentage, 0)
        XCTAssertNil(metrics.mostCommonError)
    }

    func testErrorMetricsFullRecovery() {
        let metrics = ReportErrorMetrics(totalErrors: 10, errorsByType: ["timeout": 10], recoveryRate: 1.0, mostCommonError: "timeout")
        XCTAssertEqual(metrics.recoveryPercentage, 100)
    }

    // MARK: - ReportData Edge Cases

    func testReportDataWithEmptyTimeSeries() {
        let summary = ReportSummary(
            totalTokens: 100, totalCost: 0.01, totalTasks: 1,
            successRate: 1.0, averageLatency: 100.0, periodDescription: "Test"
        )
        let taskMetrics = ReportTaskMetrics(completed: 1, failed: 0, cancelled: 0, averageDuration: 1.0)
        let errorMetrics = ReportErrorMetrics(totalErrors: 0, errorsByType: [:], recoveryRate: 0, mostCommonError: nil)

        let report = ReportData(
            title: "Minimal", timeRange: "1 day",
            summary: summary, tokenUsageData: [], costData: [],
            taskMetrics: taskMetrics, errorMetrics: errorMetrics
        )
        XCTAssertTrue(report.tokenUsageData.isEmpty)
        XCTAssertTrue(report.costData.isEmpty)
    }

    func testReportDataCodableRoundTrip() throws {
        let summary = ReportSummary(
            totalTokens: 500, totalCost: 0.05, totalTasks: 5,
            successRate: 0.8, averageLatency: 200.0, periodDescription: "Test"
        )
        let taskMetrics = ReportTaskMetrics(completed: 4, failed: 1, cancelled: 0, averageDuration: 15.0)
        let errorMetrics = ReportErrorMetrics(totalErrors: 1, errorsByType: ["parse": 1], recoveryRate: 0.5, mostCommonError: "parse")

        let report = ReportData(
            title: "Roundtrip", timeRange: "1 day",
            summary: summary, taskMetrics: taskMetrics, errorMetrics: errorMetrics
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ReportData.self, from: data)
        XCTAssertEqual(decoded.title, "Roundtrip")
        XCTAssertEqual(decoded.summary.totalTokens, 500)
    }
}
