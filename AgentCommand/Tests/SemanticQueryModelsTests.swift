import XCTest
@testable import AgentCommand

// MARK: - H5: Semantic Query Models Unit Tests

// MARK: - QueryIntent Tests

final class QueryIntentTests: XCTestCase {

    func testAllCasesHaveDisplayName() {
        for intent in QueryIntent.allCases {
            XCTAssertFalse(intent.displayName.isEmpty, "\(intent) should have a displayName")
        }
    }

    func testAllCasesHaveIconName() {
        for intent in QueryIntent.allCases {
            XCTAssertFalse(intent.iconName.isEmpty, "\(intent) should have an iconName")
        }
    }

    func testNeedsRAGContext_CodeRelated() {
        XCTAssertTrue(QueryIntent.codeSearch.needsRAGContext)
        XCTAssertTrue(QueryIntent.codeFix.needsRAGContext)
        XCTAssertTrue(QueryIntent.codeExplain.needsRAGContext)
        XCTAssertTrue(QueryIntent.codeRefactor.needsRAGContext)
        XCTAssertTrue(QueryIntent.codeGenerate.needsRAGContext)
        XCTAssertTrue(QueryIntent.dependencyQuery.needsRAGContext)
        XCTAssertTrue(QueryIntent.architectureQuery.needsRAGContext)
        XCTAssertTrue(QueryIntent.errorDiagnosis.needsRAGContext)
    }

    func testNeedsRAGContext_NonCodeRelated() {
        XCTAssertFalse(QueryIntent.fileNavigation.needsRAGContext)
        XCTAssertFalse(QueryIntent.taskCreate.needsRAGContext)
        XCTAssertFalse(QueryIntent.taskStatus.needsRAGContext)
        XCTAssertFalse(QueryIntent.conceptExplain.needsRAGContext)
        XCTAssertFalse(QueryIntent.systemCommand.needsRAGContext)
        XCTAssertFalse(QueryIntent.configChange.needsRAGContext)
        XCTAssertFalse(QueryIntent.unknown.needsRAGContext)
    }

    func testNeedsMemoryContext() {
        XCTAssertTrue(QueryIntent.codeFix.needsMemoryContext)
        XCTAssertTrue(QueryIntent.codeRefactor.needsMemoryContext)
        XCTAssertTrue(QueryIntent.errorDiagnosis.needsMemoryContext)
        XCTAssertTrue(QueryIntent.taskStatus.needsMemoryContext)
        XCTAssertTrue(QueryIntent.patternMatch.needsMemoryContext)
        // Non-memory intents
        XCTAssertFalse(QueryIntent.codeSearch.needsMemoryContext)
        XCTAssertFalse(QueryIntent.fileNavigation.needsMemoryContext)
        XCTAssertFalse(QueryIntent.unknown.needsMemoryContext)
    }

    func testPriorityWeights_CodeFixHighest() {
        XCTAssertEqual(QueryIntent.codeFix.priorityWeight, 1.0)
        XCTAssertEqual(QueryIntent.errorDiagnosis.priorityWeight, 1.0)
    }

    func testPriorityWeights_UnknownLowest() {
        XCTAssertEqual(QueryIntent.unknown.priorityWeight, 0.3)
        for intent in QueryIntent.allCases where intent != .unknown {
            XCTAssertGreaterThan(intent.priorityWeight, QueryIntent.unknown.priorityWeight)
        }
    }

    func testPriorityWeights_AreInRange() {
        for intent in QueryIntent.allCases {
            XCTAssertGreaterThanOrEqual(intent.priorityWeight, 0.0)
            XCTAssertLessThanOrEqual(intent.priorityWeight, 1.0)
        }
    }

    func testCodable() throws {
        for intent in QueryIntent.allCases {
            let data = try JSONEncoder().encode(intent)
            let decoded = try JSONDecoder().decode(QueryIntent.self, from: data)
            XCTAssertEqual(decoded, intent)
        }
    }
}

