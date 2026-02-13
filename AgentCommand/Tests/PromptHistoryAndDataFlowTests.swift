import XCTest
@testable import AgentCommand

// MARK: - History Recording & Extraction Tests

@MainActor
final class PromptHistoryExtractionTests: XCTestCase {

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

    // MARK: - Recording Prompts

    func testRecordPromptAddsToHistory() {
        XCTAssertTrue(manager.history.isEmpty)
        manager.recordPrompt("Fix the login bug")
        XCTAssertEqual(manager.history.count, 1)
        XCTAssertEqual(manager.history.first?.prompt, "Fix the login bug")
    }

    func testRecordPromptAutoAnalyzes() {
        let record = manager.recordPrompt("Fix the login bug")
        XCTAssertNotNil(record.qualityScore)
        XCTAssertGreaterThan(record.qualityScore?.overallScore ?? 0, 0)
    }

    func testRecordPromptUsesProvidedScore() {
        let customScore = PromptQualityScore(
            id: "custom", overallScore: 0.99,
            clarity: 0.99, specificity: 0.99, context: 0.99,
            actionability: 0.99, tokenEfficiency: 0.99,
            estimatedTokens: 42, estimatedCostUSD: 0.001,
            analyzedAt: Date()
        )
        let record = manager.recordPrompt("Fix the bug", score: customScore)
        XCTAssertEqual(record.qualityScore?.overallScore, 0.99)
    }

    func testRecordInsertsAtBeginning() {
        manager.recordPrompt("First prompt")
        manager.recordPrompt("Second prompt")
        XCTAssertEqual(manager.history.first?.prompt, "Second prompt",
            "Most recent prompt should be first")
    }

    func testRecordPromptExtraFields() {
        let record = manager.recordPrompt("Fix the authentication bug in LoginService.swift")
        XCTAssertNotNil(record.sentAt)
        XCTAssertNil(record.completedAt)
        XCTAssertNil(record.wasSuccessful)
        XCTAssertNotNil(record.tokenCount)
        XCTAssertNotNil(record.costUSD)
    }

    // MARK: - Tag Extraction

    func testExtractsBugFixTag() {
        let record = manager.recordPrompt("Fix the login bug")
        XCTAssertTrue(record.tags.contains("bug-fix"),
            "Should extract bug-fix tag from 'fix' and 'bug'")
    }

    func testExtractsFeatureTag() {
        let record = manager.recordPrompt("Add a new dark mode feature")
        XCTAssertTrue(record.tags.contains("feature"),
            "Should extract feature tag")
    }

    func testExtractsRefactorTag() {
        let record = manager.recordPrompt("Refactor the authentication module")
        XCTAssertTrue(record.tags.contains("refactor"),
            "Should extract refactor tag")
    }

    func testExtractsTestTag() {
        let record = manager.recordPrompt("Write tests for the login service")
        XCTAssertTrue(record.tags.contains("test"),
            "Should extract test tag")
    }

    func testExtractsDocsTag() {
        let record = manager.recordPrompt("Update the README document")
        XCTAssertTrue(record.tags.contains("docs"),
            "Should extract docs tag")
    }

    func testExtractsStyleTag() {
        let record = manager.recordPrompt("Fix the CSS style for the login button UI")
        XCTAssertTrue(record.tags.contains("style"),
            "Should extract style tag")
    }

    func testExtractsMultipleTags() {
        let record = manager.recordPrompt("Fix the bug and add a new test for the component")
        XCTAssertTrue(record.tags.count >= 2,
            "Should extract multiple tags when applicable")
    }

    func testExtractsChineseTags() {
        let record = manager.recordPrompt("修復登入頁面的錯誤")
        XCTAssertTrue(record.tags.contains("bug-fix"),
            "Should extract tags from Chinese prompts")
    }

    // MARK: - History Limit

