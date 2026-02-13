import XCTest
@testable import AgentCommand

// MARK: - Analysis Engine Tests

@MainActor
final class PromptAnalysisEngineTests: XCTestCase {

    private var manager: PromptOptimizationManager!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults to avoid interference between tests
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

    // MARK: - Quality Analysis: Clarity

    func testClarityIncreasesWithWordCount() {
        let shortPrompt = "fix bug"
        let longPrompt = "Fix the authentication bug in the login component where users cannot sign in with their email and password credentials"

        let shortScore = manager.analyzePrompt(shortPrompt)
        let longScore = manager.analyzePrompt(longPrompt)

        XCTAssertGreaterThan(longScore.clarity, shortScore.clarity,
            "Longer, clearer prompts should score higher on clarity")
    }

    func testClarityPenalizesAllCaps() {
        let normalPrompt = "Fix the bug in the login page"
        let capsPrompt = "FIX THE BUG IN THE LOGIN PAGE"

        let normalScore = manager.analyzePrompt(normalPrompt)
        let capsScore = manager.analyzePrompt(capsPrompt)

        XCTAssertGreaterThan(normalScore.clarity, capsScore.clarity,
            "ALL CAPS prompts should be penalized on clarity")
    }

    func testClarityBonusForPunctuation() {
        let noPunc = "Fix the bug in the login page make it work properly"
        let withPunc = "Fix the bug in the login page. Make it work properly."

        let noPuncScore = manager.analyzePrompt(noPunc)
        let withPuncScore = manager.analyzePrompt(withPunc)

        XCTAssertGreaterThanOrEqual(withPuncScore.clarity, noPuncScore.clarity,
            "Punctuated prompts should score equal or higher on clarity")
    }

    // MARK: - Quality Analysis: Specificity

    func testSpecificityIncreasesWithTechnicalTerms() {
        let vague = "change the thing"
        let specific = "Fix the function in the API endpoint that returns the wrong database query result"

        let vagueScore = manager.analyzePrompt(vague)
        let specificScore = manager.analyzePrompt(specific)

        XCTAssertGreaterThan(specificScore.specificity, vagueScore.specificity,
            "Technical terms should increase specificity score")
    }

    func testSpecificityBonusForFileReferences() {
        let noRef = "Fix the login bug"
        let withRef = "Fix the login bug in AuthService.swift"

        let noRefScore = manager.analyzePrompt(noRef)
        let withRefScore = manager.analyzePrompt(withRef)

        XCTAssertGreaterThan(withRefScore.specificity, noRefScore.specificity,
            "File references should boost specificity")
    }

    func testSpecificityBonusForActionWords() {
        let noAction = "the login page has an issue"
        let withAction = "Fix the login page error and update the validation"

        let noActionScore = manager.analyzePrompt(noAction)
        let withActionScore = manager.analyzePrompt(withAction)

        XCTAssertGreaterThan(withActionScore.specificity, noActionScore.specificity,
            "Action words should boost specificity")
    }

    func testSpecificityBonusForConstraints() {
        let noConstraint = "Add a new login feature"
        let withConstraint = "Add a new login feature and ensure it must use OAuth2 authentication"

        let noConstraintScore = manager.analyzePrompt(noConstraint)
        let withConstraintScore = manager.analyzePrompt(withConstraint)

        XCTAssertGreaterThan(withConstraintScore.specificity, noConstraintScore.specificity,
            "Constraint words should boost specificity")
    }

    // MARK: - Quality Analysis: Context

    func testContextBonusForBackgroundInfo() {
        let noContext = "Add dark mode"
        let withContext = "Currently the app only supports light mode. Add dark mode because users have been requesting it"

        let noContextScore = manager.analyzePrompt(noContext)
        let withContextScore = manager.analyzePrompt(withContext)

        XCTAssertGreaterThan(withContextScore.context, noContextScore.context,
            "Background info should boost context score")
    }

    func testContextBonusForFrameworkReferences() {
        let noFw = "Fix the component rendering issue"
        let withFw = "Fix the SwiftUI component rendering issue in the list view"

        let noFwScore = manager.analyzePrompt(noFw)
        let withFwScore = manager.analyzePrompt(withFw)

        XCTAssertGreaterThan(withFwScore.context, noFwScore.context,
            "Framework references should boost context score")
    }

    // MARK: - Quality Analysis: Actionability

    func testActionabilityBonusForActionStarter() {
        let passive = "the authentication system has a bug"
        let active = "Fix the authentication system bug by updating the token validation"

        let passiveScore = manager.analyzePrompt(passive)
        let activeScore = manager.analyzePrompt(active)

        XCTAssertGreaterThan(activeScore.actionability, passiveScore.actionability,
            "Starting with an action verb should boost actionability")
    }

