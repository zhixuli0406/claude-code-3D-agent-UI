import Foundation

// MARK: - H5: Semantic Understanding & AI Intent Classification Models

// MARK: - Query Intent

/// The classified intent of a user's natural language query
enum QueryIntent: String, Codable, CaseIterable {
    // Code-related intents
    case codeSearch          // "find the login function"
    case codeFix             // "fix the crash in AuthService"
    case codeExplain         // "how does the caching layer work?"
    case codeRefactor        // "refactor the database module"
    case codeGenerate        // "create a new API endpoint for users"

    // Project-related intents
    case fileNavigation      // "open AppState.swift"
    case dependencyQuery     // "what imports does RAGManager use?"
    case architectureQuery   // "show me the data flow for search"

    // Task-related intents
    case taskCreate          // "add a task to implement dark mode"
    case taskStatus          // "what's the status of the auth feature?"
    case taskDecompose       // "break down the migration task"

    // Knowledge-related intents
    case conceptExplain      // "what is BM25 scoring?"
    case patternMatch        // "find similar code to this function"
    case errorDiagnosis      // "why is this test failing?"

    // System/meta intents
    case systemCommand       // "clear the index" / "rebuild RAG"
    case configChange        // "enable auto-indexing"
    case unknown             // fallback

    var displayName: String {
        switch self {
        case .codeSearch: return "Code Search"
        case .codeFix: return "Code Fix"
        case .codeExplain: return "Code Explanation"
        case .codeRefactor: return "Code Refactor"
        case .codeGenerate: return "Code Generation"
        case .fileNavigation: return "File Navigation"
        case .dependencyQuery: return "Dependency Query"
        case .architectureQuery: return "Architecture Query"
        case .taskCreate: return "Task Creation"
        case .taskStatus: return "Task Status"
        case .taskDecompose: return "Task Decomposition"
        case .conceptExplain: return "Concept Explanation"
        case .patternMatch: return "Pattern Match"
        case .errorDiagnosis: return "Error Diagnosis"
        case .systemCommand: return "System Command"
        case .configChange: return "Configuration"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .codeSearch: return "magnifyingglass"
        case .codeFix: return "wrench.and.screwdriver"
        case .codeExplain: return "questionmark.circle"
        case .codeRefactor: return "arrow.triangle.2.circlepath"
        case .codeGenerate: return "plus.rectangle.on.rectangle"
        case .fileNavigation: return "doc.text"
        case .dependencyQuery: return "arrow.triangle.branch"
        case .architectureQuery: return "building.2"
        case .taskCreate: return "plus.circle"
        case .taskStatus: return "chart.bar"
        case .taskDecompose: return "rectangle.3.group"
        case .conceptExplain: return "lightbulb"
        case .patternMatch: return "square.grid.3x3"
        case .errorDiagnosis: return "exclamationmark.triangle"
        case .systemCommand: return "terminal"
        case .configChange: return "gearshape"
        case .unknown: return "questionmark"
        }
    }

    /// Whether this intent requires RAG context injection
    var needsRAGContext: Bool {
        switch self {
        case .codeSearch, .codeFix, .codeExplain, .codeRefactor, .codeGenerate,
             .dependencyQuery, .architectureQuery, .patternMatch, .errorDiagnosis:
            return true
        case .fileNavigation, .taskCreate, .taskStatus, .taskDecompose,
             .conceptExplain, .systemCommand, .configChange, .unknown:
            return false
        }
    }

    /// Whether this intent benefits from agent memory context
    var needsMemoryContext: Bool {
        switch self {
        case .codeFix, .codeRefactor, .errorDiagnosis, .taskStatus, .patternMatch:
            return true
        default:
            return false
        }
    }

    /// Priority weight for ranking (higher = more important intent)
    var priorityWeight: Float {
        switch self {
        case .codeFix, .errorDiagnosis: return 1.0
        case .codeSearch, .codeGenerate: return 0.9
        case .codeExplain, .codeRefactor: return 0.85
        case .fileNavigation, .dependencyQuery: return 0.8
        case .architectureQuery, .patternMatch: return 0.75
        case .taskCreate, .taskDecompose: return 0.7
        case .taskStatus, .conceptExplain: return 0.6
        case .systemCommand, .configChange: return 0.5
        case .unknown: return 0.3
        }
    }
}