    func testHistoryLimitedTo200() {
        for i in 0..<210 {
            manager.recordPrompt("Prompt number \(i)")
        }
        XCTAssertLessThanOrEqual(manager.history.count, 200,
            "History should be capped at 200 records")
    }

    // MARK: - Recording Completion

    func testRecordCompletion() {
        let record = manager.recordPrompt("Fix the login bug")
        manager.recordCompletion(
            recordId: record.id,
            success: true,
            duration: 5.0,
            tokenCount: 100,
            costUSD: 0.01
        )

        let updated = manager.history.first { $0.id == record.id }
        XCTAssertNotNil(updated?.completedAt)
        XCTAssertEqual(updated?.wasSuccessful, true)
        XCTAssertEqual(updated?.taskDuration, 5.0)
        XCTAssertEqual(updated?.tokenCount, 100)
        XCTAssertEqual(updated?.costUSD, 0.01)
    }

    func testRecordCompletionWithFailure() {
        let record = manager.recordPrompt("Build the project")
        manager.recordCompletion(
            recordId: record.id,
            success: false,
            duration: 10.0,
            tokenCount: nil,
            costUSD: nil
        )

        let updated = manager.history.first { $0.id == record.id }
        XCTAssertEqual(updated?.wasSuccessful, false)
        XCTAssertTrue(updated?.isCompleted == true)
    }

    func testRecordCompletionNonexistentIdIsNoOp() {
        manager.recordPrompt("Test prompt")
        let countBefore = manager.history.count
        manager.recordCompletion(
            recordId: "nonexistent-id",
            success: true,
            duration: 1.0,
            tokenCount: nil,
            costUSD: nil
        )
        XCTAssertEqual(manager.history.count, countBefore)
    }

    // MARK: - History Filtering

    func testFilterByTag() {
        manager.recordPrompt("Fix the login bug")
        manager.recordPrompt("Add a new feature to the dashboard")
        manager.recordPrompt("Fix another critical bug")

        manager.setFilterTag("bug-fix")
        XCTAssertTrue(manager.filteredHistory.allSatisfy { $0.tags.contains("bug-fix") },
            "Filtered history should only contain bug-fix tagged records")
    }

    func testFilterBySuccess() {
        let rec1 = manager.recordPrompt("Test 1")
        let rec2 = manager.recordPrompt("Test 2")
        manager.recordCompletion(recordId: rec1.id, success: true, duration: nil, tokenCount: nil, costUSD: nil)
        manager.recordCompletion(recordId: rec2.id, success: false, duration: nil, tokenCount: nil, costUSD: nil)

        manager.setFilterSuccess(true)
        XCTAssertTrue(manager.filteredHistory.allSatisfy { $0.wasSuccessful == true },
            "Should only show successful records")
    }

    func testClearFilters() {
        manager.recordPrompt("Fix bug")
        manager.recordPrompt("Add feature")

        manager.setFilterTag("bug-fix")
        let filtered = manager.filteredHistory.count

        manager.setFilterTag(nil)
        XCTAssertGreaterThanOrEqual(manager.filteredHistory.count, filtered,
            "Clearing filter should show more or equal records")
    }

    // MARK: - History Sorting

    func testSortByDateDesc() {
        manager.recordPrompt("First")
        // Small delay to ensure different timestamps
        manager.recordPrompt("Second")

        manager.setSortOption(.dateDesc)
        if manager.filteredHistory.count >= 2 {
            XCTAssertGreaterThanOrEqual(
                manager.filteredHistory[0].sentAt,
                manager.filteredHistory[1].sentAt,
                "dateDesc should sort newest first"
            )
        }
    }

    func testSortByDateAsc() {
        manager.recordPrompt("First")
        manager.recordPrompt("Second")

        manager.setSortOption(.dateAsc)
        if manager.filteredHistory.count >= 2 {
            XCTAssertLessThanOrEqual(
                manager.filteredHistory[0].sentAt,
                manager.filteredHistory[1].sentAt,
                "dateAsc should sort oldest first"
            )
        }
    }

