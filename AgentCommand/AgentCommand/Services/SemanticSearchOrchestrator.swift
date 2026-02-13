import Foundation
import Combine

// MARK: - H5: Semantic Search Orchestrator

/// Orchestrates the full semantic understanding pipeline and merges results
/// from RAG keyword search, entity matching, agent memory, and relationship graph
/// into a unified, multi-dimensionally ranked result set.
///
/// ## End-to-End Flow Chart:
/// ```
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                    User enters query                            │
/// └──────────────────────────┬──────────────────────────────────────┘
///                            ▼
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  Phase 1: PREPROCESS (SemanticQueryProcessor)                   │
/// │  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────┐ │
/// │  │Normalize │→│Detect    │→│Tokenize  │→│Remove    │→│Stem/  │ │
/// │  │         │ │Language  │ │          │ │StopWords │ │Lemma  │ │
/// │  └─────────┘ └──────────┘ └──────────┘ └──────────┘ └───┬───┘ │
/// │  ┌──────────┐ ┌──────────┐ ┌──────────┐                 │     │
/// │  │Extract   │→│Expand    │→│Build FTS │←────────────────┘     │
/// │  │Entities  │ │Terms     │ │Query     │                       │
/// │  └──────────┘ └──────────┘ └──────────┘                       │
/// │                            OUTPUT: PreprocessedQuery           │
/// └──────────────────────────┬──────────────────────────────────────┘
///                            ▼
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  Phase 2: CLASSIFY (IntentClassifier)                           │
/// │  ┌──────────────────────────┐  ┌──────────────────────────┐    │
/// │  │ Rule-based Decision Tree │  │ AI Model Fallback        │    │
/// │  │ (fast, deterministic)    │──│ (when confidence < 0.6)  │    │
/// │  └──────────────────────────┘  └──────────────────────────┘    │
/// │                            OUTPUT: QueryClassification         │
/// └──────────────────────────┬──────────────────────────────────────┘
///                            ▼
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  Phase 3: SEARCH (Parallel multi-source retrieval)              │
/// │                                                                 │
/// │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
/// │  │ RAG FTS5     │  │ Entity Direct│  │ Agent Memory         │  │
/// │  │ Keyword      │  │ File/Class   │  │ Recall               │  │
/// │  │ Search       │  │ Lookup       │  │ (if intent needs it) │  │
/// │  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
/// │         │                 │                      │              │
/// │         └─────────────────┼──────────────────────┘              │
/// │                           ▼                                     │
/// │              ┌───────────────────────┐                          │
/// │              │ Candidate Pool        │                          │
/// │              │ (deduplicated)        │                          │
/// │              └───────────┬───────────┘                          │
/// └──────────────────────────┬──────────────────────────────────────┘
///                            ▼
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  Phase 4: RANK (Multi-dimensional scoring)                      │
/// │                                                                 │
/// │  For each candidate:                                            │
/// │  ┌─────────────────────────────────────────────────────┐       │
/// │  │ keywordScore    ← BM25 from FTS5               (30%) │       │
/// │  │ semanticRelevance ← intent alignment             (30%) │       │
/// │  │ entityMatchScore ← extracted entity overlap      (20%) │       │
/// │  │ recencyScore    ← file modification freshness   (10%) │       │
/// │  │ relationshipScore ← dependency graph proximity   (10%) │       │
/// │  │                                                       │       │
/// │  │ combinedScore = weighted sum via ScoringWeights       │       │
/// │  └─────────────────────────────────────────────────────┘       │
/// │                                                                 │
/// │  Sort by combinedScore DESC                                    │
/// │                            OUTPUT: [SemanticSearchResult]      │
/// └──────────────────────────┬──────────────────────────────────────┘
///                            ▼
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  Phase 5: FORMAT (Context assembly)                             │
/// │  ┌─────────────────┐  ┌──────────────────┐                     │
/// │  │ Build RAG       │  │ Generate prompt  │                     │
/// │  │ context string  │  │ refinement       │                     │
/// │  └─────────────────┘  └──────────────────┘                     │
/// │                            OUTPUT: SemanticSearchResponse      │
/// └─────────────────────────────────────────────────────────────────┘
/// ```
@MainActor
class SemanticSearchOrchestrator: ObservableObject {

    // MARK: - Dependencies

