import XCTest
@testable import AgentCommand

// MARK: - Integration Tests: Full Pipeline

@MainActor
final class PromptOptimizationIntegrationTests: XCTestCase {

    private var manager: PromptOptimizationManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationPatterns")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationABTests")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationVersions")
        manager = PromptOptimizationManager()
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationPatterns")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationABTests")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationVersions")
        super.tearDown()
    }

    // MARK: - Full Prompt Lifecycle

    func testFullPromptLifecycle() {
        // 1. Analyze a prompt
        let score = manager.analyzePrompt("Fix the login bug in AuthService.swift")
        XCTAssertGreaterThan(score.overallScore, 0)
        XCTAssertNotNil(manager.lastScore)
        XCTAssertNotNil(manager.lastReport)

        // 2. Record the prompt to history
        let record = manager.recordPrompt("Fix the login bug in AuthService.swift", score: score)
        XCTAssertEqual(manager.history.count, 1)
        XCTAssertNotNil(record.qualityScore)

        // 3. Mark as complete
        manager.recordCompletion(recordId: record.id, success: true,
                                duration: 5.0, tokenCount: 100, costUSD: 0.01)
        let updated = manager.history.first { $0.id == record.id }!
        XCTAssertTrue(updated.isCompleted)
        XCTAssertEqual(updated.wasSuccessful, true)

        // 4. Check that stats are updated
        XCTAssertEqual(manager.totalPromptsAnalyzed, 1)
        XCTAssertGreaterThan(manager.avgQualityScore, 0)

        // 5. Verify filtered history is maintained
        XCTAssertEqual(manager.filteredHistory.count, 1)
    }

    // MARK: - Analyze → Record → Pattern Detect Pipeline

    func testAnalyzeRecordPatternPipeline() {
        // Create enough completed records to detect patterns
        for i in 0..<8 {
            let prompt = "Fix the critical bug number \(i) in the login authentication system"
            let score = manager.analyzePrompt(prompt)
            let record = manager.recordPrompt(prompt, score: score)
            manager.recordCompletion(recordId: record.id, success: i % 3 != 0,
                                    duration: Double(i + 1), tokenCount: 50 + i * 10,
                                    costUSD: 0.005 + Double(i) * 0.001)
        }

        // Detect patterns
        manager.detectPatterns()

        // Should have at least a "bug-fix" pattern
        XCTAssertFalse(manager.patterns.isEmpty,
            "Should detect patterns from sufficient history")

        // Pattern should have reasonable stats
        if let pattern = manager.patterns.first {
            XCTAssertGreaterThan(pattern.matchCount, 0)
            XCTAssertGreaterThanOrEqual(pattern.avgSuccessRate, 0)
            XCTAssertLessThanOrEqual(pattern.avgSuccessRate, 1.0)
        }
    }

    // MARK: - A/B Test Full Workflow

    func testABTestFullWorkflow() {
        // 1. Create A/B test
        let test = manager.createABTest(
            task: "Optimize login prompt",
            promptA: "Fix the login bug",
            promptB: "Fix the authentication error in LoginService.swift by updating the OAuth2 token validation"
        )
        XCTAssertEqual(test.status, .pending)
        XCTAssertEqual(manager.activeABTests, 1)

        // 2. Analyze both variants
        let scoreA = manager.analyzePrompt(test.variantA.prompt)
        let scoreB = manager.analyzePrompt(test.variantB.prompt)

        // 3. The more specific prompt should generally score higher
        XCTAssertGreaterThan(scoreB.specificity, scoreA.specificity,
            "Detailed prompt should be more specific")

        // 4. Run variant A
        manager.updateABTestVariant(testId: test.id, variant: "A",
            success: true, duration: 3.0, tokenCount: 30, costUSD: 0.003)
        XCTAssertEqual(manager.abTests.first?.status, .running)

        // 5. Run variant B
        manager.updateABTestVariant(testId: test.id, variant: "B",
            success: true, duration: 2.0, tokenCount: 60, costUSD: 0.006)

        // 6. Check completion
        let completed = manager.abTests.first { $0.id == test.id }
        XCTAssertEqual(completed?.status, .completed)
        XCTAssertNotNil(completed?.winnerVariant)
        XCTAssertEqual(manager.activeABTests, 0)
    }

    // MARK: - Version Management Integration

    func testVersionManagementWorkflow() {
        // 1. Create initial version
        let promptId = "auth-prompt"
        manager.saveVersion(promptId: promptId, content: "Fix the login bug", note: "Initial")

        // 2. Analyze and improve
        let score1 = manager.analyzePrompt("Fix the login bug")

        // 3. Save improved version
        let improvedPrompt = "Fix the authentication bug in LoginService.swift by updating the OAuth2 token validation. Ensure all user types can log in successfully."
        manager.saveVersion(promptId: promptId, content: improvedPrompt, note: "Improved specificity")

        // 4. Analyze improved version
        let score2 = manager.analyzePrompt(improvedPrompt)

        // 5. Verify improvement
        XCTAssertGreaterThan(score2.overallScore, score1.overallScore,
            "Improved prompt should score higher")

        // 6. Verify version history
        let versions = manager.versionsForPrompt(promptId)
        XCTAssertEqual(versions.count, 2)
        XCTAssertEqual(versions.first?.version, 2, "Latest version should be first")
    }

    // MARK: - Quick Analysis + Full Analysis Consistency

    func testQuickAndFullAnalysisConsistency() {
        let prompt = "Fix the login bug in AuthService.swift"

        // Quick analysis should match full analysis in scoring logic
        let quickScore = manager.quickAnalyze(prompt)
        let fullScore = manager.analyzePrompt(prompt)

        // The scores should be the same (same algorithm)
        XCTAssertEqual(quickScore.clarity, fullScore.clarity, accuracy: 0.001)
        XCTAssertEqual(quickScore.specificity, fullScore.specificity, accuracy: 0.001)
        XCTAssertEqual(quickScore.context, fullScore.context, accuracy: 0.001)
        XCTAssertEqual(quickScore.actionability, fullScore.actionability, accuracy: 0.001)
        XCTAssertEqual(quickScore.tokenEfficiency, fullScore.tokenEfficiency, accuracy: 0.001)
        XCTAssertEqual(quickScore.overallScore, fullScore.overallScore, accuracy: 0.001)
    }

    func testQuickAnalyzeDoesNotAffectHistory() {
        _ = manager.quickAnalyze("Quick test prompt")
        XCTAssertTrue(manager.history.isEmpty,
            "quickAnalyze should not add to history")
        XCTAssertNil(manager.lastScore,
            "quickAnalyze should not update lastScore")
    }

    // MARK: - Data Flow: Filter → Stats Consistency

    func testFilterAndStatsConsistency() {
        // Setup test data
        let bugPrompts = ["Fix login bug", "Fix signup bug", "Fix payment bug"]
        let featurePrompts = ["Add dark mode feature", "Add notification feature"]

        for prompt in bugPrompts {
            let rec = manager.recordPrompt(prompt)
            manager.recordCompletion(recordId: rec.id, success: true,
                                    duration: 3, tokenCount: 50, costUSD: 0.005)
        }
        for prompt in featurePrompts {
            let rec = manager.recordPrompt(prompt)
            manager.recordCompletion(recordId: rec.id, success: false,
                                    duration: 5, tokenCount: 80, costUSD: 0.008)
        }

        // Generate stats
        manager.generateGroupedStats()

        // Total across all categories should match total history
        let totalFromCategories = manager.categoryStats.reduce(0) { $0 + $1.count }
        // Note: a record can appear in multiple categories if it has multiple tags
        XCTAssertGreaterThanOrEqual(totalFromCategories, manager.history.count,
            "Category stats should account for all records (possibly counting multi-tagged records more than once)")

        // Filter and verify
        manager.setFilterTag("bug-fix")
        XCTAssertTrue(manager.filteredHistory.allSatisfy { $0.tags.contains("bug-fix") })

        manager.setFilterTag(nil)
        XCTAssertEqual(manager.filteredHistory.count, 5,
            "Should show all records when filter is cleared")
    }

    // MARK: - Persistence Round Trip

    func testPersistenceRoundTrip() {
        // Populate data
        manager.recordPrompt("Fix login bug")
        _ = manager.createABTest(task: "T", promptA: "A", promptB: "B")
        manager.saveVersion(promptId: "p1", content: "V1")

        let historyCount = manager.history.count
        let abCount = manager.abTests.count
        let versionCount = manager.versions.count

        // Simulate reload
        let manager2 = PromptOptimizationManager()
        XCTAssertEqual(manager2.history.count, historyCount)
        XCTAssertEqual(manager2.abTests.count, abCount)
        XCTAssertEqual(manager2.versions.count, versionCount)
    }

    // MARK: - Concurrent Quick Analyze Stability

    func testMultipleQuickAnalyzeCalls() {
        // Simulate rapid-fire analysis (like live typing)
        let prompts = [
            "F",
            "Fi",
            "Fix",
            "Fix t",
            "Fix th",
            "Fix the",
            "Fix the l",
            "Fix the lo",
            "Fix the log",
            "Fix the logi",
            "Fix the login",
            "Fix the login b",
            "Fix the login bu",
            "Fix the login bug",
        ]

        for prompt in prompts {
            let score = manager.quickAnalyze(prompt)
            XCTAssertGreaterThanOrEqual(score.overallScore, 0)
            XCTAssertLessThanOrEqual(score.overallScore, 1.0)
        }
    }

    // MARK: - Edge Cases

    func testEmptyPrompt() {
        let score = manager.analyzePrompt("")
        XCTAssertGreaterThanOrEqual(score.overallScore, 0)
        XCTAssertLessThanOrEqual(score.overallScore, 1.0)
    }

    func testVeryLongPrompt() {
        let longPrompt = String(repeating: "Fix the login bug. ", count: 100)
        let score = manager.analyzePrompt(longPrompt)
        XCTAssertGreaterThanOrEqual(score.overallScore, 0)
        XCTAssertLessThanOrEqual(score.overallScore, 1.0)
        XCTAssertGreaterThan(score.estimatedTokens, 100)
    }

    func testSpecialCharacters() {
        let prompt = "Fix the bug in `AuthService.swift`\nLine 42: `func login() -> Bool`\n\tTabbed content"
        let score = manager.analyzePrompt(prompt)
        XCTAssertGreaterThanOrEqual(score.overallScore, 0)
    }

    func testUnicodeContent() {
        let prompt = "修復 LoginService.swift 中的 OAuth2 驗證錯誤。目前使用者無法透過 Google 帳號登入。確保所有驗證流程正常運作。🔧"
        let score = manager.analyzePrompt(prompt)
        XCTAssertGreaterThanOrEqual(score.overallScore, 0)
        XCTAssertGreaterThan(score.estimatedTokens, 0)
    }

    func testRapidRecordAndCompleteCycle() {
        // Simulate rapid record-complete cycles with tag-triggering prompts
        for i in 0..<50 {
            let rec = manager.recordPrompt("Fix bug number \(i) in the test")
            manager.recordCompletion(recordId: rec.id, success: i % 2 == 0,
                                    duration: Double(i), tokenCount: i * 10, costUSD: Double(i) * 0.001)
        }

        XCTAssertEqual(manager.history.count, 50)
        manager.generateGroupedStats()
        XCTAssertFalse(manager.groupedStats.isEmpty)
        XCTAssertFalse(manager.categoryStats.isEmpty)
    }

    // MARK: - Cross-Component Data Integrity

    func testHistoryRecordMatchesAnalysisReport() {
        let prompt = "Fix the authentication bug"
        _ = manager.analyzePrompt(prompt)
        let record = manager.recordPrompt(prompt)

        // Record's score should match the analysis
        XCTAssertNotNil(record.qualityScore)
        XCTAssertNotNil(manager.lastReport)
        // They may not be exactly equal since analyzePrompt is called again in recordPrompt
        // But they should be consistent (same prompt → same scoring)
        if let recordClarity = record.qualityScore?.clarity,
           let lastClarity = manager.lastScore?.clarity {
            XCTAssertEqual(recordClarity, lastClarity, accuracy: 0.001)
        }
    }

    func testAntiPatternsMatchReport() {
        _ = manager.analyzePrompt("fix it and make it work as usual")
        let report = manager.lastReport!

        XCTAssertEqual(report.antiPatterns.count, manager.detectedAntiPatterns.count,
            "Report anti-patterns should match detected anti-patterns")
        XCTAssertEqual(report.suggestions.count, manager.suggestions.count,
            "Report suggestions should match manager suggestions")
    }

    func testScoreInReportMatchesLastScore() {
        let score = manager.analyzePrompt("Add dark mode to the app")
        XCTAssertEqual(manager.lastReport?.score.overallScore, score.overallScore)
        XCTAssertEqual(manager.lastScore?.overallScore, score.overallScore)
    }
}