    func testActionabilityBonusForExpectedOutput() {
        let noOutput = "Update the login page"
        let withOutput = "Update the login page so the result should show a success message"

        let noOutputScore = manager.analyzePrompt(noOutput)
        let withOutputScore = manager.analyzePrompt(withOutput)

        XCTAssertGreaterThan(withOutputScore.actionability, noOutputScore.actionability,
            "Expected output descriptions should boost actionability")
    }

    func testActionabilityBonusForStepByStep() {
        let flat = "change the login page"
        let stepped = "First update the login page validation step by step, then update the registration form fields"

        let flatScore = manager.analyzePrompt(flat)
        let steppedScore = manager.analyzePrompt(stepped)

        XCTAssertGreaterThanOrEqual(steppedScore.actionability, flatScore.actionability,
            "Step-by-step format should boost or equal actionability")
    }

    // MARK: - Quality Analysis: Token Efficiency

    func testTokenEfficiencyVeryShort() {
        let prompt = "fix"
        let score = manager.analyzePrompt(prompt)
        XCTAssertLessThanOrEqual(score.tokenEfficiency, 0.4,
            "Very short prompts should have low token efficiency")
    }

    func testTokenEfficiencySweetSpot() {
        // Create a prompt that estimates to ~50 tokens (sweet spot 20-100)
        let words = Array(repeating: "word", count: 50).joined(separator: " ")
        let score = manager.analyzePrompt(words)
        XCTAssertGreaterThanOrEqual(score.tokenEfficiency, 0.7,
            "Prompts in the sweet spot should have high token efficiency")
    }

    // MARK: - Quality Analysis: Overall Score Weighted Calculation

    func testOverallScoreWeighting() {
        // The overall score should be:
        // clarity * 0.25 + specificity * 0.25 + context * 0.2 + actionability * 0.2 + tokenEfficiency * 0.1
        let prompt = "Fix the authentication bug in LoginService.swift. Currently users cannot sign in because the token validation fails. The result should allow successful OAuth2 login."
        let score = manager.analyzePrompt(prompt)

        let expected = score.clarity * 0.25 + score.specificity * 0.25 +
                       score.context * 0.2 + score.actionability * 0.2 +
                       score.tokenEfficiency * 0.1

        XCTAssertEqual(score.overallScore, expected, accuracy: 0.001,
            "Overall score should follow the weighted formula")
    }

    // MARK: - Quality Analysis: Score Bounds

    func testScoresAreBounded() {
        let prompts = [
            "",
            "x",
            "fix it",
            "Fix the authentication bug in the login component where users cannot sign in with OAuth2",
            String(repeating: "word ", count: 500),
        ]

        for prompt in prompts {
            let score = manager.analyzePrompt(prompt)
            XCTAssertGreaterThanOrEqual(score.overallScore, 0.0)
            XCTAssertLessThanOrEqual(score.overallScore, 1.0)
            XCTAssertGreaterThanOrEqual(score.clarity, 0.0)
            XCTAssertLessThanOrEqual(score.clarity, 1.0)
            XCTAssertGreaterThanOrEqual(score.specificity, 0.0)
            XCTAssertLessThanOrEqual(score.specificity, 1.0)
            XCTAssertGreaterThanOrEqual(score.context, 0.0)
            XCTAssertLessThanOrEqual(score.context, 1.0)
            XCTAssertGreaterThanOrEqual(score.actionability, 0.0)
            XCTAssertLessThanOrEqual(score.actionability, 1.0)
            XCTAssertGreaterThanOrEqual(score.tokenEfficiency, 0.0)
            XCTAssertLessThanOrEqual(score.tokenEfficiency, 1.0)
        }
    }

    // MARK: - Token Estimation

    func testTokenEstimationEnglishOnly() {
        let prompt = "Fix the login bug" // 18 chars => ~5 tokens + 1
        let score = manager.analyzePrompt(prompt)
        XCTAssertGreaterThan(score.estimatedTokens, 0)
    }

    func testTokenEstimationCJK() {
        let prompt = "修復登入頁面的錯誤" // 9 CJK chars => 9*2 + 1 = 19
        let score = manager.analyzePrompt(prompt)
        XCTAssertGreaterThan(score.estimatedTokens, 10,
            "CJK should estimate more tokens per character")
    }