// MARK: - QueryClassification Tests

final class QueryClassificationTests: XCTestCase {

    func testIsHighConfidence() {
        let high = QueryClassification(primaryIntent: .codeSearch, confidence: 0.80)
        XCTAssertTrue(high.isHighConfidence)

        let medium = QueryClassification(primaryIntent: .codeSearch, confidence: 0.74)
        XCTAssertFalse(medium.isHighConfidence)

        let exact = QueryClassification(primaryIntent: .codeSearch, confidence: 0.75)
        XCTAssertTrue(exact.isHighConfidence)
    }

    func testIsAmbiguous_LowConfidence() {
        let ambiguous = QueryClassification(primaryIntent: .codeSearch, confidence: 0.40)
        XCTAssertTrue(ambiguous.isAmbiguous)
    }

    func testIsAmbiguous_HighConfidence() {
        let clear = QueryClassification(primaryIntent: .codeSearch, confidence: 0.90)
        XCTAssertFalse(clear.isAmbiguous)
    }

    func testIsAmbiguous_CloseSecondary() {
        let classification = QueryClassification(
            primaryIntent: .codeSearch,
            confidence: 0.70,
            secondaryIntents: [IntentScore(intent: .codeExplain, score: 0.60)]
        )
        // 0.60 > 0.70 * 0.8 (0.56), so it's ambiguous
        XCTAssertTrue(classification.isAmbiguous)
    }

    func testCodable() throws {
        let original = QueryClassification(
            primaryIntent: .codeFix,
            confidence: 0.85,
            secondaryIntents: [IntentScore(intent: .codeSearch, score: 0.5)],
            queryComplexity: .moderate
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QueryClassification.self, from: data)
        XCTAssertEqual(decoded.primaryIntent, original.primaryIntent)
        XCTAssertEqual(decoded.confidence, original.confidence, accuracy: 0.001)
    }
}

// MARK: - QueryComplexity Tests

final class QueryComplexityTests: XCTestCase {

    func testMaxSearchDepth() {
        XCTAssertEqual(QueryComplexity.trivial.maxSearchDepth, 5)
        XCTAssertEqual(QueryComplexity.simple.maxSearchDepth, 10)
        XCTAssertEqual(QueryComplexity.moderate.maxSearchDepth, 15)
        XCTAssertEqual(QueryComplexity.complex.maxSearchDepth, 20)
        XCTAssertEqual(QueryComplexity.compound.maxSearchDepth, 25)
    }

    func testSuggestedRAGSnippets() {
        XCTAssertEqual(QueryComplexity.trivial.suggestedRAGSnippets, 3)
        XCTAssertEqual(QueryComplexity.simple.suggestedRAGSnippets, 5)
        XCTAssertEqual(QueryComplexity.moderate.suggestedRAGSnippets, 7)
        XCTAssertEqual(QueryComplexity.complex.suggestedRAGSnippets, 10)
        XCTAssertEqual(QueryComplexity.compound.suggestedRAGSnippets, 12)
    }

    func testMaxSearchDepth_Increasing() {
        let complexities: [QueryComplexity] = [.trivial, .simple, .moderate, .complex, .compound]
        for i in 1..<complexities.count {
            XCTAssertGreaterThan(complexities[i].maxSearchDepth, complexities[i-1].maxSearchDepth)
        }
    }
}

// MARK: - QueryLanguage Tests

final class QueryLanguageTests: XCTestCase {

    func testEnglishStopWords() {
        let stopWords = QueryLanguage.english.stopWords
        XCTAssertTrue(stopWords.contains("the"))
        XCTAssertTrue(stopWords.contains("is"))
        XCTAssertTrue(stopWords.contains("and"))
        XCTAssertFalse(stopWords.isEmpty)
    }

    func testChineseStopWords() {
        let stopWords = QueryLanguage.chineseTraditional.stopWords
        XCTAssertTrue(stopWords.contains("的"))
        XCTAssertTrue(stopWords.contains("是"))
        XCTAssertFalse(stopWords.isEmpty)
    }

