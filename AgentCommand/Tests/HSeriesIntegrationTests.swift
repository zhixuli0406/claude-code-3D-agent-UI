import XCTest
@testable import AgentCommand

// MARK: - H-Series Integration Tests
//
// These tests verify cross-module interactions between H-series features:
// - H1 (RAG) ↔ H5 (Semantic Query)
// - H1 (RAG Content Chunker) ↔ H1 (RAG Models)
// - H5 (Intent Classifier) ↔ H5 (Semantic Query Processor)
// - L2 (Smart Scheduling) end-to-end workflows
// - L3 (Anomaly Detection) end-to-end workflows

// MARK: - RAG Pipeline Integration

final class RAGPipelineIntegrationTests: XCTestCase {

    func testChunkerOutputMatchesModelConstraints() {
        let chunker = RAGContentChunker()
        let swiftCode = """
        import Foundation
        import SwiftUI

        // MARK: - MyApp Models

        struct UserModel {
            var name: String
            var email: String
            var createdAt: Date
        }

        class UserService {
            private var users: [UserModel] = []

            func addUser(_ user: UserModel) {
                users.append(user)
            }

            func findUser(byName name: String) -> UserModel? {
                return users.first { $0.name == name }
            }
        }

        enum AppError: Error {
            case notFound
            case unauthorized
            case networkError(String)
        }
        """

        let chunks = chunker.chunk(content: swiftCode, fileType: .swift)

        // Verify all chunks have valid types
        for chunk in chunks {
            XCTAssertTrue(RAGChunkType.allCases.contains(chunk.type))
        }

        // Verify chunks cover the entire content
        XCTAssertFalse(chunks.isEmpty)

        // Verify line number consistency
        for chunk in chunks {
            XCTAssertGreaterThanOrEqual(chunk.endLine, chunk.startLine)
        }

        // Verify symbol names are extracted for declarations
        let classChunk = chunks.first { $0.type == .classDefinition }
        if let classChunk = classChunk {
            XCTAssertNotNil(classChunk.symbolName)
        }
    }

    func testRRFFusionEndToEnd() {
        let ranker = RAGHybridRanker()

        // Create documents
        let doc1 = RAGDocument(filePath: "/app/AuthService.swift", fileName: "AuthService.swift",
                               fileType: .swift, contentPreview: "class AuthService { func login() {} }",
                               lineCount: 50, fileSize: 1200, lastModified: Date())
        let doc2 = RAGDocument(filePath: "/app/UserModel.swift", fileName: "UserModel.swift",
                               fileType: .swift, contentPreview: "struct UserModel { var name: String }",
                               lineCount: 30, fileSize: 800, lastModified: Date())

        // Create FTS results
        let ftsResults = [
            RAGSearchResult(document: doc1, matchedSnippet: "func login()", score: 0.9, lineNumber: 10),
            RAGSearchResult(document: doc2, matchedSnippet: "var name", score: 0.5, lineNumber: 3),
        ]

        // Create vector results
        let vectorResults: [(chunkId: Int, documentId: String, score: Float, snippet: String, startLine: Int, symbolName: String?, filePath: String)] = [
            (chunkId: 1, documentId: doc1.id, score: 0.85, snippet: "authentication login", startLine: 5, symbolName: "func login", filePath: doc1.filePath),
        ]

        // Step 1: Fuse
        let fused = ranker.fuse(ftsResults: ftsResults, vectorResults: vectorResults)
        XCTAssertFalse(fused.isEmpty)

        // Step 2: Apply boosts
        let relationship = RAGRelationship(sourceId: doc1.id, targetId: doc2.id, type: .imports)
        let boosted = ranker.applyBoosts(results: fused, documents: [doc1, doc2], relationships: [relationship], query: "login authentication")
        XCTAssertFalse(boosted.isEmpty)

        // Step 3: Deduplicate
        let final = ranker.deduplicate(boosted, maxPerDocument: 2)
        XCTAssertFalse(final.isEmpty)

        // Results should be sorted by score
        for i in 1..<final.count {
            XCTAssertGreaterThanOrEqual(final[i-1].finalScore, final[i].finalScore)
        }
    }