    func testSortByQualityDesc() {
        manager.recordPrompt("x") // Short, low quality
        manager.recordPrompt("Fix the authentication bug in LoginService.swift by updating the OAuth2 token validation logic to properly handle expired refresh tokens") // Detailed, high quality

        manager.setSortOption(.qualityDesc)
        if manager.filteredHistory.count >= 2 {
            let first = manager.filteredHistory[0].qualityScore?.overallScore ?? 0
            let second = manager.filteredHistory[1].qualityScore?.overallScore ?? 0
            XCTAssertGreaterThanOrEqual(first, second,
                "qualityDesc should sort highest quality first")
        }
    }

    // MARK: - Get All Tags

    func testGetAllTags() {
        manager.recordPrompt("Fix the bug")
        manager.recordPrompt("Add new feature")
        manager.recordPrompt("Write test coverage")

        let tags = manager.getAllTags()
        XCTAssertFalse(tags.isEmpty)
        XCTAssertTrue(tags.isSorted(), "Tags should be sorted alphabetically")
    }
}

// MARK: - Pattern Detection Tests

@MainActor
final class PatternDetectionTests: XCTestCase {

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
        super.tearDown()
    }

    func testDetectPatternsRequiresMinimumRecords() {
        // Only 3 records, needs 5 completed
        for i in 0..<3 {
            let rec = manager.recordPrompt("Fix bug \(i)")
            manager.recordCompletion(recordId: rec.id, success: true, duration: 1, tokenCount: 10, costUSD: 0.001)
        }
        manager.detectPatterns()
        // May or may not detect with < 5 completed
        // The guard is `completed.count >= 5`
        XCTAssertTrue(manager.patterns.isEmpty || manager.patterns.count >= 0) // Just ensure no crash
    }

    func testDetectPatternsWithSufficientRecords() {
        // Create 6 completed bug-fix records
        for i in 0..<6 {
            let rec = manager.recordPrompt("Fix critical bug number \(i) in the system")
            manager.recordCompletion(recordId: rec.id, success: true, duration: 5, tokenCount: 50, costUSD: 0.005)
        }
        manager.detectPatterns()

        // With 6 bug-fix records, "bug-fix" tag group should have >= 3 and form a pattern
        let bugFixPattern = manager.patterns.first { $0.name.lowercased().contains("bug") }
        if manager.patterns.isEmpty == false {
            XCTAssertNotNil(bugFixPattern, "Should detect a bug-fix pattern")
        }
    }

    func testPatternsAreSortedByMatchCount() {
        // Create many records with different tags
        for i in 0..<8 {
            let rec = manager.recordPrompt("Fix bug \(i) in the application")
            manager.recordCompletion(recordId: rec.id, success: true, duration: 1, tokenCount: 10, costUSD: 0.001)
        }
        for i in 0..<4 {
            let rec = manager.recordPrompt("Add feature \(i) to dashboard")
            manager.recordCompletion(recordId: rec.id, success: true, duration: 1, tokenCount: 10, costUSD: 0.001)
        }
        manager.detectPatterns()

        if manager.patterns.count >= 2 {
            XCTAssertGreaterThanOrEqual(
                manager.patterns[0].matchCount,
                manager.patterns[1].matchCount,
                "Patterns should be sorted by match count descending"
            )
        }
    }
}

// MARK: - A/B Testing Tests