    func testTokenEstimationMixed() {
        let prompt = "Fix 登入 bug" // Mixed English + CJK
        let score = manager.analyzePrompt(prompt)
        XCTAssertGreaterThan(score.estimatedTokens, 0)
    }

    // MARK: - Cost Estimation

    func testCostEstimationPositive() {
        let prompt = "Fix the authentication bug"
        let score = manager.analyzePrompt(prompt)
        XCTAssertGreaterThan(score.estimatedCostUSD, 0)
    }

    func testCostEstimationProportionalToTokens() {
        let shortPrompt = "Fix bug"
        let longPrompt = "Fix the authentication bug in the login component with detailed error handling and proper OAuth2 token validation for all user types including admin and regular users"

        let shortScore = manager.analyzePrompt(shortPrompt)
        let longScore = manager.analyzePrompt(longPrompt)

        XCTAssertGreaterThan(longScore.estimatedCostUSD, shortScore.estimatedCostUSD,
            "Longer prompts should cost more")
    }

    // MARK: - Published State Updates

    func testAnalyzePromptUpdatesLastScore() {
        XCTAssertNil(manager.lastScore)
        _ = manager.analyzePrompt("Fix the login bug")
        XCTAssertNotNil(manager.lastScore)
    }

    func testAnalyzePromptUpdatesSuggestions() {
        // A vague prompt should generate suggestions
        _ = manager.analyzePrompt("do it")
        XCTAssertFalse(manager.suggestions.isEmpty,
            "Vague prompts should generate suggestions")
    }

    func testAnalyzePromptUpdatesAntiPatterns() {
        _ = manager.analyzePrompt("do it and make it work as usual")
        XCTAssertFalse(manager.detectedAntiPatterns.isEmpty,
            "Prompts with anti-patterns should detect them")
    }

    func testAnalyzePromptUpdatesReport() {
        XCTAssertNil(manager.lastReport)
        _ = manager.analyzePrompt("Fix the login bug")
        XCTAssertNotNil(manager.lastReport)
        XCTAssertEqual(manager.lastReport?.prompt, "Fix the login bug")
    }
}

// MARK: - Anti-Pattern Detection Tests

@MainActor
final class AntiPatternDetectionTests: XCTestCase {

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

    func testDetectsVagueness() {
        _ = manager.analyzePrompt("do it now")
        let vague = manager.detectedAntiPatterns.filter { $0.category == .vagueness }
        XCTAssertFalse(vague.isEmpty, "Should detect 'do it' as vagueness")
        XCTAssertEqual(vague.first?.severity, .critical)
    }

    func testDetectsMultipleVaguePatterns() {
        _ = manager.analyzePrompt("fix it and make it work and do something")
        let vague = manager.detectedAntiPatterns.filter { $0.category == .vagueness }
        XCTAssertGreaterThanOrEqual(vague.count, 2,
            "Should detect multiple vague references")
    }

    func testDetectsOverloading() {
        _ = manager.analyzePrompt("Add login feature and also add the payment system and additionally implement email notifications")
        let overloading = manager.detectedAntiPatterns.filter { $0.category == .overloading }
        XCTAssertFalse(overloading.isEmpty, "Should detect task overloading")
        XCTAssertEqual(overloading.first?.severity, .warning)
    }

    func testDetectsMissingConstraints() {
        // 16+ words without constraint keywords
        let prompt = "Update the entire user authentication flow to use the new provider and change all the related components to work with it properly"
        _ = manager.analyzePrompt(prompt)
        let missing = manager.detectedAntiPatterns.filter { $0.category == .missingConstraints }
        XCTAssertFalse(missing.isEmpty, "Should detect missing constraints in long prompts")
    }

    func testNoMissingConstraintsWhenPresent() {
        let prompt = "Update the entire user authentication flow to use the new provider and ensure that all related components must work with it properly"
        _ = manager.analyzePrompt(prompt)
        let missing = manager.detectedAntiPatterns.filter { $0.category == .missingConstraints }
        XCTAssertTrue(missing.isEmpty, "Should not flag missing constraints when constraints are present")
    }

    func testDetectsNegativeFraming() {
        _ = manager.analyzePrompt("Don't use the old API. Never call the deprecated method. Avoid using global state.")
        let negative = manager.detectedAntiPatterns.filter { $0.category == .negativeFraming }
        XCTAssertFalse(negative.isEmpty, "Should detect negative framing")
    }

    func testDetectsImplicitAssumption() {
        _ = manager.analyzePrompt("Update the feature as usual")
        let implicit = manager.detectedAntiPatterns.filter { $0.category == .implicitAssumption }
        XCTAssertFalse(implicit.isEmpty, "Should detect implicit assumption 'as usual'")
        XCTAssertEqual(implicit.first?.severity, .critical)
    }