    func testJapaneseStopWords() {
        let stopWords = QueryLanguage.japanese.stopWords
        XCTAssertTrue(stopWords.contains("の"))
        XCTAssertTrue(stopWords.contains("は"))
        XCTAssertFalse(stopWords.isEmpty)
    }

    func testMixedStopWords() {
        let stopWords = QueryLanguage.mixed.stopWords
        XCTAssertTrue(stopWords.isEmpty)
    }

    func testCodable() throws {
        for lang in [QueryLanguage.english, .chineseTraditional, .chineseSimplified, .japanese, .mixed] {
            let data = try JSONEncoder().encode(lang)
            let decoded = try JSONDecoder().decode(QueryLanguage.self, from: data)
            XCTAssertEqual(decoded, lang)
        }
    }
}

// MARK: - QueryEntity Tests

final class QueryEntityTests: XCTestCase {

    func testAllEntityTypesHaveDisplayName() {
        for entityType in QueryEntity.EntityType.allCases {
            XCTAssertFalse(entityType.displayName.isEmpty)
        }
    }

    func testEntityInitialization() {
        let entity = QueryEntity(
            type: .fileName,
            value: "AppState.swift",
            originalSpan: "AppState.swift",
            startIndex: 5,
            confidence: 0.9
        )
        XCTAssertEqual(entity.type, .fileName)
        XCTAssertEqual(entity.value, "AppState.swift")
        XCTAssertEqual(entity.startIndex, 5)
        XCTAssertEqual(entity.confidence, 0.9)
        XCTAssertFalse(entity.id.isEmpty)
    }

    func testEntityDefaultConfidence() {
        let entity = QueryEntity(
            type: .className,
            value: "MyClass",
            originalSpan: "MyClass",
            startIndex: 0
        )
        XCTAssertEqual(entity.confidence, 1.0)
    }
}

// MARK: - PreprocessedQuery Tests

final class PreprocessedQueryTests: XCTestCase {

    func testInitialization() {
        let query = PreprocessedQuery(originalQuery: "find the login function")
        XCTAssertEqual(query.originalQuery, "find the login function")
        XCTAssertEqual(query.normalizedQuery, "find the login function")
        XCTAssertTrue(query.tokens.isEmpty)
        XCTAssertTrue(query.stemmedTokens.isEmpty)
        XCTAssertEqual(query.detectedLanguage, .english)
        XCTAssertTrue(query.entities.isEmpty)
        XCTAssertTrue(query.expandedTerms.isEmpty)
        XCTAssertTrue(query.ftsQuery.isEmpty)
        XCTAssertFalse(query.id.isEmpty)
    }
}

// MARK: - SemanticScoringWeights Tests

final class SemanticScoringWeightsTests: XCTestCase {