// MARK: - Query Classification Result

/// The result of classifying a user query's intent
struct QueryClassification: Identifiable, Codable {
    let id: String
    var primaryIntent: QueryIntent
    var confidence: Float          // 0.0 - 1.0
    var secondaryIntents: [IntentScore]
    var extractedEntities: [QueryEntity]
    var queryComplexity: QueryComplexity
    var classifiedAt: Date

    init(primaryIntent: QueryIntent, confidence: Float, secondaryIntents: [IntentScore] = [], extractedEntities: [QueryEntity] = [], queryComplexity: QueryComplexity = .simple) {
        self.id = UUID().uuidString
        self.primaryIntent = primaryIntent
        self.confidence = confidence
        self.secondaryIntents = secondaryIntents
        self.extractedEntities = extractedEntities
        self.queryComplexity = queryComplexity
        self.classifiedAt = Date()
    }

    var isHighConfidence: Bool { confidence >= 0.75 }
    var isAmbiguous: Bool { confidence < 0.5 || (!secondaryIntents.isEmpty && secondaryIntents[0].score > confidence * 0.8) }
}

/// A scored intent candidate
struct IntentScore: Codable {
    var intent: QueryIntent
    var score: Float
}

// MARK: - Query Entity

/// An entity extracted from the user's natural language query
struct QueryEntity: Identifiable, Codable {
    let id: String
    var type: EntityType
    var value: String
    var originalSpan: String   // the original text in the query
    var startIndex: Int        // character offset in query
    var confidence: Float

    init(type: EntityType, value: String, originalSpan: String, startIndex: Int, confidence: Float = 1.0) {
        self.id = UUID().uuidString
        self.type = type
        self.value = value
        self.originalSpan = originalSpan
        self.startIndex = startIndex
        self.confidence = confidence
    }

    enum EntityType: String, Codable, CaseIterable {
        case fileName        // "AppState.swift"
        case className       // "RAGSystemManager"
        case functionName    // "search(query:)"
        case variableName    // "indexStats"
        case filePath        // "Services/RAGDatabaseManager.swift"
        case fileType        // "Swift", ".py"
        case errorMessage    // "nil is not convertible to String"
        case frameworkName   // "SceneKit", "SwiftUI"
        case taskName        // "implement dark mode"
        case configKey       // "auto-indexing"
        case lineNumber      // "line 42"
        case codePattern     // "singleton", "factory"
        case keyword         // general technical keyword

        var displayName: String {
            switch self {
            case .fileName: return "File"
            case .className: return "Class"
            case .functionName: return "Function"
            case .variableName: return "Variable"
            case .filePath: return "Path"
            case .fileType: return "File Type"
            case .errorMessage: return "Error"
            case .frameworkName: return "Framework"
            case .taskName: return "Task"
            case .configKey: return "Config"
            case .lineNumber: return "Line"
            case .codePattern: return "Pattern"
            case .keyword: return "Keyword"
            }
        }
    }
}

// MARK: - Query Complexity

/// How complex the parsed query is
enum QueryComplexity: String, Codable {
    case trivial     // single keyword: "AppState"
    case simple      // short phrase: "find login function"
    case moderate    // sentence with context: "fix the crash that happens when user logs in"
    case complex     // multi-part with constraints: "refactor AuthService to use async/await, ensure tests pass"
    case compound    // multiple distinct sub-queries

    var maxSearchDepth: Int {
        switch self {
        case .trivial: return 5
        case .simple: return 10
        case .moderate: return 15
        case .complex: return 20
        case .compound: return 25
        }
    }

    var suggestedRAGSnippets: Int {
        switch self {
        case .trivial: return 3
        case .simple: return 5
        case .moderate: return 7
        case .complex: return 10
        case .compound: return 12
        }
    }
}

// MARK: - Preprocessed Query

/// A query after NLP preprocessing: normalized, tokenized, entities extracted
struct PreprocessedQuery: Identifiable, Codable {
    let id: String
    var originalQuery: String
    var normalizedQuery: String
    var tokens: [String]
    var stemmedTokens: [String]
    var stopWordsRemoved: [String]
    var detectedLanguage: QueryLanguage
    var entities: [QueryEntity]
    var expandedTerms: [String]       // synonyms and related terms
    var ftsQuery: String              // ready-to-use FTS5 query
    var semanticKeywords: [String]    // top keywords for semantic matching
    var preprocessedAt: Date