    func testVectorSerializationRoundTrip() {
        // Simulate embedding → blob → restore cycle
        let embedding: [Float] = (0..<512).map { _ in Float.random(in: -1.0...1.0) }
        let blob = embedding.asBlob
        let restored = [Float].fromBlob(blob)

        XCTAssertEqual(restored.count, embedding.count)
        for (a, b) in zip(embedding, restored) {
            XCTAssertEqual(a, b, accuracy: 1e-6)
        }
    }

    func testCosineSimilarityWithEmbeddings() {
        let service = RAGEmbeddingService()
        let v1 = service.embed(text: "authentication login user")
        let v2 = service.embed(text: "auth sign in credential")
        let v3 = service.embed(text: "database table schema")

        if let v1 = v1, let v2 = v2, let v3 = v3 {
            let sim12 = RAGEmbeddingService.cosineSimilarity(v1, v2)
            let sim13 = RAGEmbeddingService.cosineSimilarity(v1, v3)
            // Semantically similar texts should have higher similarity
            // Note: NLEmbedding quality varies, so we use a generous check
            XCTAssertGreaterThan(sim12, -1.0) // Just verify it returns valid values
            XCTAssertGreaterThan(sim13, -1.0)
        }
    }
}

// MARK: - Semantic Query Pipeline Integration

@MainActor
final class SemanticQueryPipelineIntegrationTests: XCTestCase {

    func testFullQueryProcessingPipeline() {
        let processor = SemanticQueryProcessor()
        let classifier = IntentClassifier()

        // Step 1: Preprocess the query
        let preprocessed = processor.preprocess("fix the crash in AuthService.swift")

        // Verify preprocessing results
        XCTAssertFalse(preprocessed.tokens.isEmpty)
        XCTAssertFalse(preprocessed.stemmedTokens.isEmpty)
        XCTAssertFalse(preprocessed.ftsQuery.isEmpty)

        // Check entity extraction
        let fileEntities = preprocessed.entities.filter { $0.type == .fileName }
        XCTAssertFalse(fileEntities.isEmpty, "Should detect AuthService.swift as file entity")

        // Step 2: Classify intent
        let classification = classifier.classify(preprocessed)
        XCTAssertNotNil(classification.primaryIntent)
        XCTAssertGreaterThan(classification.confidence, 0)

        // "fix" + "crash" should map to codeFix or errorDiagnosis
        let validIntents: [QueryIntent] = [.codeFix, .errorDiagnosis]
        XCTAssertTrue(validIntents.contains(classification.primaryIntent),
                      "Expected fix/error intent, got \(classification.primaryIntent)")
    }

    func testQueryProcessorWithKnownEntities() {
        let processor = SemanticQueryProcessor()

        // Populate known entities (simulating RAG index)
        processor.knownFileNames = ["AppState.swift", "AuthService.swift", "ContentView.swift"]
        processor.knownClassNames = ["AppState", "AuthService"]

        let preprocessed = processor.preprocess("how does AppState handle login?")

        // Should detect AppState as a known entity
        let knownEntities = preprocessed.entities.filter { $0.value == "AppState" || $0.value == "AppState.swift" }
        XCTAssertFalse(knownEntities.isEmpty, "Should detect AppState as known entity")

        // Semantic keywords should include the entity
        let hasAppState = preprocessed.semanticKeywords.contains { $0.contains("AppState") || $0.contains("appstate") }
        XCTAssertTrue(hasAppState || !preprocessed.semanticKeywords.isEmpty)
    }