    func testDefaultWeightsSumToOne() {
        let w = SemanticScoringWeights.default
        let sum = w.keywordWeight + w.semanticWeight + w.entityWeight + w.recencyWeight + w.relationshipWeight
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func testCodeSearchWeightsSumToOne() {
        let w = SemanticScoringWeights.codeSearch
        let sum = w.keywordWeight + w.semanticWeight + w.entityWeight + w.recencyWeight + w.relationshipWeight
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func testErrorDiagnosisWeightsSumToOne() {
        let w = SemanticScoringWeights.errorDiagnosis
        let sum = w.keywordWeight + w.semanticWeight + w.entityWeight + w.recencyWeight + w.relationshipWeight
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func testCombine() {
        let w = SemanticScoringWeights.default
        let score = w.combine(keyword: 1.0, semantic: 1.0, entity: 1.0, recency: 1.0, relationship: 1.0)
        // All dimensions at 1.0, weights sum to 1.0 → combined = 1.0
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testCombine_AllZeros() {
        let w = SemanticScoringWeights.default
        let score = w.combine(keyword: 0, semantic: 0, entity: 0, recency: 0, relationship: 0)
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    func testCombine_PartialScores() {
        let w = SemanticScoringWeights.default
        let score = w.combine(keyword: 0.8, semantic: 0.6, entity: 0.5, recency: 0.3, relationship: 0.2)
        // 0.8*0.30 + 0.6*0.30 + 0.5*0.20 + 0.3*0.10 + 0.2*0.10 = 0.24 + 0.18 + 0.10 + 0.03 + 0.02 = 0.57
        XCTAssertEqual(score, 0.57, accuracy: 0.01)
    }

    func testCodable() throws {
        let original = SemanticScoringWeights.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SemanticScoringWeights.self, from: data)
        XCTAssertEqual(decoded.keywordWeight, original.keywordWeight, accuracy: 0.001)
        XCTAssertEqual(decoded.semanticWeight, original.semanticWeight, accuracy: 0.001)
    }
}

// MARK: - SemanticPromptTemplate Tests

final class SemanticPromptTemplateTests: XCTestCase {

    func testAllBuiltinTemplatesExist() {
        let templates = SemanticPromptTemplate.allBuiltinTemplates
        XCTAssertEqual(templates.count, 5)
    }

    func testBuiltinTemplatesHaveUniqueIds() {
        let templates = SemanticPromptTemplate.allBuiltinTemplates
        let ids = Set(templates.map(\.id))
        XCTAssertEqual(ids.count, templates.count)
    }

    func testBuiltinTemplatesHaveNames() {
        for template in SemanticPromptTemplate.allBuiltinTemplates {
            XCTAssertFalse(template.name.isEmpty)
            XCTAssertFalse(template.systemPrompt.isEmpty)
            XCTAssertFalse(template.userPromptTemplate.isEmpty)
        }
    }

    func testTemplatePurposeDisplayNames() {
        for purpose in SemanticPromptTemplate.TemplatePurpose.allCases {
            XCTAssertFalse(purpose.displayName.isEmpty)
        }
    }

    func testIntentClassificationTemplate() {
        let template = SemanticPromptTemplate.intentClassificationTemplate
        XCTAssertEqual(template.purpose, .intentClassification)
        XCTAssertTrue(template.userPromptTemplate.contains("{{query}}"))
        XCTAssertEqual(template.temperature, 0.1)
    }

    func testEntityExtractionTemplate() {
        let template = SemanticPromptTemplate.entityExtractionTemplate
        XCTAssertEqual(template.purpose, .entityExtraction)
        XCTAssertEqual(template.temperature, 0.0)
    }

    func testQueryExpansionTemplate() {
        let template = SemanticPromptTemplate.queryExpansionTemplate
        XCTAssertEqual(template.purpose, .queryExpansion)
        XCTAssertTrue(template.userPromptTemplate.contains("{{intent}}"))
    }
}

// MARK: - DecisionTreeNode Tests

final class DecisionTreeNodeTests: XCTestCase {

    func testLeafNode() {
        let node = DecisionTreeNode(
            id: "leaf-1",
            condition: DecisionCondition(type: .containsKeyword, value: "error"),
            resultIntent: .errorDiagnosis
        )
        XCTAssertTrue(node.isLeaf)
    }

    func testBranchNode() {
        let node = DecisionTreeNode(
            id: "branch-1",
            condition: DecisionCondition(type: .hasFileReference, value: ""),
            trueChild: "leaf-1",
            falseChild: "leaf-2"
        )
        XCTAssertFalse(node.isLeaf)
    }

    func testConditionTypes() {
        let types: [DecisionCondition.ConditionType] = [
            .containsKeyword, .startsWithVerb, .hasFileReference,
            .hasErrorPattern, .wordCountGreaterThan, .hasQuestionMark,
            .hasCodeBlock, .languageIs
        ]
        for condType in types {
            let condition = DecisionCondition(type: condType, value: "test")
            XCTAssertEqual(condition.type, condType)
        }
    }
}