    let queryProcessor = SemanticQueryProcessor()
    let intentClassifier = IntentClassifier()

    /// Injected from AppState at runtime
    weak var ragManager: RAGSystemManager?
    weak var memoryManager: AgentMemorySystemManager?

    // MARK: - Published State

    @Published var lastResponse: SemanticSearchResponse?
    @Published var isProcessing: Bool = false
    @Published var scoringWeights: SemanticScoringWeights = .default

    // MARK: - Main Orchestration

    /// Execute the full semantic search pipeline
    func search(query: String) -> SemanticSearchResponse {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }

        // Phase 1: Preprocess
        updateKnownEntities()
        let preprocessed = queryProcessor.preprocess(query)

        // Phase 2: Classify intent
        let classification = intentClassifier.classify(preprocessed)

        // Select scoring weights based on intent
        let weights = weightsForIntent(classification.primaryIntent)

        // Phase 3: Multi-source search
        var candidates: [SemanticSearchResult] = []

        // 3a: RAG FTS5 keyword search
        let ragResults = performRAGSearch(preprocessed: preprocessed, classification: classification)
        candidates.append(contentsOf: ragResults)

        // 3b: Direct entity match
        let entityResults = performEntitySearch(preprocessed: preprocessed)
        candidates.append(contentsOf: entityResults)

        // 3c: Agent memory recall (if intent requires it)
        if classification.primaryIntent.needsMemoryContext {
            let memoryResults = performMemorySearch(preprocessed: preprocessed)
            candidates.append(contentsOf: memoryResults)
        }

        // Deduplicate by file path
        candidates = deduplicateCandidates(candidates)

        let totalCandidates = candidates.count

        // Phase 4: Multi-dimensional scoring
        let scored = scoreCandidates(candidates, preprocessed: preprocessed, classification: classification, weights: weights)