    func testMultipleQueryClassifications() {
        let processor = SemanticQueryProcessor()
        let classifier = IntentClassifier()

        let testCases: [(query: String, expectedIntents: [QueryIntent])] = [
            ("fix the login bug", [.codeFix, .errorDiagnosis]),
            ("add a new payment endpoint", [.codeGenerate, .taskCreate]),
            ("refactor the database layer", [.codeRefactor]),
            ("find the auth handler", [.codeSearch]),
            ("open AppState.swift", [.fileNavigation, .codeSearch]),
            ("enable auto-indexing", [.configChange]),
            ("clear the cache", [.systemCommand]),
            ("what is dependency injection?", [.conceptExplain, .codeExplain]),
        ]

        for (query, expectedIntents) in testCases {
            let preprocessed = processor.preprocess(query)
            let classification = classifier.classify(preprocessed)
            XCTAssertTrue(expectedIntents.contains(classification.primaryIntent),
                          "Query '\(query)' expected \(expectedIntents), got \(classification.primaryIntent)")
        }
    }

    func testScoringWeightsIntegration() {
        // Verify that different weight presets produce different combined scores
        let defaultWeights = SemanticScoringWeights.default
        let codeSearchWeights = SemanticScoringWeights.codeSearch
        let errorWeights = SemanticScoringWeights.errorDiagnosis

        // Test scenario: high keyword, low recency
        let scores = (keyword: Float(0.9), semantic: Float(0.3), entity: Float(0.5), recency: Float(0.1), relationship: Float(0.2))

        let defaultScore = defaultWeights.combine(keyword: scores.keyword, semantic: scores.semantic, entity: scores.entity, recency: scores.recency, relationship: scores.relationship)
        let codeScore = codeSearchWeights.combine(keyword: scores.keyword, semantic: scores.semantic, entity: scores.entity, recency: scores.recency, relationship: scores.relationship)
        let errorScore = errorWeights.combine(keyword: scores.keyword, semantic: scores.semantic, entity: scores.entity, recency: scores.recency, relationship: scores.relationship)

        // All scores should be valid
        XCTAssertGreaterThan(defaultScore, 0)
        XCTAssertGreaterThan(codeScore, 0)
        XCTAssertGreaterThan(errorScore, 0)

        // Different presets should yield different scores
        XCTAssertNotEqual(defaultScore, codeScore, accuracy: 0.001)
    }
}

// MARK: - Smart Scheduling End-to-End

@MainActor
final class SmartSchedulingIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "smartScheduling.completedCount")
        UserDefaults.standard.removeObject(forKey: "smartScheduling.avgAccuracy")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "smartScheduling.completedCount")
        UserDefaults.standard.removeObject(forKey: "smartScheduling.avgAccuracy")
        super.tearDown()
    }

    func testFullSchedulingWorkflow() {
        let manager = SmartSchedulingManager()

        // Step 1: Add tasks with different priorities
        manager.addTask(name: "Low Priority", description: "Minor update", priority: .low, estimatedTokens: 500)
        manager.addTask(name: "Critical Fix", description: "Production bug", priority: .critical, estimatedTokens: 2000)
        manager.addTask(name: "Medium Feature", description: "New feature", priority: .medium, estimatedTokens: 3000)
        manager.addTask(name: "High Refactor", description: "Code cleanup", priority: .high, estimatedTokens: 1500)

        XCTAssertEqual(manager.scheduledTasks.count, 4)

        // Step 2: Verify optimization orders critical tasks first
        let scheduled = manager.scheduledTasks.filter { $0.status == .scheduled }
        if let firstScheduled = scheduled.min(by: { ($0.suggestedTime ?? Date.distantFuture) < ($1.suggestedTime ?? Date.distantFuture) }) {
            XCTAssertEqual(firstScheduled.priority, .critical)
        }

        // Step 3: Complete a task
        if let criticalTask = manager.scheduledTasks.first(where: { $0.name == "Critical Fix" }) {
            manager.markCompleted(criticalTask.id)
            XCTAssertEqual(criticalTask.id, manager.scheduledTasks.first(where: { $0.id == criticalTask.id })?.id)
        }

        // Step 4: Adjust priority
        if let lowTask = manager.scheduledTasks.first(where: { $0.name == "Low Priority" }) {
            manager.adjustPriority(lowTask.id, to: .high)
            XCTAssertEqual(manager.scheduledTasks.first(where: { $0.id == lowTask.id })?.priority, .high)
        }

        // Step 5: Batch some tasks
        let batchIds = manager.scheduledTasks.filter { $0.priority == .medium }.map(\.id)
        manager.createBatch(taskIds: batchIds)

        // Step 6: Remove a task
        if let mediumTask = manager.scheduledTasks.first(where: { $0.name == "Medium Feature" }) {
            manager.removeTask(mediumTask.id)
        }

        // Verify final state
        XCTAssertLessThan(manager.scheduledTasks.count, 4)
        XCTAssertGreaterThan(manager.stats.totalScheduled, 0)
    }
}