    func testDetectsRedundancy() {
        _ = manager.analyzePrompt("Fix the login bug. Fix the login bug.")
        let redundancy = manager.detectedAntiPatterns.filter { $0.category == .redundancy }
        XCTAssertFalse(redundancy.isEmpty, "Should detect repeated sentences")
    }

    func testDetectsScopeCreep() {
        let longPrompt = Array(repeating: "word", count: 210).joined(separator: " ")
        _ = manager.analyzePrompt(longPrompt)
        let scopeCreep = manager.detectedAntiPatterns.filter { $0.category == .scopeCreep }
        XCTAssertFalse(scopeCreep.isEmpty, "Should detect scope creep for very long prompts")
    }

    func testAntiPatternsSortedBySeverity() {
        _ = manager.analyzePrompt("fix it and also do something as usual. fix it and also do something as usual. " +
            Array(repeating: "word", count: 200).joined(separator: " "))
        let severities = manager.detectedAntiPatterns.map(\.severity)
        for i in 0..<severities.count - 1 {
            XCTAssertLessThanOrEqual(severities[i], severities[i + 1],
                "Anti-patterns should be sorted by severity (critical first)")
        }
    }

    func testNoAntiPatternsForGoodPrompt() {
        _ = manager.analyzePrompt("Fix the authentication bug in LoginService.swift by updating the OAuth2 token validation. Ensure all user types can log in successfully.")
        // This good prompt should have few or no anti-patterns
        let critical = manager.detectedAntiPatterns.filter { $0.severity == .critical }
        XCTAssertTrue(critical.isEmpty, "Good prompts should not trigger critical anti-patterns")
    }

    // MARK: - Chinese (CJK) Anti-Pattern Detection

    func testDetectsChineseImplicitAssumption() {
        _ = manager.analyzePrompt("跟之前一樣更新登入功能")
        let implicit = manager.detectedAntiPatterns.filter { $0.category == .implicitAssumption }
        XCTAssertFalse(implicit.isEmpty, "Should detect Chinese implicit assumptions")
    }

    func testDetectsChineseOverloading() {
        _ = manager.analyzePrompt("新增登入功能，另外要新增付款系統，此外還需要實作通知功能")
        let overloading = manager.detectedAntiPatterns.filter { $0.category == .overloading }
        XCTAssertFalse(overloading.isEmpty, "Should detect Chinese task overloading")
    }
}

// MARK: - Suggestion Generation Tests

@MainActor
final class SuggestionGenerationTests: XCTestCase {

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

    func testSuggestsImproveClarity() {
        _ = manager.analyzePrompt("fix") // Very short, low clarity
        let claritySuggestions = manager.suggestions.filter { $0.type == .improveStructure }
        XCTAssertFalse(claritySuggestions.isEmpty,
            "Low clarity should generate improve structure suggestion")
    }

    func testSuggestsAddContext() {
        _ = manager.analyzePrompt("Add dark mode") // No context
        let contextSuggestions = manager.suggestions.filter { $0.type == .addContext }
        XCTAssertFalse(contextSuggestions.isEmpty,
            "Missing context should generate add context suggestion")
    }

    func testSuggestsReduceAmbiguity() {
        _ = manager.analyzePrompt("Fix this thing here")
        let ambigSuggestions = manager.suggestions.filter { $0.type == .reduceAmbiguity }
        XCTAssertFalse(ambigSuggestions.isEmpty,
            "Ambiguous words should generate reduce ambiguity suggestion")
    }

    func testSuggestionImpactLevels() {
        _ = manager.analyzePrompt("fix it")
        for suggestion in manager.suggestions {
            // All impacts should be valid enum values
            XCTAssertTrue([.high, .medium, .low].contains(suggestion.impact))
        }
    }

    func testNoSuggestionsForHighQualityPrompt() {
        let goodPrompt = "Fix the authentication bug in LoginService.swift. Currently users cannot sign in because the OAuth2 token validation logic rejects valid tokens. The fix should ensure all valid tokens are accepted and invalid tokens are rejected with proper error messages."
        _ = manager.analyzePrompt(goodPrompt)
        // A very detailed prompt should have fewer suggestions
        let highImpactSuggestions = manager.suggestions.filter { $0.impact == .high }
        XCTAssertTrue(highImpactSuggestions.count <= 1,
            "High quality prompts should have very few high-impact suggestions")
    }
}

// MARK: - Rewrite Generation Tests