// MARK: - Stress Tests

@MainActor
final class PromptOptimizationStressTests: XCTestCase {

    private var manager: PromptOptimizationManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationPatterns")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationABTests")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationVersions")
        manager = PromptOptimizationManager()
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationPatterns")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationABTests")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationVersions")
        super.tearDown()
    }

    func testBulkHistoryInsert() {
        // Insert 250 records (should be trimmed to 200)
        for i in 0..<250 {
            manager.recordPrompt("Bulk prompt \(i)")
        }
        XCTAssertLessThanOrEqual(manager.history.count, 200)
    }

    func testBulkCacheInsert() {
        // Insert 60 unique quick analyses (cache max is 50)
        for i in 0..<60 {
            _ = manager.quickAnalyze("Unique prompt variant \(i)")
        }
        // Cache should still work without crashes
        let score = manager.quickAnalyze("Final check prompt")
        XCTAssertGreaterThan(score.overallScore, 0)
    }

    func testBulkVersionInsert() {
        // Insert many versions across different prompts
        for i in 0..<100 {
            manager.saveVersion(promptId: "p\(i % 10)", content: "Content \(i)")
        }
        manager.pruneOldData()
        XCTAssertLessThanOrEqual(manager.versions.count, PromptOptimizationManager.maxVersions)
    }

    func testBulkABTestInsert() {
        for i in 0..<60 {
            _ = manager.createABTest(task: "Test \(i)", promptA: "A\(i)", promptB: "B\(i)")
        }
        manager.pruneOldData()
        XCTAssertLessThanOrEqual(manager.abTests.count, PromptOptimizationManager.maxABTests)
    }

    func testStatisticsWithLargeDataset() {
        for i in 0..<200 {
            let rec = manager.recordPrompt("Task \(i) fix the bug")
            manager.recordCompletion(recordId: rec.id, success: i % 3 != 0,
                                    duration: Double(i % 20), tokenCount: 30 + i % 100,
                                    costUSD: Double(i) * 0.001)
        }

        manager.setGrouping(.daily)
        XCTAssertFalse(manager.groupedStats.isEmpty)

        manager.setGrouping(.weekly)
        XCTAssertFalse(manager.groupedStats.isEmpty)

        manager.setGrouping(.monthly)
        XCTAssertFalse(manager.groupedStats.isEmpty)
    }
}
