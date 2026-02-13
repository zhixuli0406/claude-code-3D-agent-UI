import XCTest
@testable import AgentCommand

// MARK: - Prompt Quality Score Tests

final class PromptQualityScoreTests: XCTestCase {

    // MARK: - Grade Label

    func testGradeLabelAPlus() {
        let score = makeScore(overall: 0.95)
        XCTAssertEqual(score.gradeLabel, "A+")
    }

    func testGradeLabelA() {
        let score = makeScore(overall: 0.85)
        XCTAssertEqual(score.gradeLabel, "A")
    }

    func testGradeLabelB() {
        let score = makeScore(overall: 0.75)
        XCTAssertEqual(score.gradeLabel, "B")
    }

    func testGradeLabelC() {
        let score = makeScore(overall: 0.65)
        XCTAssertEqual(score.gradeLabel, "C")
    }

    func testGradeLabelD() {
        let score = makeScore(overall: 0.55)
        XCTAssertEqual(score.gradeLabel, "D")
    }

    func testGradeLabelF() {
        let score = makeScore(overall: 0.3)
        XCTAssertEqual(score.gradeLabel, "F")
    }

    func testGradeLabelBoundaryAt90() {
        let score = makeScore(overall: 0.9)
        XCTAssertEqual(score.gradeLabel, "A+")
    }

    func testGradeLabelBoundaryAt80() {
        let score = makeScore(overall: 0.8)
        XCTAssertEqual(score.gradeLabel, "A")
    }

    func testGradeLabelBoundaryAt50() {
        let score = makeScore(overall: 0.5)
        XCTAssertEqual(score.gradeLabel, "D")
    }

    func testGradeLabelBoundaryAtZero() {
        let score = makeScore(overall: 0.0)
        XCTAssertEqual(score.gradeLabel, "F")
    }

    // MARK: - Grade Color

    func testGradeColorGreenForHighScore() {
        let score = makeScore(overall: 0.85)
        XCTAssertEqual(score.gradeColorHex, "#4CAF50")
    }

    func testGradeColorOrangeForMediumScore() {
        let score = makeScore(overall: 0.7)
        XCTAssertEqual(score.gradeColorHex, "#FF9800")
    }

    func testGradeColorRedForLowScore() {
        let score = makeScore(overall: 0.4)
        XCTAssertEqual(score.gradeColorHex, "#F44336")
    }

    // MARK: - Percentage Conversions

    func testOverallPercentage() {
        let score = makeScore(overall: 0.75)
        XCTAssertEqual(score.overallPercentage, 75)
    }

    func testDimensionPercentages() {
        let score = PromptQualityScore(
            id: "test", overallScore: 0.8,
            clarity: 0.9, specificity: 0.7, context: 0.6,
            actionability: 0.5, tokenEfficiency: 0.85,
            estimatedTokens: 50, estimatedCostUSD: 0.001,
            analyzedAt: Date()
        )
        XCTAssertEqual(score.clarityPercentage, 90)
        XCTAssertEqual(score.specificityPercentage, 70)
        XCTAssertEqual(score.contextPercentage, 60)
        XCTAssertEqual(score.actionabilityPercentage, 50)
        XCTAssertEqual(score.tokenEfficiencyPercentage, 85)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = makeScore(overall: 0.85)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromptQualityScore.self, from: data)
        XCTAssertEqual(decoded.overallScore, original.overallScore)
        XCTAssertEqual(decoded.gradeLabel, original.gradeLabel)
        XCTAssertEqual(decoded.estimatedTokens, original.estimatedTokens)
    }

    // MARK: - Helpers

    private func makeScore(overall: Double) -> PromptQualityScore {
        PromptQualityScore(
            id: UUID().uuidString,
            overallScore: overall,
            clarity: overall, specificity: overall, context: overall,
            actionability: overall, tokenEfficiency: overall,
            estimatedTokens: 50, estimatedCostUSD: 0.001,
            analyzedAt: Date()
        )
    }
}

// MARK: - Prompt Suggestion Tests

final class PromptSuggestionTests: XCTestCase {

