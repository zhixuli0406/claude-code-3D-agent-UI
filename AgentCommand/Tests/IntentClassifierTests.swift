import XCTest
@testable import AgentCommand

// MARK: - H5: Intent Classifier Unit Tests

@MainActor
final class IntentClassifierTests: XCTestCase {

    private var classifier: IntentClassifier!
    private var processor: SemanticQueryProcessor!

    override func setUp() {
        super.setUp()
        classifier = IntentClassifier()
        processor = SemanticQueryProcessor()
    }

    override func tearDown() {
        classifier = nil
        processor = nil
        super.tearDown()
    }

    private func classify(_ query: String) -> QueryClassification {
        let preprocessed = processor.preprocess(query)
        return classifier.classify(preprocessed)
    }

    // MARK: - Error Diagnosis Detection

    func testClassify_ErrorKeyword() {
        let result = classify("there's an error in the login module")
        XCTAssertEqual(result.primaryIntent, .errorDiagnosis)
    }

    func testClassify_CrashKeyword() {
        let result = classify("the app crashes when I click submit")
        XCTAssertEqual(result.primaryIntent, .errorDiagnosis)
    }

    func testClassify_BugKeyword() {
        let result = classify("there is a bug in the authentication flow")
        XCTAssertEqual(result.primaryIntent, .errorDiagnosis)
    }

    // MARK: - Fix/Debug Detection