    init(originalQuery: String) {
        self.id = UUID().uuidString
        self.originalQuery = originalQuery
        self.normalizedQuery = originalQuery
        self.tokens = []
        self.stemmedTokens = []
        self.stopWordsRemoved = []
        self.detectedLanguage = .english
        self.entities = []
        self.expandedTerms = []
        self.ftsQuery = ""
        self.semanticKeywords = []
        self.preprocessedAt = Date()
    }
}

/// Detected language of the query
enum QueryLanguage: String, Codable {
    case english
    case chineseTraditional
    case chineseSimplified
    case japanese
    case mixed

    var stopWords: [String] {
        switch self {
        case .english:
            return ["the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
                    "have", "has", "had", "do", "does", "did", "will", "would", "could",
                    "should", "may", "might", "can", "shall", "of", "in", "to", "for",
                    "with", "on", "at", "from", "by", "as", "into", "about", "it", "its",
                    "this", "that", "these", "those", "i", "me", "my", "we", "our", "you",
                    "your", "he", "she", "they", "them", "and", "or", "but", "not", "so"]
        case .chineseTraditional, .chineseSimplified:
            return ["的", "了", "在", "是", "我", "有", "和", "就", "不", "人",
                    "都", "一", "一個", "上", "也", "很", "到", "說", "要", "去",
                    "你", "會", "著", "沒有", "看", "好", "自己", "這", "他", "她",
                    "那", "被", "從", "把", "讓", "給", "它"]
        case .japanese:
            return ["の", "に", "は", "を", "た", "が", "で", "て", "と", "し",
                    "れ", "さ", "ある", "いる", "も", "する", "から", "な", "こと",
                    "として", "い", "や", "など", "なっ", "ない", "この", "ため"]
        case .mixed:
            return []
        }
    }
}

// MARK: - Semantic Search Result (Enhanced RAG Result)

/// Enhanced search result combining BM25 keyword score with semantic relevance
struct SemanticSearchResult: Identifiable {
    let id: String
    var ragResult: RAGSearchResult?           // original BM25-based result
    var memoryResult: AgentMemory?            // from agent memory
    var source: SearchResultSource
    var keywordScore: Float                   // BM25 / FTS5 score
    var semanticRelevance: Float              // intent-based relevance 0.0-1.0
    var entityMatchScore: Float               // how many extracted entities matched
    var recencyScore: Float                   // time-based freshness
    var relationshipScore: Float              // dependency/import graph proximity
    var combinedScore: Float                  // weighted final score
    var matchedEntities: [QueryEntity]        // which entities were found
    var snippetWithHighlights: String         // snippet with matched terms highlighted
    var explanationNote: String               // why this result was ranked here

    init(ragResult: RAGSearchResult? = nil, memoryResult: AgentMemory? = nil, source: SearchResultSource) {
        self.id = UUID().uuidString
        self.ragResult = ragResult
        self.memoryResult = memoryResult
        self.source = source
        self.keywordScore = 0
        self.semanticRelevance = 0
        self.entityMatchScore = 0
        self.recencyScore = 0
        self.relationshipScore = 0
        self.combinedScore = 0
        self.matchedEntities = []
        self.snippetWithHighlights = ""
        self.explanationNote = ""
    }
}

/// Where a search result came from
enum SearchResultSource: String, Codable {
    case ragFullText        // RAG FTS5 keyword search
    case ragRelationship    // RAG dependency graph traversal
    case agentMemory        // agent memory recall
    case entityDirect       // direct entity match (file name, class name)
    case semanticExpansion  // found via synonym/term expansion
}

// MARK: - Semantic Search Response

/// The complete response from the semantic search orchestrator
struct SemanticSearchResponse: Identifiable {
    let id: String
    var query: PreprocessedQuery
    var classification: QueryClassification
    var results: [SemanticSearchResult]
    var ragContext: String                   // formatted context for prompt injection
    var suggestedPrompt: String?            // AI-generated prompt refinement
    var processingTimeMs: Int
    var totalCandidates: Int                // how many results were considered before ranking
    var searchedAt: Date