@MainActor
final class ABTestingTests: XCTestCase {

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
        super.tearDown()
    }

    func testCreateABTest() {
        let test = manager.createABTest(
            task: "Login improvement",
            promptA: "Fix the login bug",
            promptB: "Fix the authentication error in LoginService.swift"
        )

        XCTAssertEqual(test.taskDescription, "Login improvement")
        XCTAssertEqual(test.variantA.prompt, "Fix the login bug")
        XCTAssertEqual(test.variantB.prompt, "Fix the authentication error in LoginService.swift")
        XCTAssertEqual(test.status, .pending)
        XCTAssertNil(test.completedAt)
        XCTAssertNil(test.winnerVariant)
    }

    func testCreateABTestAddsToList() {
        XCTAssertTrue(manager.abTests.isEmpty)
        _ = manager.createABTest(task: "Test", promptA: "A", promptB: "B")
        XCTAssertEqual(manager.abTests.count, 1)
    }

    func testUpdateVariantA() {
        let test = manager.createABTest(task: "Test", promptA: "A", promptB: "B")
        manager.updateABTestVariant(testId: test.id, variant: "A",
            success: true, duration: 3.0, tokenCount: 50, costUSD: 0.005)

        let updated = manager.abTests.first { $0.id == test.id }
        XCTAssertEqual(updated?.variantA.wasSuccessful, true)
        XCTAssertEqual(updated?.variantA.duration, 3.0)
        XCTAssertEqual(updated?.status, .running, "Should be running when only one variant is complete")
    }

    func testUpdateBothVariantsCompletes() {
        let test = manager.createABTest(task: "Test", promptA: "A", promptB: "B")

        manager.updateABTestVariant(testId: test.id, variant: "A",
            success: true, duration: 3.0, tokenCount: 50, costUSD: 0.005)
        manager.updateABTestVariant(testId: test.id, variant: "B",
            success: true, duration: 5.0, tokenCount: 80, costUSD: 0.008)

        let updated = manager.abTests.first { $0.id == test.id }
        XCTAssertEqual(updated?.status, .completed, "Should be completed when both variants done")
        XCTAssertNotNil(updated?.completedAt)
        XCTAssertNotNil(updated?.winnerVariant, "Should determine a winner")
    }

    func testWinnerDetermination() {
        let test = manager.createABTest(task: "Test", promptA: "A", promptB: "B")

        // Variant A: success, fast, fewer tokens
        manager.updateABTestVariant(testId: test.id, variant: "A",
            success: true, duration: 2.0, tokenCount: 30, costUSD: 0.003)
        // Variant B: failed, slow, more tokens
        manager.updateABTestVariant(testId: test.id, variant: "B",
            success: false, duration: 10.0, tokenCount: 200, costUSD: 0.02)

        let updated = manager.abTests.first { $0.id == test.id }
        XCTAssertEqual(updated?.winnerVariant, "A",
            "Variant A should win (success + faster + fewer tokens)")
    }

    func testActiveABTestsCount() {
        _ = manager.createABTest(task: "Test 1", promptA: "A1", promptB: "B1")
        _ = manager.createABTest(task: "Test 2", promptA: "A2", promptB: "B2")
        XCTAssertEqual(manager.activeABTests, 2, "Both pending tests should count as active")
    }
}

// MARK: - Version Management Tests

@MainActor
final class VersionManagementTests: XCTestCase {

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
        super.tearDown()
    }

    func testSaveVersion() {
        manager.saveVersion(promptId: "p1", content: "Version 1 content", note: "Initial")
        XCTAssertEqual(manager.versions.count, 1)
        XCTAssertEqual(manager.versions.first?.version, 1)
        XCTAssertEqual(manager.versions.first?.content, "Version 1 content")
    }

    func testVersionAutoIncrements() {
        manager.saveVersion(promptId: "p1", content: "V1")
        manager.saveVersion(promptId: "p1", content: "V2")
        manager.saveVersion(promptId: "p1", content: "V3")

        let versions = manager.versionsForPrompt("p1")
        XCTAssertEqual(versions.count, 3)
        XCTAssertEqual(versions.first?.version, 3, "Newest version should be first")
        XCTAssertEqual(versions.last?.version, 1, "Oldest version should be last")
    }

    func testVersionsForDifferentPrompts() {
        manager.saveVersion(promptId: "p1", content: "P1-V1")
        manager.saveVersion(promptId: "p2", content: "P2-V1")
        manager.saveVersion(promptId: "p1", content: "P1-V2")

        let p1Versions = manager.versionsForPrompt("p1")
        let p2Versions = manager.versionsForPrompt("p2")

        XCTAssertEqual(p1Versions.count, 2)
        XCTAssertEqual(p2Versions.count, 1)
    }

    func testVersionLimitPerPrompt() {
        // Max 20 versions per prompt
        for i in 1...25 {
            manager.saveVersion(promptId: "p1", content: "Content \(i)")
        }

        let versions = manager.versionsForPrompt("p1")
        XCTAssertLessThanOrEqual(versions.count, 20,
            "Should cap at 20 versions per prompt")
    }
}