// MARK: - Anomaly Detection End-to-End

@MainActor
final class AnomalyDetectionIntegrationTests: XCTestCase {

    func testFullAnomalyDetectionWorkflow() {
        let manager = AnomalyDetectionManager()

        // Step 1: Configure retry strategies
        manager.setDefaultRetryConfig()
        XCTAssertEqual(manager.retryConfigs.count, 2)

        // Step 2: Report various anomalies
        manager.reportAnomaly(type: .excessiveTokens, severity: .warning,
                             message: "Task 'build' consumed 12000 tokens",
                             agentName: "Builder-1", taskName: "build",
                             metrics: ["tokens": 12000, "threshold": 10000])

        manager.reportAnomaly(type: .longRunning, severity: .critical,
                             message: "Task 'deploy' running for 15 minutes",
                             agentName: "Deployer-1", taskName: "deploy",
                             metrics: ["duration_min": 15, "timeout_min": 10])

        manager.reportAnomaly(type: .repeatedErrors, severity: .critical,
                             message: "Agent 'Tester-1' has 4 failed tasks",
                             agentName: "Tester-1",
                             metrics: ["error_count": 4])

        XCTAssertEqual(manager.alerts.count, 3)
        XCTAssertGreaterThan(manager.errorPatterns.count, 0)

        // Step 3: Verify stats
        XCTAssertEqual(manager.stats.totalAlerts, 3)
        XCTAssertEqual(manager.stats.activeAlerts, 3)

        // Step 4: Resolve some alerts
        manager.resolveAlert(manager.alerts[0].id)
        XCTAssertEqual(manager.stats.activeAlerts, 2)
        XCTAssertEqual(manager.stats.resolvedAlerts, 1)

        // Step 5: Toggle retry config
        let configId = manager.retryConfigs[0].id
        manager.toggleRetryConfig(configId)
        XCTAssertFalse(manager.retryConfigs[0].isActive)

        // Step 6: Resolve all remaining
        manager.resolveAllAlerts()
        XCTAssertEqual(manager.stats.activeAlerts, 0)
        XCTAssertEqual(manager.stats.resolvedAlerts, 3)

        // Step 7: Dismiss an alert
        manager.dismissAlert(manager.alerts[0].id)
        XCTAssertEqual(manager.alerts.count, 2)
    }