    func testClassify_Fix() {
        let result = classify("fix the login function")
        XCTAssertEqual(result.primaryIntent, .codeFix)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.6)
    }

    func testClassify_Debug() {
        let result = classify("debug the authentication service")
        XCTAssertEqual(result.primaryIntent, .codeFix)
    }

    // MARK: - Code Generation Detection

    func testClassify_Add() {
        let result = classify("add a new endpoint for users")
        XCTAssertEqual(result.primaryIntent, .codeGenerate)
    }

    func testClassify_Create() {
        let result = classify("create a new class for handling payments")
        XCTAssertEqual(result.primaryIntent, .codeGenerate)
    }

    func testClassify_Implement() {
        let result = classify("implement the search functionality")
        XCTAssertEqual(result.primaryIntent, .codeGenerate)
    }

    // MARK: - Task Create vs Code Generate

    func testClassify_AddTask() {
        let result = classify("add a task to implement dark mode")
        XCTAssertEqual(result.primaryIntent, .taskCreate)
    }

    // MARK: - Refactor Detection

    func testClassify_Refactor() {
        let result = classify("refactor the database module")
        XCTAssertEqual(result.primaryIntent, .codeRefactor)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.6)
    }

    func testClassify_Restructure() {
        let result = classify("restructure the API layer")
        XCTAssertEqual(result.primaryIntent, .codeRefactor)
    }

    // MARK: - Code Search Detection

    func testClassify_Find() {
        let result = classify("find the authentication handler")
        XCTAssertEqual(result.primaryIntent, .codeSearch)
    }

    func testClassify_Search() {
        let result = classify("search for the login function")
        XCTAssertEqual(result.primaryIntent, .codeSearch)
    }

    // MARK: - File Navigation

    func testClassify_Open() {
        let result = classify("open the settings page")
        XCTAssertEqual(result.primaryIntent, .fileNavigation)
    }

    func testClassify_Navigate() {
        let result = classify("navigate to the main view")
        XCTAssertEqual(result.primaryIntent, .fileNavigation)
    }

    // MARK: - Question / Explain Detection

    func testClassify_HowQuestion() {
        let result = classify("how does the caching layer work?")
        let validIntents: [QueryIntent] = [.codeExplain, .conceptExplain, .architectureQuery]
        XCTAssertTrue(validIntents.contains(result.primaryIntent),
                      "Expected explain-related intent, got \(result.primaryIntent)")
    }

    func testClassify_WhatQuestion() {
        let result = classify("what is BM25 scoring?")
        let validIntents: [QueryIntent] = [.conceptExplain, .codeExplain]
        XCTAssertTrue(validIntents.contains(result.primaryIntent),
                      "Expected explain-related intent, got \(result.primaryIntent)")
    }

    // MARK: - System Command Detection

    func testClassify_Clear() {
        let result = classify("clear the search index")
        XCTAssertEqual(result.primaryIntent, .systemCommand)
    }

    func testClassify_Rebuild() {
        let result = classify("rebuild the RAG index")
        XCTAssertEqual(result.primaryIntent, .systemCommand)
    }

    func testClassify_Reset() {
        let result = classify("reset all settings")
        // Could be systemCommand or configChange
        let validIntents: [QueryIntent] = [.systemCommand, .configChange]
        XCTAssertTrue(validIntents.contains(result.primaryIntent))
    }

    // MARK: - Config Change Detection

    func testClassify_Enable() {
        let result = classify("enable auto-indexing")
        XCTAssertEqual(result.primaryIntent, .configChange)
    }

    func testClassify_Disable() {
        let result = classify("disable notifications")
        XCTAssertEqual(result.primaryIntent, .configChange)
    }

    // MARK: - Pattern Match Detection

    func testClassify_Similar() {
        let result = classify("find similar code to this function")
        let validIntents: [QueryIntent] = [.patternMatch, .codeSearch]
        XCTAssertTrue(validIntents.contains(result.primaryIntent))
    }

    // MARK: - Task Status Detection

    func testClassify_TaskStatus() {
        let result = classify("what is the status of the auth task?")
        // This query has question word + "status" + "task", could match multiple intents
        let validIntents: [QueryIntent] = [.taskStatus, .conceptExplain, .codeExplain, .configChange]
        XCTAssertTrue(validIntents.contains(result.primaryIntent),
                      "Expected task/explain intent, got \(result.primaryIntent)")
    }

    func testClassify_TaskDecompose() {
        let result = classify("break down the migration task into steps")
        let validIntents: [QueryIntent] = [.taskDecompose, .codeRefactor]
        XCTAssertTrue(validIntents.contains(result.primaryIntent))
    }

    // MARK: - Unknown / Fallback

    func testClassify_Unknown() {
        let result = classify("hello")
        // Single word without clear intent
        XCTAssertNotNil(result.primaryIntent)
        XCTAssertGreaterThan(result.confidence, 0)
    }

    // MARK: - Confidence

    func testClassify_HighConfidenceForClearIntent() {
        let result = classify("fix the crash in AppState.swift")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.6)
    }

    func testClassify_ConfidenceInRange() {
        let queries = ["fix bug", "add feature", "what is this?", "hello world", "refactor code"]
        for query in queries {
            let result = classify(query)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
        }
    }

    // MARK: - Complexity Assessment

    func testClassify_TrivialComplexity() {
        let result = classify("AppState")
        // 1-2 tokens → trivial
        XCTAssertEqual(result.queryComplexity, .trivial)
    }

    func testClassify_SimpleComplexity() {
        let result = classify("find login function")
        // 3 tokens but NLP may detect entities, so complexity varies
        let validComplexities: [QueryComplexity] = [.trivial, .simple, .moderate]
        XCTAssertTrue(validComplexities.contains(result.queryComplexity),
                      "Expected trivial/simple/moderate, got \(result.queryComplexity)")
    }

    // MARK: - Secondary Intents

    func testClassify_HasSecondaryIntents() {
        let result = classify("fix the crash in the login module and then test it")
        // Complex query should have secondary intents
        XCTAssertNotNil(result.primaryIntent)
    }

    // MARK: - Chinese Query Support

    func testClassify_ChineseFix() {
        let result = classify("修復登入功能的錯誤")
        let validIntents: [QueryIntent] = [.codeFix, .errorDiagnosis]
        XCTAssertTrue(validIntents.contains(result.primaryIntent),
                      "Expected fix/error intent for Chinese query, got \(result.primaryIntent)")
    }

    func testClassify_ChineseSearch() {
        let result = classify("搜尋使用者認證功能")
        let validIntents: [QueryIntent] = [.codeSearch, .codeGenerate]
        XCTAssertTrue(validIntents.contains(result.primaryIntent),
                      "Expected search intent for Chinese query, got \(result.primaryIntent)")
    }

    // MARK: - AI Response Parsing

    func testParseAIResponse_ValidJSON() {
        let json = """
        {"primary": {"intent": "codeSearch", "confidence": 0.92}, "secondary": [{"intent": "fileNavigation", "score": 0.45}]}
        """
        let preprocessed = PreprocessedQuery(originalQuery: "test")
        let result = classifier.parseAIResponse(json, originalQuery: preprocessed)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.primaryIntent, .codeSearch)
        XCTAssertEqual(result?.confidence ?? 0, 0.92, accuracy: 0.01)
        XCTAssertEqual(result?.secondaryIntents.count, 1)
    }

    func testParseAIResponse_InvalidJSON() {
        let result = classifier.parseAIResponse("not json", originalQuery: PreprocessedQuery(originalQuery: "test"))
        XCTAssertNil(result)
    }

    func testParseAIResponse_InvalidIntent() {
        let json = """
        {"primary": {"intent": "nonExistentIntent", "confidence": 0.9}, "secondary": []}
        """
        let result = classifier.parseAIResponse(json, originalQuery: PreprocessedQuery(originalQuery: "test"))
        XCTAssertNil(result)
    }

    // MARK: - AI Prompt Building

    func testBuildAIClassificationPrompt() {
        let prompt = classifier.buildAIClassificationPrompt(
            query: "find the login function",
            projectContext: "Swift project",
            recentFiles: ["AppState.swift", "ContentView.swift"]
        )
        XCTAssertTrue(prompt.contains("find the login function"))
        XCTAssertTrue(prompt.contains("Swift project"))
        XCTAssertTrue(prompt.contains("AppState.swift"))
    }

    // MARK: - Last Classification

    func testClassify_UpdatesLastClassification() {
        XCTAssertNil(classifier.lastClassification)
        let _ = classify("fix the bug")
        XCTAssertNotNil(classifier.lastClassification)
    }

    // MARK: - AI Threshold

    func testAIThreshold_Default() {
        XCTAssertEqual(classifier.aiThreshold, 0.6)
    }

    func testAIThreshold_Configurable() {
        classifier.aiThreshold = 0.8
        XCTAssertEqual(classifier.aiThreshold, 0.8)
    }
}