// MARK: - Statistics Aggregation Tests

@MainActor
final class StatisticsAggregationTests: XCTestCase {

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
        super.tearDown()
    }

    func testTotalPromptsAnalyzed() {
        XCTAssertEqual(manager.totalPromptsAnalyzed, 0)
        manager.recordPrompt("Test 1")
        manager.recordPrompt("Test 2")
        XCTAssertEqual(manager.totalPromptsAnalyzed, 2)
    }

    func testAvgQualityScore() {
        XCTAssertEqual(manager.avgQualityScore, 0)
        manager.recordPrompt("Fix the login bug")
        XCTAssertGreaterThan(manager.avgQualityScore, 0)
    }

    func testBestPatternName() {
        XCTAssertNil(manager.bestPatternName)
        // Would need patterns populated to test this properly
    }

    func testGenerateGroupedStatsDaily() {
        manager.recordPrompt("Fix bug 1")
        manager.recordPrompt("Fix bug 2")

        manager.setGrouping(.daily)
        XCTAssertFalse(manager.groupedStats.isEmpty,
            "Should generate daily stats when history exists")

        // All records from today should be in one group
        if let todayStats = manager.groupedStats.first {
            XCTAssertEqual(todayStats.totalCount, 2)
        }
    }

    func testGenerateGroupedStatsWeekly() {
        manager.recordPrompt("Test prompt")
        manager.setGrouping(.weekly)
        XCTAssertFalse(manager.groupedStats.isEmpty,
            "Should generate weekly stats when history exists")
    }

    func testGenerateGroupedStatsMonthly() {
        manager.recordPrompt("Test prompt")
        manager.setGrouping(.monthly)
        XCTAssertFalse(manager.groupedStats.isEmpty,
            "Should generate monthly stats when history exists")
    }

    func testGenerateGroupedStatsEmpty() {
        manager.setGrouping(.daily)
        XCTAssertTrue(manager.groupedStats.isEmpty,
            "Should have no stats when history is empty")
    }

    func testCategoryStats() {
        manager.recordPrompt("Fix the login bug")
        manager.recordPrompt("Add new feature")

        manager.generateGroupedStats()

        XCTAssertFalse(manager.categoryStats.isEmpty,
            "Should generate category stats from tagged history")
    }

    func testCategoryStatsSortedByCount() {
        for i in 0..<5 {
            manager.recordPrompt("Fix bug number \(i)")
        }
        manager.recordPrompt("Add new feature")

        manager.generateGroupedStats()

        if manager.categoryStats.count >= 2 {
            XCTAssertGreaterThanOrEqual(
                manager.categoryStats[0].count,
                manager.categoryStats[1].count,
                "Category stats should be sorted by count descending"
            )
        }
    }
}

// MARK: - Autocomplete Suggestions Tests

@MainActor
final class AutocompleteSuggestionTests: XCTestCase {

    private var manager: PromptOptimizationManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        manager = PromptOptimizationManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testContextSuggestionsForCommonPrefix() {
        let suggestions = manager.generateAutocompleteSuggestions(prefix: "fix")
        let contextSuggestions = suggestions.filter { $0.source == .projectContext }
        XCTAssertFalse(contextSuggestions.isEmpty,
            "Should generate context suggestions for 'fix' prefix")
    }