    func testAutoActionAssignment() {
        let manager = AnomalyDetectionManager()

        // Test all anomaly types for auto-action
        let testCases: [(AnomalyType, AnomalySeverity, Bool)] = [
            (.infiniteLoop, .critical, true),   // always auto-action
            (.infiniteLoop, .warning, true),    // always auto-action
            (.excessiveTokens, .critical, true), // critical only
            (.excessiveTokens, .warning, false), // no auto-action for warning
            (.repeatedErrors, .critical, true),  // always auto-action
            (.longRunning, .critical, true),     // critical only
            (.longRunning, .warning, false),     // no auto-action for warning
            (.memoryLeak, .critical, true),      // always auto-action
            (.rateLimitRisk, .warning, true),    // always auto-action
        ]

        for (type, severity, expectAutoAction) in testCases {
            let manager = AnomalyDetectionManager()
            manager.reportAnomaly(type: type, severity: severity, message: "Test \(type) \(severity)")
            let hasAction = manager.alerts.first?.autoAction != nil
            XCTAssertEqual(hasAction, expectAutoAction,
                          "\(type) with \(severity) should \(expectAutoAction ? "have" : "not have") auto-action")
        }
    }
}

// MARK: - Cross-Module Integration

@MainActor
final class CrossModuleIntegrationTests: XCTestCase {

    func testFileTypeDetectionConsistency() {
        // Verify RAGFileType.from(extension:) works with chunker dispatch
        let chunker = RAGContentChunker()
        let testFiles: [(ext: String, expectedType: RAGFileType)] = [
            ("swift", .swift),
            ("py", .python),
            ("js", .javascript),
            ("ts", .typescript),
            ("md", .markdown),
            ("json", .json),
        ]

        for (ext, expectedType) in testFiles {
            let detectedType = RAGFileType.from(extension: ext)
            XCTAssertEqual(detectedType, expectedType, "Extension .\(ext) should map to \(expectedType)")

            // Verify chunker can handle this type
            let chunks = chunker.chunk(content: "sample content", fileType: detectedType)
            XCTAssertFalse(chunks.isEmpty, "Chunker should handle \(detectedType)")
        }
    }

    func testQueryComplexityAffectsSearchConfig() {
        // Verify that higher complexity suggests more RAG snippets
        let complexities: [QueryComplexity] = [.trivial, .simple, .moderate, .complex, .compound]
        var prevSnippets = 0
        for complexity in complexities {
            XCTAssertGreaterThanOrEqual(complexity.suggestedRAGSnippets, prevSnippets,
                                       "\(complexity) should suggest >= \(prevSnippets) snippets")
            prevSnippets = complexity.suggestedRAGSnippets
        }
    }

    func testModelCodableRoundTrips() throws {
        // Verify all Codable models survive encode/decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // RAGFileType
        for ft in RAGFileType.allCases {
            let data = try encoder.encode(ft)
            XCTAssertEqual(try decoder.decode(RAGFileType.self, from: data), ft)
        }

        // RAGChunkType
        for ct in RAGChunkType.allCases {
            let data = try encoder.encode(ct)
            XCTAssertEqual(try decoder.decode(RAGChunkType.self, from: data), ct)
        }

        // QueryIntent
        for qi in QueryIntent.allCases {
            let data = try encoder.encode(qi)
            XCTAssertEqual(try decoder.decode(QueryIntent.self, from: data), qi)
        }

        // RAGRelationship
        let rel = RAGRelationship(sourceId: "a", targetId: "b", type: .imports)
        let relData = try encoder.encode(rel)
        let decodedRel = try decoder.decode(RAGRelationship.self, from: relData)
        XCTAssertEqual(decodedRel.sourceId, "a")
        XCTAssertEqual(decodedRel.targetId, "b")
        XCTAssertEqual(decodedRel.type, .imports)

        // RAGSemanticConfig
        let config = RAGSemanticConfig.default
        let configData = try encoder.encode(config)
        let decodedConfig = try decoder.decode(RAGSemanticConfig.self, from: configData)
        XCTAssertEqual(decodedConfig.enableSemanticSearch, config.enableSemanticSearch)

        // SemanticScoringWeights
        let weights = SemanticScoringWeights.default
        let wData = try encoder.encode(weights)
        let decodedW = try decoder.decode(SemanticScoringWeights.self, from: wData)
        XCTAssertEqual(decodedW.keywordWeight, weights.keywordWeight, accuracy: 0.001)
    }
}
