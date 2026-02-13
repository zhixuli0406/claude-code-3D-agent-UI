import Foundation

// MARK: - I2: Test Coverage Models

struct TestCoverageReport: Identifiable {
    let id: UUID
    var timestamp: Date
    var overallCoverage: Double // 0.0 - 1.0
    var fileCoverages: [FileCoverage]
    var totalTests: Int
    var passedTests: Int
    var failedTests: Int
    var skippedTests: Int
    var duration: TimeInterval

    var successRate: Double {
        totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0
    }
}

struct FileCoverage: Identifiable {
    let id: UUID
    var filePath: String
    var fileName: String
    var coverage: Double // 0.0 - 1.0
    var coveredLines: Int
    var totalLines: Int
    var uncoveredRanges: [LineRange]
    var moduleGroup: String

    var coverageColor: String {
        if coverage >= 0.8 { return "#4CAF50" }
        if coverage >= 0.5 { return "#FF9800" }
        return "#F44336"
    }
}

struct LineRange {
    var start: Int
    var end: Int
}

enum TestResult: String, CaseIterable {
    case passed = "passed"
    case failed = "failed"
    case skipped = "skipped"
    case error = "error"

    var hexColor: String {
        switch self {
        case .passed: return "#4CAF50"
        case .failed: return "#F44336"
        case .skipped: return "#9E9E9E"
        case .error: return "#FF9800"
        }
    }

    var iconName: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct TestCase: Identifiable {
    let id: UUID
    var name: String
    var suiteName: String
    var result: TestResult
    var duration: TimeInterval
    var errorMessage: String?
}

struct CoverageTrend: Identifiable {
    let id: UUID
    var date: Date
    var coverage: Double
    var testCount: Int
}