    func testSuggestionTypeIcons() {
        // Verify all suggestion types have non-empty icons
        for type in PromptSuggestion.SuggestionType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "Icon should not be empty for \(type)")
        }
    }

    func testSuggestionTypeDisplayNames() {
        for type in PromptSuggestion.SuggestionType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "Display name should not be empty for \(type)")
        }
    }

    func testImpactColors() {
        XCTAssertEqual(PromptSuggestion.SuggestionImpact.high.colorHex, "#F44336")
        XCTAssertEqual(PromptSuggestion.SuggestionImpact.medium.colorHex, "#FF9800")
        XCTAssertEqual(PromptSuggestion.SuggestionImpact.low.colorHex, "#4CAF50")
    }

    func testCodableRoundTrip() throws {
        let suggestion = PromptSuggestion(
            id: "test",
            type: .addContext,
            title: "Add Context",
            description: "Add more context",
            originalSnippet: "original",
            suggestedSnippet: "suggested",
            impact: .high
        )
        let data = try JSONEncoder().encode(suggestion)
        let decoded = try JSONDecoder().decode(PromptSuggestion.self, from: data)
        XCTAssertEqual(decoded.type, .addContext)
        XCTAssertEqual(decoded.impact, .high)
    }
}

// MARK: - Prompt Anti-Pattern Tests

final class PromptAntiPatternTests: XCTestCase {

    func testAntiPatternCategoryIcons() {
        for cat in PromptAntiPattern.AntiPatternCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "Icon should not be empty for \(cat)")
        }
    }

    func testAntiPatternCategoryDisplayNames() {
        for cat in PromptAntiPattern.AntiPatternCategory.allCases {
            XCTAssertFalse(cat.displayName.isEmpty, "Display name should not be empty for \(cat)")
        }
    }

    func testSeverityComparable() {
        XCTAssertTrue(PromptAntiPattern.AntiPatternSeverity.critical < .warning)
        XCTAssertTrue(PromptAntiPattern.AntiPatternSeverity.warning < .info)
        XCTAssertTrue(PromptAntiPattern.AntiPatternSeverity.critical < .info)
    }

    func testSeverityColors() {
        XCTAssertEqual(PromptAntiPattern.AntiPatternSeverity.critical.colorHex, "#F44336")
        XCTAssertEqual(PromptAntiPattern.AntiPatternSeverity.warning.colorHex, "#FF9800")
        XCTAssertEqual(PromptAntiPattern.AntiPatternSeverity.info.colorHex, "#03A9F4")
    }

    func testCodableRoundTrip() throws {
        let antiPattern = PromptAntiPattern(
            id: "test",
            category: .vagueness,
            title: "Vague",
            description: "Too vague",
            matchedText: "fix it",
            severity: .critical,
            fixSuggestion: "Be specific"
        )
        let data = try JSONEncoder().encode(antiPattern)
        let decoded = try JSONDecoder().decode(PromptAntiPattern.self, from: data)
        XCTAssertEqual(decoded.category, .vagueness)
        XCTAssertEqual(decoded.severity, .critical)
    }
}

// MARK: - Prompt Pattern Tests

final class PromptPatternTests: XCTestCase {

    func testEffectivenessLabelHighlyEffective() {
        let pattern = makePattern(successRate: 0.9)
        XCTAssertEqual(pattern.effectivenessLabel, "Highly Effective")
        XCTAssertEqual(pattern.effectivenessColorHex, "#4CAF50")
    }

    func testEffectivenessLabelEffective() {
        let pattern = makePattern(successRate: 0.7)
        XCTAssertEqual(pattern.effectivenessLabel, "Effective")
        XCTAssertEqual(pattern.effectivenessColorHex, "#FF9800")
    }

    func testEffectivenessLabelMixed() {
        let pattern = makePattern(successRate: 0.5)
        XCTAssertEqual(pattern.effectivenessLabel, "Mixed Results")
    }

    func testEffectivenessLabelLow() {
        let pattern = makePattern(successRate: 0.2)
        XCTAssertEqual(pattern.effectivenessLabel, "Low Effectiveness")
        XCTAssertEqual(pattern.effectivenessColorHex, "#F44336")
    }

    func testSuccessPercentage() {
        let pattern = makePattern(successRate: 0.85)
        XCTAssertEqual(pattern.successPercentage, 85)
    }

    private func makePattern(successRate: Double) -> PromptPattern {
        PromptPattern(
            id: "test", name: "Test", description: "Test pattern",
            matchCount: 10, avgSuccessRate: successRate,
            avgDuration: 5.0, avgTokens: 100,
            examplePrompts: ["test prompt"],
            detectedAt: Date()
        )
    }
}

// MARK: - History Stats Tests

final class PromptHistoryStatsTests: XCTestCase {