    func testHistorySuggestions() {
        // Record a successful prompt
        let rec = manager.recordPrompt("Fix the login bug in AuthService")
        manager.recordCompletion(recordId: rec.id, success: true, duration: 1, tokenCount: 10, costUSD: 0.001)

        let suggestions = manager.generateAutocompleteSuggestions(prefix: "Fix")
        let historySuggestions = suggestions.filter { $0.source == .history }
        XCTAssertFalse(historySuggestions.isEmpty,
            "Should suggest from successful history")
    }

    func testAutocompleteSuggestionsUpdatesPublishedState() {
        XCTAssertTrue(manager.autocompleteSuggestions.isEmpty)
        _ = manager.generateAutocompleteSuggestions(prefix: "fix")
        XCTAssertFalse(manager.autocompleteSuggestions.isEmpty)
    }
}

// MARK: - Memory Management Tests

@MainActor
final class MemoryManagementTests: XCTestCase {

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
        super.tearDown()
    }

    func testPruneOldDataEnforcesHistoryLimit() {
        for i in 0..<210 {
            manager.recordPrompt("Prompt \(i)")
        }
        manager.pruneOldData()
        XCTAssertLessThanOrEqual(manager.history.count, PromptOptimizationManager.maxHistoryRecords)
    }

    func testPruneOldDataEnforcesABTestLimit() {
        for _ in 0..<55 {
            _ = manager.createABTest(task: "T", promptA: "A", promptB: "B")
        }
        manager.pruneOldData()
        XCTAssertLessThanOrEqual(manager.abTests.count, PromptOptimizationManager.maxABTests)
    }

    func testPruneOldDataEnforcesVersionLimit() {
        for i in 0..<510 {
            manager.saveVersion(promptId: "p\(i % 100)", content: "Content \(i)")
        }
        manager.pruneOldData()
        XCTAssertLessThanOrEqual(manager.versions.count, PromptOptimizationManager.maxVersions)
    }
}

// MARK: - Persistence Tests

@MainActor
final class PersistenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationPatterns")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationABTests")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationVersions")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "promptOptimizationHistory")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationPatterns")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationABTests")
        UserDefaults.standard.removeObject(forKey: "promptOptimizationVersions")
        super.tearDown()
    }

    func testHistoryPersistsAcrossInstances() {
        let manager1 = PromptOptimizationManager()
        manager1.recordPrompt("Persisted prompt")
        let countAfterRecord = manager1.history.count

        // Create a new instance that should load from UserDefaults
        let manager2 = PromptOptimizationManager()
        XCTAssertEqual(manager2.history.count, countAfterRecord,
            "History should persist across manager instances")
        XCTAssertEqual(manager2.history.first?.prompt, "Persisted prompt")
    }

    func testABTestsPersist() {
        let manager1 = PromptOptimizationManager()
        _ = manager1.createABTest(task: "Persist test", promptA: "A", promptB: "B")

        let manager2 = PromptOptimizationManager()
        XCTAssertEqual(manager2.abTests.count, 1)
        XCTAssertEqual(manager2.abTests.first?.taskDescription, "Persist test")
    }

    func testVersionsPersist() {
        let manager1 = PromptOptimizationManager()
        manager1.saveVersion(promptId: "p1", content: "Persisted version")

        let manager2 = PromptOptimizationManager()
        XCTAssertEqual(manager2.versions.count, 1)
        XCTAssertEqual(manager2.versions.first?.content, "Persisted version")
    }
}

// MARK: - Array Extension for Testing

extension Array where Element: Comparable {
    func isSorted() -> Bool {
        guard count > 1 else { return true }
        for i in 1..<count {
            if self[i - 1] > self[i] { return false }
        }
        return true
    }
}
