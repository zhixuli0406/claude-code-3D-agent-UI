import Foundation

// MARK: - M2: Export & Reporting System Models

/// Supported export formats
enum ExportFormat: String, Codable, CaseIterable {
    case json
    case csv
    case markdown
    case pdf

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .pdf: return "pdf"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .markdown: return "text/markdown"
        case .pdf: return "application/pdf"
        }
    }

    var iconName: String {
        switch self {
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .markdown: return "doc.text"
        case .pdf: return "doc.richtext"
        }
    }
}

// MARK: - Report Template

/// A reusable report template
struct ReportTemplate: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var sections: [ReportSection]
    var includeCharts: Bool
    var includeSummary: Bool
    var createdAt: Date

    init(name: String, description: String = "", sections: [ReportSection] = [], includeCharts: Bool = true, includeSummary: Bool = true) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.sections = sections
        self.includeCharts = includeCharts
        self.includeSummary = includeSummary
        self.createdAt = Date()
    }

    static let defaultTemplate = ReportTemplate(
        name: "Default Report",
        description: "Standard performance report with all sections",
        sections: ReportSection.SectionType.allCases.map {
            ReportSection(type: $0, isEnabled: true)
        }
    )
}

/// A section within a report
struct ReportSection: Identifiable, Codable, Hashable {
    let id: String
    var type: SectionType
    var isEnabled: Bool
    var sortOrder: Int

    init(type: SectionType, isEnabled: Bool = true, sortOrder: Int = 0) {
        self.id = UUID().uuidString
        self.type = type
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }

    enum SectionType: String, Codable, CaseIterable, Hashable {
        case executiveSummary
        case tokenUsage
        case costAnalysis
        case taskMetrics
        case errorAnalysis
        case performanceTrends

        var displayName: String {
            switch self {
            case .executiveSummary: return "Executive Summary"
            case .tokenUsage: return "Token Usage"
            case .costAnalysis: return "Cost Analysis"
            case .taskMetrics: return "Task Metrics"
            case .errorAnalysis: return "Error Analysis"
            case .performanceTrends: return "Performance Trends"
            }
        }

        var iconName: String {
            switch self {
            case .executiveSummary: return "doc.text.magnifyingglass"
            case .tokenUsage: return "number.circle"
            case .costAnalysis: return "dollarsign.circle"
            case .taskMetrics: return "checkmark.circle"
            case .errorAnalysis: return "exclamationmark.triangle"
            case .performanceTrends: return "chart.line.uptrend.xyaxis"
            }
        }
    }
}

// MARK: - Report Schedule

/// Schedule for automatic report generation
struct ReportSchedule: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var templateId: String
    var frequency: ScheduleFrequency
    var exportFormat: ExportFormat
    var isActive: Bool
    var lastRunAt: Date?
    var nextRunAt: Date?
    var createdAt: Date

    init(name: String, templateId: String, frequency: ScheduleFrequency, exportFormat: ExportFormat) {
        self.id = UUID().uuidString
        self.name = name
        self.templateId = templateId
        self.frequency = frequency
        self.exportFormat = exportFormat
        self.isActive = true
        self.createdAt = Date()
        self.nextRunAt = frequency.nextOccurrence(from: Date())
    }

    enum ScheduleFrequency: String, Codable, CaseIterable, Hashable {
        case daily
        case weekly
        case biweekly
        case monthly

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .biweekly: return "Bi-weekly"
            case .monthly: return "Monthly"
            }
        }

        var intervalDays: Int {
            switch self {
            case .daily: return 1
            case .weekly: return 7
            case .biweekly: return 14
            case .monthly: return 30
            }
        }

        func nextOccurrence(from date: Date) -> Date {
            Calendar.current.date(byAdding: .day, value: intervalDays, to: date) ?? date
        }
    }
}

// MARK: - Export Job

/// Tracks the state of an export operation
struct ExportJob: Identifiable, Codable, Hashable {
    let id: String
    var templateId: String?
    var format: ExportFormat
    var status: ExportStatus
    var progress: Double // 0.0 - 1.0
    var outputPath: String?
    var fileSize: Int64?
    var errorMessage: String?
    var startedAt: Date
    var completedAt: Date?

    init(format: ExportFormat, templateId: String? = nil) {
        self.id = UUID().uuidString
        self.templateId = templateId
        self.format = format
        self.status = .pending
        self.progress = 0
        self.startedAt = Date()
    }

    var progressPercentage: Int { Int(progress * 100) }

    var formattedFileSize: String? {
        guard let fileSize = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }

    enum ExportStatus: String, Codable, Hashable {
        case pending
        case inProgress
        case completed
        case failed

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }

        var colorHex: String {
            switch self {
            case .pending: return "#9E9E9E"
            case .inProgress: return "#2196F3"
            case .completed: return "#4CAF50"
            case .failed: return "#F44336"
            }
        }
    }
}

// MARK: - Report Data Container

/// Container for generated report data
struct ReportData: Identifiable, Codable {
    let id: String
    var title: String
    var generatedAt: Date
    var timeRange: String
    var summary: ReportSummary
    var tokenUsageData: [AnalyticsDataPoint]
    var costData: [AnalyticsDataPoint]
    var taskMetrics: ReportTaskMetrics
    var errorMetrics: ReportErrorMetrics

    init(title: String, timeRange: String, summary: ReportSummary, tokenUsageData: [AnalyticsDataPoint] = [], costData: [AnalyticsDataPoint] = [], taskMetrics: ReportTaskMetrics, errorMetrics: ReportErrorMetrics) {
        self.id = UUID().uuidString
        self.title = title
        self.generatedAt = Date()
        self.timeRange = timeRange
        self.summary = summary
        self.tokenUsageData = tokenUsageData
        self.costData = costData
        self.taskMetrics = taskMetrics
        self.errorMetrics = errorMetrics
    }
}

/// Summary section of a report
struct ReportSummary: Codable {
    var totalTokens: Int
    var totalCost: Double
    var totalTasks: Int
    var successRate: Double
    var averageLatency: Double
    var periodDescription: String

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var successRatePercentage: Int { Int(successRate * 100) }
}

/// Task metrics for a report
struct ReportTaskMetrics: Codable {
    var completed: Int
    var failed: Int
    var cancelled: Int
    var averageDuration: TimeInterval

    var total: Int { completed + failed + cancelled }

    var successRate: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

/// Error metrics for a report
struct ReportErrorMetrics: Codable {
    var totalErrors: Int
    var errorsByType: [String: Int]
    var recoveryRate: Double
    var mostCommonError: String?

    var recoveryPercentage: Int { Int(recoveryRate * 100) }
}