    func testSuccessRate() {
        let stats = PromptHistoryStats(
            id: "test", periodLabel: "2025-01", periodStart: Date(),
            periodEnd: Date(), totalCount: 10, successCount: 7,
            failedCount: 3, avgQualityScore: 0.8,
            totalTokens: 500, totalCostUSD: 0.05,
            tagDistribution: ["bug-fix": 5]
        )
        XCTAssertEqual(stats.successRate, 0.7)
        XCTAssertEqual(stats.avgTokensPerPrompt, 50)
        XCTAssertEqual(stats.avgCostPerPrompt, 0.005, accuracy: 0.0001)
    }

    func testEmptyStats() {
        let stats = PromptHistoryStats(
            id: "test", periodLabel: "empty", periodStart: Date(),
            periodEnd: Date(), totalCount: 0, successCount: 0,
            failedCount: 0, avgQualityScore: 0,
            totalTokens: 0, totalCostUSD: 0,
            tagDistribution: [:]
        )
        XCTAssertEqual(stats.successRate, 0)
        XCTAssertEqual(stats.avgTokensPerPrompt, 0)
        XCTAssertEqual(stats.avgCostPerPrompt, 0)
    }
}

// MARK: - Prompt History Record Tests

final class PromptHistoryRecordTests: XCTestCase {

    func testIsCompletedWhenComplete() {
        let record = PromptHistoryRecord(
            id: "test", prompt: "test", qualityScore: nil,
            sentAt: Date(), completedAt: Date(),
            wasSuccessful: true, taskDuration: nil,
            tokenCount: nil, costUSD: nil,
            tags: [], patternId: nil
        )
        XCTAssertTrue(record.isCompleted)
    }

    func testIsCompletedWhenPending() {
        let record = PromptHistoryRecord(
            id: "test", prompt: "test", qualityScore: nil,
            sentAt: Date(), completedAt: nil,
            wasSuccessful: nil, taskDuration: nil,
            tokenCount: nil, costUSD: nil,
            tags: [], patternId: nil
        )
        XCTAssertFalse(record.isCompleted)
    }
}

// MARK: - Prompt Version Tests

final class PromptVersionTests: XCTestCase {

    func testVersionLabel() {
        let version = PromptVersion(
            id: "test", promptId: "p1",
            version: 3, content: "content",
            qualityScore: nil, wasSuccessful: nil,
            note: nil, createdAt: Date()
        )
        XCTAssertEqual(version.versionLabel, "v3")
    }
}

// MARK: - Prompt Analysis Report Tests

final class PromptAnalysisReportTests: XCTestCase {

    func testIssueCounts() {
        let report = PromptAnalysisReport(
            id: "test",
            prompt: "test",
            score: PromptQualityScore(
                id: "s1", overallScore: 0.5, clarity: 0.5, specificity: 0.5,
                context: 0.5, actionability: 0.5, tokenEfficiency: 0.5,
                estimatedTokens: 50, estimatedCostUSD: 0.001, analyzedAt: Date()
            ),
            suggestions: [],
            antiPatterns: [
                PromptAntiPattern(id: "a1", category: .vagueness, title: "", description: "",
                    matchedText: "", severity: .critical, fixSuggestion: ""),
                PromptAntiPattern(id: "a2", category: .overloading, title: "", description: "",
                    matchedText: "", severity: .critical, fixSuggestion: ""),
                PromptAntiPattern(id: "a3", category: .redundancy, title: "", description: "",
                    matchedText: "", severity: .warning, fixSuggestion: ""),
                PromptAntiPattern(id: "a4", category: .scopeCreep, title: "", description: "",
                    matchedText: "", severity: .info, fixSuggestion: ""),
            ],
            rewriteSuggestion: nil,
            analyzedAt: Date()
        )
        XCTAssertEqual(report.issueCount, 4)
        XCTAssertEqual(report.criticalCount, 2)
        XCTAssertEqual(report.warningCount, 1)
        XCTAssertEqual(report.infoCount, 1)
    }
}

// MARK: - Sort & Grouping Enums Tests

final class PromptEnumsTests: XCTestCase {

    func testHistorySortOptionDisplayNames() {
        for option in PromptHistorySortOption.allCases {
            XCTAssertFalse(option.displayName.isEmpty)
            XCTAssertFalse(option.iconName.isEmpty)
        }
    }

    func testHistoryTimeGroupingDisplayNames() {
        for grouping in PromptHistoryTimeGrouping.allCases {
            XCTAssertFalse(grouping.displayName.isEmpty)
            XCTAssertFalse(grouping.iconName.isEmpty)
        }
    }
}