        // Phase 5: Format response
        let ragContext = buildRAGContext(from: scored, classification: classification)
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)

        let response = SemanticSearchResponse(
            id: UUID().uuidString,
            query: preprocessed,
            classification: classification,
            results: scored,
            ragContext: ragContext,
            suggestedPrompt: generatePromptRefinement(query: query, classification: classification),
            processingTimeMs: processingTime,
            totalCandidates: totalCandidates,
            searchedAt: Date()
        )

        lastResponse = response
        return response
    }

    // MARK: - Async Orchestration (with AI Classification Fallback)

    /// Execute the full semantic search pipeline with async AI-enhanced classification
    func searchAsync(query: String) async -> SemanticSearchResponse {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }

        // Phase 1: Preprocess
        updateKnownEntities()
        let preprocessed = queryProcessor.preprocess(query)

        // Phase 2: Classify intent (async with AI fallback)
        let projectContext = buildProjectContext()
        let recentFiles = ragManager?.documents.prefix(10).map(\.fileName) ?? []
        let classification = await intentClassifier.classifyAsync(
            preprocessed,
            projectContext: projectContext,
            recentFiles: Array(recentFiles)
        )

        // Phase 3-5: Same as sync pipeline
        return executeSearchPipeline(
            query: query,
            preprocessed: preprocessed,
            classification: classification,
            startTime: startTime
        )
    }

    /// Shared search pipeline for phases 3-5 (used by both sync and async)
    private func executeSearchPipeline(query: String, preprocessed: PreprocessedQuery, classification: QueryClassification, startTime: Date) -> SemanticSearchResponse {
        let weights = weightsForIntent(classification.primaryIntent)

        // Phase 3: Multi-source search
        var candidates: [SemanticSearchResult] = []
        candidates.append(contentsOf: performRAGSearch(preprocessed: preprocessed, classification: classification))
        candidates.append(contentsOf: performEntitySearch(preprocessed: preprocessed))
        if classification.primaryIntent.needsMemoryContext {
            candidates.append(contentsOf: performMemorySearch(preprocessed: preprocessed))
        }
        candidates = deduplicateCandidates(candidates)
        let totalCandidates = candidates.count

        // Phase 4: Multi-dimensional scoring
        let scored = scoreCandidates(candidates, preprocessed: preprocessed, classification: classification, weights: weights)

        // Phase 5: Format response
        let ragContext = buildRAGContext(from: scored, classification: classification)
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)

        let response = SemanticSearchResponse(
            id: UUID().uuidString,
            query: preprocessed,
            classification: classification,
            results: scored,
            ragContext: ragContext,
            suggestedPrompt: generatePromptRefinement(query: query, classification: classification),
            processingTimeMs: processingTime,
            totalCandidates: totalCandidates,
            searchedAt: Date()
        )

        lastResponse = response
        return response
    }

    /// Build a brief project context string for AI classification
    private func buildProjectContext() -> String {
        guard let rag = ragManager else { return "Unknown project" }
        let stats = rag.indexStats
        let fileTypes = Dictionary(grouping: rag.documents, by: \.fileType)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\($0.key.displayName): \($0.value)" }
            .joined(separator: ", ")
        return "Project with \(stats.totalDocuments) files (\(fileTypes))"
    }

    // MARK: - Phase 3a: RAG Search

    private func performRAGSearch(preprocessed: PreprocessedQuery, classification: QueryClassification) -> [SemanticSearchResult] {
        guard let rag = ragManager else { return [] }

        let limit = classification.queryComplexity.maxSearchDepth

        // Use the enhanced FTS query from preprocessing
        let ftsQuery = preprocessed.ftsQuery
        guard !ftsQuery.isEmpty else { return [] }

        let ragResults = rag.dbManager.search(query: ftsQuery, limit: limit)

        return ragResults.map { ragResult in
            var result = SemanticSearchResult(ragResult: ragResult, source: .ragFullText)
            result.keywordScore = ragResult.score
            result.snippetWithHighlights = ragResult.matchedSnippet
            return result
        }
    }

    // MARK: - Phase 3b: Entity Direct Search

    private func performEntitySearch(preprocessed: PreprocessedQuery) -> [SemanticSearchResult] {
        guard let rag = ragManager else { return [] }

        var results: [SemanticSearchResult] = []

        for entity in preprocessed.entities {
            switch entity.type {
            case .fileName, .filePath:
                // Direct file lookup
                if let doc = rag.documents.first(where: {
                    $0.fileName.localizedCaseInsensitiveContains(entity.value) ||
                    $0.filePath.localizedCaseInsensitiveContains(entity.value)
                }) {
                    let ragResult = RAGSearchResult(
                        document: doc,
                        matchedSnippet: doc.contentPreview,
                        score: 1.0
                    )
                    var result = SemanticSearchResult(ragResult: ragResult, source: .entityDirect)
                    result.keywordScore = 1.0
                    result.entityMatchScore = 1.0
                    result.matchedEntities = [entity]
                    results.append(result)
                }

            case .className, .functionName:
                // Search for the entity value directly
                let classResults = rag.dbManager.search(query: "\"\(entity.value)\"", limit: 5)
                for ragResult in classResults {
                    var result = SemanticSearchResult(ragResult: ragResult, source: .entityDirect)
                    result.keywordScore = ragResult.score
                    result.entityMatchScore = entity.confidence
                    result.matchedEntities = [entity]
                    results.append(result)
                }

            default:
                break
            }
        }

        return results
    }

    // MARK: - Phase 3c: Agent Memory Search

    private func performMemorySearch(preprocessed: PreprocessedQuery) -> [SemanticSearchResult] {
        guard let memory = memoryManager else { return [] }

        let keywords = preprocessed.semanticKeywords.joined(separator: " ")
        let recalled = memory.recallForTask(agentName: "", taskPrompt: keywords)

        return recalled.prefix(5).map { agentMemory in
            var result = SemanticSearchResult(memoryResult: agentMemory, source: .agentMemory)
            result.keywordScore = agentMemory.decayedScore
            result.snippetWithHighlights = agentMemory.summary
            return result
        }
    }

    // MARK: - Phase 4: Multi-Dimensional Scoring

    private func scoreCandidates(_ candidates: [SemanticSearchResult], preprocessed: PreprocessedQuery, classification: QueryClassification, weights: SemanticScoringWeights) -> [SemanticSearchResult] {

        let maxKeywordScore = candidates.map(\.keywordScore).max() ?? 1.0

        return candidates.map { candidate in
            var scored = candidate

            // Normalize keyword score to 0-1
            let normalizedKeyword = maxKeywordScore > 0 ? scored.keywordScore / maxKeywordScore : 0

            // Semantic relevance: how well does this result align with the detected intent?
            let semanticRelevance = computeSemanticRelevance(candidate: candidate, intent: classification.primaryIntent, entities: preprocessed.entities)

            // Entity match score: what fraction of extracted entities are found in this result?
            let entityMatch = computeEntityMatchScore(candidate: candidate, entities: preprocessed.entities)

            // Recency score: how recently was the file modified?
            let recency = computeRecencyScore(candidate: candidate)

            // Relationship score: how close in the dependency graph?
            let relationship = computeRelationshipScore(candidate: candidate, entities: preprocessed.entities)

            scored.keywordScore = normalizedKeyword
            scored.semanticRelevance = semanticRelevance
            scored.entityMatchScore = entityMatch
            scored.recencyScore = recency
            scored.relationshipScore = relationship

            // Combined weighted score
            scored.combinedScore = weights.combine(
                keyword: normalizedKeyword,
                semantic: semanticRelevance,
                entity: entityMatch,
                recency: recency,
                relationship: relationship
            )

            // Generate explanation
            scored.explanationNote = generateExplanation(scored, weights: weights)

            return scored
        }
        .sorted { $0.combinedScore > $1.combinedScore }
    }

    // MARK: - Scoring Dimensions

    private func computeSemanticRelevance(candidate: SemanticSearchResult, intent: QueryIntent, entities: [QueryEntity]) -> Float {
        guard let ragResult = candidate.ragResult else {
            // Memory results get base relevance from their own score
            return candidate.memoryResult?.decayedScore ?? 0.3
        }

        var relevance: Float = 0.3

        let doc = ragResult.document

        // Intent-specific boosts
        switch intent {
        case .codeSearch, .codeExplain:
            // Prefer source code files
            if [.swift, .python, .javascript, .typescript].contains(doc.fileType) {
                relevance += 0.2
            }
        case .codeFix, .errorDiagnosis:
            // Prefer files with test or error patterns
            let snippet = ragResult.matchedSnippet.lowercased()
            if snippet.contains("error") || snippet.contains("catch") || snippet.contains("throw") {
                relevance += 0.3
            }
        case .fileNavigation:
            // Direct entity match is highly relevant
            if !candidate.matchedEntities.isEmpty {
                relevance += 0.5
            }
        case .dependencyQuery, .architectureQuery:
            // Prefer files with many imports
            if doc.lineCount > 50 { relevance += 0.1 }
        case .codeRefactor, .codeGenerate:
            if [.swift, .python, .javascript, .typescript].contains(doc.fileType) {
                relevance += 0.15
            }
        default:
            break
        }

        // Boost if file type matches entity file type references
        let requestedTypes = entities.filter { $0.type == .fileType }.map(\.value)
        if !requestedTypes.isEmpty && requestedTypes.contains(doc.fileType.rawValue) {
            relevance += 0.2
        }

        return min(relevance, 1.0)
    }

    private func computeEntityMatchScore(candidate: SemanticSearchResult, entities: [QueryEntity]) -> Float {
        guard !entities.isEmpty else { return 0 }
        guard let ragResult = candidate.ragResult else { return 0 }

        let doc = ragResult.document
        let snippet = ragResult.matchedSnippet.lowercased()
        let filePath = doc.filePath.lowercased()

        var matchCount = 0
        for entity in entities {
            let lower = entity.value.lowercased()
            if snippet.contains(lower) || filePath.contains(lower) || doc.fileName.lowercased().contains(lower) {
                matchCount += 1
            }
        }

        return Float(matchCount) / Float(entities.count)
    }

    private func computeRecencyScore(candidate: SemanticSearchResult) -> Float {
        guard let ragResult = candidate.ragResult else {
            // Memory results use their own recency
            if let memory = candidate.memoryResult {
                let hoursSince = Float(Date().timeIntervalSince(memory.lastAccessedAt) / 3600)
                return max(0, 1.0 - hoursSince / 720) // decay over 30 days
            }
            return 0.5
        }

        let hoursSinceModified = Float(Date().timeIntervalSince(ragResult.document.lastModified) / 3600)
        // Exponential decay: 1.0 for just modified, ~0.5 at 7 days, ~0.1 at 30 days
        return max(0, exp(-hoursSinceModified / 168))
    }

    private func computeRelationshipScore(candidate: SemanticSearchResult, entities: [QueryEntity]) -> Float {
        guard let rag = ragManager, let ragResult = candidate.ragResult else { return 0 }

        let docId = ragResult.document.id

        // Check if this document has relationships to any entity-matched documents
        let entityFileNames = entities.filter { $0.type == .fileName }.map(\.value)
        let entityDocs = rag.documents.filter { doc in
            entityFileNames.contains { doc.fileName.localizedCaseInsensitiveContains($0) }
        }

        for entityDoc in entityDocs {
            let hasRelation = rag.relationships.contains { rel in
                (rel.sourceId == docId && rel.targetId == entityDoc.id) ||
                (rel.targetId == docId && rel.sourceId == entityDoc.id)
            }
            if hasRelation { return 0.8 }
        }

        // Check if it has any relationships at all (graph connected vs isolated)
        let hasAnyRelation = rag.relationships.contains { $0.sourceId == docId || $0.targetId == docId }
        return hasAnyRelation ? 0.3 : 0.1
    }

    // MARK: - Phase 5: Context Assembly

    private func buildRAGContext(from results: [SemanticSearchResult], classification: QueryClassification) -> String {
        let topResults = results.prefix(classification.queryComplexity.suggestedRAGSnippets)
        guard !topResults.isEmpty else { return "" }

        var context = "--- Relevant context from project files (semantic search) ---\n"
        context += "Query intent: \(classification.primaryIntent.displayName) (confidence: \(String(format: "%.0f%%", classification.confidence * 100)))\n\n"

        for (index, result) in topResults.enumerated() {
            if let ragResult = result.ragResult {
                context += "[\(index + 1)] File: \(ragResult.document.filePath)"
                if !result.matchedEntities.isEmpty {
                    let entityNames = result.matchedEntities.map { "\($0.type.displayName): \($0.value)" }
                    context += " | Matched: \(entityNames.joined(separator: ", "))"
                }
                context += " | Score: \(String(format: "%.2f", result.combinedScore))\n"
                context += ragResult.matchedSnippet
                    .replacingOccurrences(of: ">>>", with: "")
                    .replacingOccurrences(of: "<<<", with: "")
                context += "\n\n"
            } else if let memory = result.memoryResult {
                context += "[\(index + 1)] Memory: \(memory.taskTitle) (\(memory.category.displayName))\n"
                context += memory.summary
                context += "\n\n"
            }
        }

        context += "--- End of context ---\n"
        return context
    }

    // MARK: - Prompt Refinement

    private func generatePromptRefinement(query: String, classification: QueryClassification) -> String? {
        guard classification.isAmbiguous else { return nil }

        var suggestion = "Your query seems ambiguous. "

        switch classification.primaryIntent {
        case .codeSearch:
            suggestion += "Try specifying a file name or class: e.g., \"find the search function in RAGSystemManager\""
        case .codeFix:
            suggestion += "Include the error message or file: e.g., \"fix the nil crash in AppState.swift line 42\""
        case .unknown:
            suggestion += "Try starting with an action verb: find, fix, add, explain, refactor"
        default:
            suggestion += "Add more specific details like file names, class names, or error messages."
        }

        return suggestion
    }

    // MARK: - Explanation Generator

    private func generateExplanation(_ result: SemanticSearchResult, weights: SemanticScoringWeights) -> String {
        var parts: [String] = []

        if result.keywordScore > 0.7 { parts.append("strong keyword match") }
        if result.semanticRelevance > 0.7 { parts.append("high intent relevance") }
        if result.entityMatchScore > 0.5 { parts.append("entity match") }
        if result.recencyScore > 0.7 { parts.append("recently modified") }
        if result.relationshipScore > 0.5 { parts.append("related via imports") }

        if parts.isEmpty { parts.append("partial match") }

        return parts.joined(separator: ", ").prefix(1).uppercased() + parts.joined(separator: ", ").dropFirst()
    }

    // MARK: - Helpers

    private func weightsForIntent(_ intent: QueryIntent) -> SemanticScoringWeights {
        switch intent {
        case .codeSearch, .fileNavigation:
            return .codeSearch
        case .errorDiagnosis, .codeFix:
            return .errorDiagnosis
        default:
            return .default
        }
    }

    private func deduplicateCandidates(_ candidates: [SemanticSearchResult]) -> [SemanticSearchResult] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            let key: String
            if let rag = candidate.ragResult {
                key = rag.document.filePath
            } else if let mem = candidate.memoryResult {
                key = "memory-\(mem.id)"
            } else {
                key = candidate.id
            }

            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func updateKnownEntities() {
        guard let rag = ragManager else { return }
        queryProcessor.updateKnownEntities(documents: rag.documents)
    }

    // MARK: - AI-Enhanced Query Expansion

    /// Call AI to expand query terms for better recall (async, optional)
    func expandQueryWithAI(query: String, intent: QueryIntent) async -> [String] {
        guard let apiKey = IntentClassifier.resolveAnthropicAPIKey(), !apiKey.isEmpty else {
            return []
        }

        let template = SemanticPromptTemplate.queryExpansionTemplate
        var userPrompt = template.userPromptTemplate
        userPrompt = userPrompt.replacingOccurrences(of: "{{query}}", with: query)
        userPrompt = userPrompt.replacingOccurrences(of: "{{intent}}", with: intent.rawValue)
        userPrompt = userPrompt.replacingOccurrences(of: "{{language}}", with: "Swift")

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": template.maxTokens,
            "temperature": template.temperature,
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "system": template.systemPrompt
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                return []
            }

            // Parse the expanded terms from JSON response
            if let jsonStart = text.firstIndex(of: "{"),
               let jsonEnd = text.lastIndex(of: "}") {
                let jsonStr = String(text[jsonStart...jsonEnd])
                if let jsonData = jsonStr.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let terms = parsed["expandedTerms"] as? [String] {
                    return terms
                }
            }
            return []
        } catch {
            return []
        }
    }

    // MARK: - AI-Enhanced Result Reranking

    /// Optionally rerank top results using AI for improved precision
    func rerankWithAI(query: String, intent: QueryIntent, results: [SemanticSearchResult]) async -> [SemanticSearchResult] {
        guard results.count > 1,
              let apiKey = IntentClassifier.resolveAnthropicAPIKey(), !apiKey.isEmpty else {
            return results
        }

        // Only rerank top N to limit API cost
        let topN = min(results.count, 10)
        let toRerank = Array(results.prefix(topN))
        let remaining = Array(results.dropFirst(topN))

        let template = SemanticPromptTemplate.resultRerankingTemplate
        var userPrompt = template.userPromptTemplate
        userPrompt = userPrompt.replacingOccurrences(of: "{{query}}", with: query)
        userPrompt = userPrompt.replacingOccurrences(of: "{{intent}}", with: intent.rawValue)

        // Format results for the prompt
        let resultsText = toRerank.enumerated().map { index, result in
            let filePath = result.ragResult?.document.filePath ?? result.memoryResult?.taskTitle ?? "unknown"
            let snippet = (result.ragResult?.matchedSnippet ?? result.memoryResult?.summary ?? "")
                .prefix(200)
            return "[\(index)] \(filePath)\n\(snippet)"
        }.joined(separator: "\n\n")
        userPrompt = userPrompt.replacingOccurrences(of: "{{results}}", with: resultsText)

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": template.maxTokens,
            "temperature": template.temperature,
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "system": template.systemPrompt
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return results
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                return results
            }

            // Parse rankings from AI response
            if let jsonStart = text.firstIndex(of: "{"),
               let jsonEnd = text.lastIndex(of: "}") {
                let jsonStr = String(text[jsonStart...jsonEnd])
                if let jsonData = jsonStr.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let rankings = parsed["rankings"] as? [[String: Any]] {

                    var reranked = toRerank
                    for ranking in rankings {
                        if let index = ranking["index"] as? Int,
                           let relevance = ranking["relevance"] as? Double,
                           index < reranked.count {
                            reranked[index].semanticRelevance = Float(relevance)
                            if let reason = ranking["reason"] as? String {
                                reranked[index].explanationNote = reason
                            }
                            // Recalculate combined score with AI relevance
                            let w = scoringWeights
                            reranked[index].combinedScore = w.combine(
                                keyword: reranked[index].keywordScore,
                                semantic: Float(relevance),
                                entity: reranked[index].entityMatchScore,
                                recency: reranked[index].recencyScore,
                                relationship: reranked[index].relationshipScore
                            )
                        }
                    }

                    reranked.sort { $0.combinedScore > $1.combinedScore }
                    return reranked + remaining
                }
            }
            return results
        } catch {
            return results
        }
    }
}