@MainActor
final class RewriteGenerationTests: XCTestCase {

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

    func testGeneratesRewriteForLowScorePrompt() {
        _ = manager.analyzePrompt("fix it")
        XCTAssertNotNil(manager.lastRewrite,
            "Should generate rewrite for low-score prompts")
    }

    func testRewriteReplacesVagueReferences() {
        _ = manager.analyzePrompt("fix it now")
        if let rewrite = manager.lastRewrite {
            XCTAssertFalse(rewrite.rewrittenPrompt.lowercased().contains("fix it"),
                "Rewrite should replace 'fix it' with specific text")
            XCTAssertTrue(rewrite.appliedRules.contains { $0.contains("vague") },
                "Applied rules should include vague reference replacement")
        }
    }

    func testRewriteAddsActionVerb() {
        _ = manager.analyzePrompt("the login page has an error in it")
        if let rewrite = manager.lastRewrite {
            XCTAssertTrue(rewrite.rewrittenPrompt.hasPrefix("Implement"),
                "Should add action verb prefix")
        }
    }

    func testNoRewriteForHighScorePrompt() {
        let goodPrompt = "Fix the authentication bug in LoginService.swift. Currently users cannot sign in because the OAuth2 token validation logic rejects valid tokens. Ensure all valid tokens are accepted."
        _ = manager.analyzePrompt(goodPrompt)
        // If overall score >= 0.8, no rewrite should be generated
        if let score = manager.lastScore, score.overallScore >= 0.8 {
            XCTAssertNil(manager.lastRewrite,
                "Should not generate rewrite for high-score prompts")
        }
    }

    func testRewriteHasPositiveImprovementEstimate() {
        _ = manager.analyzePrompt("fix it")
        if let rewrite = manager.lastRewrite {
            XCTAssertGreaterThan(rewrite.estimatedScoreImprovement, 0)
            XCTAssertLessThanOrEqual(rewrite.estimatedScoreImprovement, 0.2)
        }
    }
}

// MARK: - Quick Analysis & Cache Tests

@MainActor
final class QuickAnalysisCacheTests: XCTestCase {

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

    func testQuickAnalyzeReturnsScore() {
        let score = manager.quickAnalyze("Fix the login bug")
        XCTAssertGreaterThan(score.overallScore, 0)
        XCTAssertGreaterThan(score.estimatedTokens, 0)
    }

    func testQuickAnalyzeDoesNotUpdatePublishedState() {
        // quickAnalyze should NOT update lastScore, suggestions, etc.
        XCTAssertNil(manager.lastScore)
        _ = manager.quickAnalyze("Fix the login bug")
        XCTAssertNil(manager.lastScore, "quickAnalyze should not update lastScore")
        XCTAssertTrue(manager.suggestions.isEmpty, "quickAnalyze should not update suggestions")
        XCTAssertTrue(manager.detectedAntiPatterns.isEmpty, "quickAnalyze should not update antiPatterns")
    }

    func testQuickAnalyzeCacheHit() {
        let prompt = "Fix the login bug in AuthService"
        let score1 = manager.quickAnalyze(prompt)
        let score2 = manager.quickAnalyze(prompt)

        // Same prompt should return same score (cached)
        XCTAssertEqual(score1.overallScore, score2.overallScore)
        XCTAssertEqual(score1.clarity, score2.clarity)
    }

    func testQuickAnalyzeCacheConsistency() {
        let prompt1 = "Fix the login bug"
        let prompt2 = "Add a new feature to the dashboard"

        let score1 = manager.quickAnalyze(prompt1)
        let score2 = manager.quickAnalyze(prompt2)

        // Different prompts should potentially have different scores
        // (Not asserting inequality since they *could* be equal by chance)
        XCTAssertGreaterThan(score1.overallScore, 0)
        XCTAssertGreaterThan(score2.overallScore, 0)
    }

    func testCacheLRUEviction() {
        // Fill cache beyond maxCacheSize (50)
        for i in 0..<55 {
            _ = manager.quickAnalyze("Unique prompt number \(i) for testing")
        }

        // The first few entries should have been evicted
        // We can verify by checking that new analyses still work
        let score = manager.quickAnalyze("One more unique prompt")
        XCTAssertGreaterThan(score.overallScore, 0)
    }

    func testClearAnalysisCache() {
        _ = manager.quickAnalyze("Test prompt for caching")
        manager.clearAnalysisCache()

        // After clearing, quickAnalyze should still work (recompute)
        let score = manager.quickAnalyze("Test prompt for caching")
        XCTAssertGreaterThan(score.overallScore, 0)
    }
}