    var topResults: [SemanticSearchResult] {
        Array(results.prefix(10))
    }

    var hasResults: Bool { !results.isEmpty }
}

// MARK: - Scoring Weights Configuration

/// Configurable weights for multi-dimensional result ranking
struct SemanticScoringWeights: Codable {
    var keywordWeight: Float      // BM25 text match
    var semanticWeight: Float     // intent-based relevance
    var entityWeight: Float       // entity match boost
    var recencyWeight: Float      // freshness
    var relationshipWeight: Float // graph proximity

    static let `default` = SemanticScoringWeights(
        keywordWeight: 0.30,
        semanticWeight: 0.30,
        entityWeight: 0.20,
        recencyWeight: 0.10,
        relationshipWeight: 0.10
    )

    static let codeSearch = SemanticScoringWeights(
        keywordWeight: 0.35,
        semanticWeight: 0.20,
        entityWeight: 0.25,
        recencyWeight: 0.05,
        relationshipWeight: 0.15
    )

    static let errorDiagnosis = SemanticScoringWeights(
        keywordWeight: 0.20,
        semanticWeight: 0.25,
        entityWeight: 0.15,
        recencyWeight: 0.25,
        relationshipWeight: 0.15
    )

    /// Calculate combined score from individual dimensions
    func combine(keyword: Float, semantic: Float, entity: Float, recency: Float, relationship: Float) -> Float {
        return keyword * keywordWeight
            + semantic * semanticWeight
            + entity * entityWeight
            + recency * recencyWeight
            + relationship * relationshipWeight
    }
}

// MARK: - Prompt Templates for AI Semantic Judgment

/// Templates used to construct prompts for AI-based semantic understanding
struct SemanticPromptTemplate: Identifiable, Codable {
    let id: String
    var name: String
    var purpose: TemplatePurpose
    var systemPrompt: String
    var userPromptTemplate: String   // uses {{variable}} placeholders
    var expectedOutputFormat: String
    var maxTokens: Int
    var temperature: Double

    enum TemplatePurpose: String, Codable, CaseIterable {
        case intentClassification
        case entityExtraction
        case queryExpansion
        case resultReranking
        case answerSynthesis

        var displayName: String {
            switch self {
            case .intentClassification: return "Intent Classification"
            case .entityExtraction: return "Entity Extraction"
            case .queryExpansion: return "Query Expansion"
            case .resultReranking: return "Result Re-ranking"
            case .answerSynthesis: return "Answer Synthesis"
            }
        }
    }

    // MARK: Built-in Templates

    static let intentClassificationTemplate = SemanticPromptTemplate(
        id: "builtin-intent-classification",
        name: "Intent Classification",
        purpose: .intentClassification,
        systemPrompt: """
            You are an intent classifier for a code project management tool. \
            Classify the user's query into exactly one primary intent and up to 2 secondary intents. \
            Return JSON only.
            """,
        userPromptTemplate: """
            Classify this query: "{{query}}"

            Project context: {{projectContext}}
            Recent files: {{recentFiles}}

            Available intents: codeSearch, codeFix, codeExplain, codeRefactor, codeGenerate, \
            fileNavigation, dependencyQuery, architectureQuery, taskCreate, taskStatus, \
            taskDecompose, conceptExplain, patternMatch, errorDiagnosis, systemCommand, configChange

            Return JSON: {"primary": {"intent": "...", "confidence": 0.0-1.0}, "secondary": [{"intent": "...", "score": 0.0-1.0}]}
            """,
        expectedOutputFormat: """
            {"primary": {"intent": "codeSearch", "confidence": 0.92}, "secondary": [{"intent": "fileNavigation", "score": 0.45}]}
            """,
        maxTokens: 200,
        temperature: 0.1
    )

    static let entityExtractionTemplate = SemanticPromptTemplate(
        id: "builtin-entity-extraction",
        name: "Entity Extraction",
        purpose: .entityExtraction,
        systemPrompt: """
            You are an entity extractor for a code project tool. \
            Extract all code-related entities from the query. \
            Return JSON only.
            """,
        userPromptTemplate: """
            Extract entities from: "{{query}}"

            Known files: {{knownFiles}}
            Known classes: {{knownClasses}}

            Entity types: fileName, className, functionName, variableName, filePath, fileType, \
            errorMessage, frameworkName, taskName, configKey, lineNumber, codePattern, keyword

            Return JSON array: [{"type": "...", "value": "...", "span": "...", "confidence": 0.0-1.0}]
            """,
        expectedOutputFormat: """
            [{"type": "className", "value": "RAGSystemManager", "span": "RAG manager", "confidence": 0.85}]
            """,
        maxTokens: 300,
        temperature: 0.0
    )

