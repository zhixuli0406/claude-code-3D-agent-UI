import Foundation

// MARK: - I3: Code Quality Models

enum LintSeverity: String, CaseIterable {
    case error = "error"
    case warning = "warning"
    case info = "info"

    var hexColor: String {
        switch self {
        case .error: return "#F44336"
        case .warning: return "#FF9800"
        case .info: return "#2196F3"
        }
    }

    var iconName: String {
        switch self {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct LintIssue: Identifiable {
    let id: UUID
    var filePath: String
    var line: Int
    var column: Int
    var severity: LintSeverity
    var rule: String
    var message: String
    var toolName: String // e.g. "SwiftLint", "ESLint"
}

struct CodeComplexity: Identifiable {
    let id: UUID
    var moduleName: String
    var filePath: String
    var cyclomaticComplexity: Int
    var linesOfCode: Int
    var maintainabilityIndex: Double // 0-100
    var cognitiveComplexity: Int

    var complexityColor: String {
        if cyclomaticComplexity <= 10 { return "#4CAF50" }
        if cyclomaticComplexity <= 20 { return "#FF9800" }
        return "#F44336"
    }

    var maintainabilityColor: String {
        if maintainabilityIndex >= 70 { return "#4CAF50" }
        if maintainabilityIndex >= 40 { return "#FF9800" }
        return "#F44336"
    }
}

struct TechDebtItem: Identifiable {
    let id: UUID
    var title: String
    var description: String
    var filePath: String
    var estimatedHours: Double
    var priority: TechDebtPriority
    var category: TechDebtCategory
    var createdAt: Date
    var isResolved: Bool
}

enum TechDebtPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var hexColor: String {
        switch self {
        case .low: return "#4CAF50"
        case .medium: return "#FF9800"
        case .high: return "#F44336"
        case .critical: return "#9C27B0"
        }
    }
}

enum TechDebtCategory: String, CaseIterable {
    case codeSmell = "code_smell"
    case duplicateCode = "duplicate_code"
    case complexMethod = "complex_method"
    case deprecatedAPI = "deprecated_api"
    case missingTests = "missing_tests"
    case securityVuln = "security_vulnerability"

    var displayName: String {
        switch self {
        case .codeSmell: return "Code Smell"
        case .duplicateCode: return "Duplicate Code"
        case .complexMethod: return "Complex Method"
        case .deprecatedAPI: return "Deprecated API"
        case .missingTests: return "Missing Tests"
        case .securityVuln: return "Security Vulnerability"
        }
    }
}

struct RefactorSuggestion: Identifiable {
    let id: UUID
    var filePath: String
    var title: String
    var description: String
    var impact: String
    var estimatedEffort: String
}

struct CodeQualityStats {
    var totalIssues: Int = 0
    var errorCount: Int = 0
    var warningCount: Int = 0
    var infoCount: Int = 0
    var avgComplexity: Double = 0
    var totalTechDebt: Double = 0 // hours
    var techDebtTrend: [TechDebtTrendPoint] = []
}

struct TechDebtTrendPoint: Identifiable {
    let id: UUID
    var date: Date
    var totalHours: Double
}