    static let queryExpansionTemplate = SemanticPromptTemplate(
        id: "builtin-query-expansion",
        name: "Query Expansion",
        purpose: .queryExpansion,
        systemPrompt: """
            You are a query expansion engine for code search. \
            Generate synonyms, related terms, and alternative phrasings. \
            Return JSON only.
            """,
        userPromptTemplate: """
            Expand this search query: "{{query}}"
            Detected intent: {{intent}}
            Project language: {{language}}

            Generate up to 5 alternative search terms or phrases that would find relevant results.

            Return JSON: {"expandedTerms": ["term1", "term2", ...], "alternativeQueries": ["query1", "query2", ...]}
            """,
        expectedOutputFormat: """
            {"expandedTerms": ["authentication", "login", "auth", "sign in"], "alternativeQueries": ["login function implementation", "auth service"]}
            """,
        maxTokens: 200,
        temperature: 0.3
    )

    static let resultRerankingTemplate = SemanticPromptTemplate(
        id: "builtin-result-reranking",
        name: "Result Re-ranking",
        purpose: .resultReranking,
        systemPrompt: """
            You are a search result relevance judge. \
            Given a query and a list of code snippets, re-rank them by relevance. \
            Return JSON only.
            """,
        userPromptTemplate: """
            Query: "{{query}}"
            Intent: {{intent}}

            Results to rank:
            {{results}}

            Re-rank by relevance. Return JSON: {"rankings": [{"index": 0, "relevance": 0.0-1.0, "reason": "..."}]}
            """,
        expectedOutputFormat: """
            {"rankings": [{"index": 0, "relevance": 0.95, "reason": "Direct match for the requested function"}, {"index": 2, "relevance": 0.72, "reason": "Related utility used by the target"}]}
            """,
        maxTokens: 500,
        temperature: 0.1
    )

    static let answerSynthesisTemplate = SemanticPromptTemplate(
        id: "builtin-answer-synthesis",
        name: "Answer Synthesis",
        purpose: .answerSynthesis,
        systemPrompt: """
            You are a code assistant for a project management tool. \
            Synthesize a helpful answer from the provided context and search results. \
            Be concise and reference specific files/functions.
            """,
        userPromptTemplate: """
            User query: "{{query}}"
            Intent: {{intent}}

            Relevant code context:
            {{context}}

            Agent memory (if relevant):
            {{memory}}

            Provide a concise, actionable answer. Reference specific files and line numbers where applicable.
            """,
        expectedOutputFormat: "A natural language answer with code references.",
        maxTokens: 1000,
        temperature: 0.4
    )

    static var allBuiltinTemplates: [SemanticPromptTemplate] {
        [intentClassificationTemplate, entityExtractionTemplate, queryExpansionTemplate, resultRerankingTemplate, answerSynthesisTemplate]
    }
}

// MARK: - Decision Tree Node

/// Represents a node in the intent classification decision tree (rule-based fallback)
struct DecisionTreeNode: Identifiable, Codable {
    let id: String
    var condition: DecisionCondition
    var trueChild: String?    // id of the child node when condition is true
    var falseChild: String?   // id of the child node when condition is false
    var resultIntent: QueryIntent?  // leaf node result

    var isLeaf: Bool { resultIntent != nil }
}

/// A condition evaluated in the decision tree
struct DecisionCondition: Codable {
    var type: ConditionType
    var value: String

    enum ConditionType: String, Codable {
        case containsKeyword        // query contains specific keyword
        case startsWithVerb         // query starts with action verb
        case hasFileReference       // query mentions a file
        case hasErrorPattern        // query contains error-like text
        case wordCountGreaterThan   // query word count threshold
        case hasQuestionMark        // is a question
        case hasCodeBlock           // contains backtick code blocks
        case languageIs             // detected language matches
    }
}
