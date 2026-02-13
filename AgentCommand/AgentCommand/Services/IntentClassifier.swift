import Foundation

// MARK: - H5: Intent Classifier (Rule-based + AI Hybrid)

/// Classifies user queries into intents using a two-tier approach:
/// 1. **Rule-based decision tree** (fast, offline, deterministic)
/// 2. **AI model fallback** (when rule confidence < threshold)
///
/// ## Decision Tree (Intent Classification Flow):
/// ```
///                        ┌──────────────────────┐
///                        │   User Query Input    │
///                        └──────────┬───────────┘
///                                   ▼
///                        ┌──────────────────────┐
///                        │  Contains error/crash │
///                        │  keywords?            │
///                        └────┬────────────┬─────┘
///                          YES│            │NO
///                             ▼            ▼
///                   ┌─────────────┐  ┌──────────────────┐
///                   │errorDiagnosis│  │ Starts with      │
///                   └─────────────┘  │ action verb?      │
///                                    └───┬──────────┬────┘
///                                     YES│          │NO
///                                        ▼          ▼
///                             ┌──────────────┐ ┌──────────────────┐
///                             │ Which verb?   │ │ Is a question?   │
///                             └──┬───┬───┬───┘ └───┬──────────┬───┘
///                           fix  add refactor   YES│          │NO
///                            │    │    │           ▼          ▼
///                            ▼    ▼    ▼    ┌──────────┐ ┌──────────┐
///                      codeFix code code    │ Has file  │ │ Has file │
///                            Generate Refac │ reference?│ │ ref?     │
///                                    tor    └──┬────┬──┘ └──┬────┬──┘
///                                           YES│    │NO  YES│    │NO
///                                              ▼    ▼       ▼    ▼
///                                        codeExplain concept fileNav codeSearch
///                                                    Explain        (fallback)
/// ```
@MainActor
class IntentClassifier: ObservableObject {

    @Published var lastClassification: QueryClassification?

    /// Confidence threshold below which AI fallback is triggered
    var aiThreshold: Float = 0.6

    // MARK: - Main Classification

    /// Classify a preprocessed query into an intent
    func classify(_ preprocessed: PreprocessedQuery) -> QueryClassification {
        // Tier 1: Rule-based classification
        let ruleResult = classifyWithRules(preprocessed)

        // If high confidence, return directly
        if ruleResult.confidence >= aiThreshold {
            lastClassification = ruleResult
            return ruleResult
        }

        // Tier 2: Enhanced heuristic analysis for low-confidence cases
        let enhanced = enhanceClassification(ruleResult, preprocessed: preprocessed)
        lastClassification = enhanced
        return enhanced
    }

    /// Build the AI prompt for external classification (to be sent to Claude API)
    func buildAIClassificationPrompt(query: String, projectContext: String, recentFiles: [String]) -> String {
        var prompt = SemanticPromptTemplate.intentClassificationTemplate.userPromptTemplate
        prompt = prompt.replacingOccurrences(of: "{{query}}", with: query)
        prompt = prompt.replacingOccurrences(of: "{{projectContext}}", with: projectContext)
        prompt = prompt.replacingOccurrences(of: "{{recentFiles}}", with: recentFiles.prefix(10).joined(separator: ", "))
        return prompt
    }

    /// Parse the AI model's JSON response into a QueryClassification
    func parseAIResponse(_ jsonString: String, originalQuery: PreprocessedQuery) -> QueryClassification? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let primary = json["primary"] as? [String: Any],
              let intentStr = primary["intent"] as? String,
              let confidence = primary["confidence"] as? Double,
              let intent = QueryIntent(rawValue: intentStr)
        else { return nil }

        var secondaryIntents: [IntentScore] = []
        if let secondary = json["secondary"] as? [[String: Any]] {
            for item in secondary {
                if let iStr = item["intent"] as? String,
                   let score = item["score"] as? Double,
                   let si = QueryIntent(rawValue: iStr) {
                    secondaryIntents.append(IntentScore(intent: si, score: Float(score)))
                }
            }
        }

        return QueryClassification(
            primaryIntent: intent,
            confidence: Float(confidence),
            secondaryIntents: secondaryIntents,
            extractedEntities: originalQuery.entities,
            queryComplexity: assessComplexity(originalQuery)
        )
    }

    // MARK: - Tier 1: Rule-Based Decision Tree

    private func classifyWithRules(_ preprocessed: PreprocessedQuery) -> QueryClassification {
        let query = preprocessed.normalizedQuery
        let lower = query.lowercased()
        let tokens = preprocessed.tokens
        let entities = preprocessed.entities

        var candidates: [(QueryIntent, Float)] = []

        // ─── Branch 1: Error / Crash / Diagnosis ───
        let errorKeywords = ["error", "crash", "fail", "exception", "bug", "broken", "wrong",
                            "not working", "doesn't work", "can't", "cannot",
                            "錯誤", "崩潰", "失敗", "異常", "壞了", "不能", "無法"]
        let errorScore = scoreKeywordMatch(lower, keywords: errorKeywords)
        if errorScore > 0 {
            candidates.append((.errorDiagnosis, 0.5 + errorScore * 0.4))
        }

        // ─── Branch 2: Action Verb at Start ───
        let firstToken = tokens.first?.lowercased() ?? ""

        // Fix / Debug
        let fixVerbs = ["fix", "debug", "repair", "resolve", "patch", "修復", "修正", "解決"]
        if fixVerbs.contains(firstToken) {
            candidates.append((.codeFix, 0.85))
        }

        // Add / Create / Implement
        let addVerbs = ["add", "create", "implement", "build", "write", "generate", "make",
                       "新增", "建立", "實作", "產生", "撰寫"]
        if addVerbs.contains(firstToken) {
            // Distinguish: codeGenerate vs taskCreate
            let hasTaskContext = lower.contains("task") || lower.contains("todo") || lower.contains("任務")
            candidates.append((hasTaskContext ? .taskCreate : .codeGenerate, 0.80))
        }

        // Refactor / Restructure
        let refactorVerbs = ["refactor", "restructure", "reorganize", "clean", "simplify",
                            "重構", "重組", "簡化"]
        if refactorVerbs.contains(firstToken) {
            candidates.append((.codeRefactor, 0.85))
        }

        // Find / Search / Locate
        let searchVerbs = ["find", "search", "locate", "look", "where", "show",
                          "找", "搜尋", "查找", "尋找", "哪裡", "顯示"]
        if searchVerbs.contains(firstToken) {
            candidates.append((.codeSearch, 0.80))
        }

        // Remove / Delete
        let removeVerbs = ["remove", "delete", "drop", "eliminate", "移除", "刪除", "去除"]
        if removeVerbs.contains(firstToken) {
            candidates.append((.codeRefactor, 0.70))
        }

        // Update / Change / Modify
        let updateVerbs = ["update", "change", "modify", "alter", "更新", "修改", "變更"]
        if updateVerbs.contains(firstToken) {
            candidates.append((.codeRefactor, 0.70))
        }

        // Test
        let testVerbs = ["test", "verify", "check", "validate", "測試", "驗證", "檢查"]
        if testVerbs.contains(firstToken) {
            candidates.append((.codeGenerate, 0.65))
        }

        // Open / Go to / Navigate
        let navVerbs = ["open", "goto", "navigate", "jump", "go", "開啟", "前往", "跳到"]
        if navVerbs.contains(firstToken) {
            candidates.append((.fileNavigation, 0.85))
        }

        // ─── Branch 3: Question Detection ───
        let isQuestion = query.hasSuffix("?") || query.hasSuffix("？")
        let questionWords = ["how", "what", "why", "when", "who", "which", "explain",
                            "如何", "什麼", "為什麼", "何時", "哪個", "解釋", "說明"]
        let startsWithQuestion = questionWords.contains(firstToken)

        if isQuestion || startsWithQuestion {
            // Is it about code or concept?
            let hasCodeRef = entities.contains { [.fileName, .className, .functionName, .filePath].contains($0.type) }
            if hasCodeRef {
                candidates.append((.codeExplain, 0.80))
            } else {
                candidates.append((.conceptExplain, 0.70))
            }

            // "what depends on" / "what imports"
            let depKeywords = ["depend", "import", "require", "use", "reference",
                              "依賴", "引入", "引用", "使用"]
            if depKeywords.contains(where: { lower.contains($0) }) {
                candidates.append((.dependencyQuery, 0.80))
            }

            // Architecture questions
            let archKeywords = ["architecture", "structure", "flow", "design", "layer",
                               "架構", "結構", "流程", "設計"]
            if archKeywords.contains(where: { lower.contains($0) }) {
                candidates.append((.architectureQuery, 0.75))
            }
        }

        // ─── Branch 4: File Reference Detection ───
        let hasFileEntity = entities.contains { $0.type == .fileName || $0.type == .filePath }
        if hasFileEntity && candidates.isEmpty {
            candidates.append((.fileNavigation, 0.60))
        }

        // ─── Branch 5: Task-Related Keywords ───
        let taskKeywords = ["task", "status", "progress", "breakdown", "decompose",
                           "任務", "狀態", "進度", "分解", "拆解"]
        let taskScore = scoreKeywordMatch(lower, keywords: taskKeywords)
        if taskScore > 0.3 {
            if lower.contains("status") || lower.contains("progress") || lower.contains("狀態") || lower.contains("進度") {
                candidates.append((.taskStatus, 0.5 + taskScore * 0.3))
            } else if lower.contains("break") || lower.contains("decompose") || lower.contains("分解") || lower.contains("拆解") {
                candidates.append((.taskDecompose, 0.5 + taskScore * 0.3))
            } else {
                candidates.append((.taskCreate, 0.5 + taskScore * 0.3))
            }
        }

        // ─── Branch 6: System Commands ───
        let sysKeywords = ["clear", "rebuild", "reset", "reindex", "restart",
                          "清除", "重建", "重置", "重新索引"]
        if sysKeywords.contains(where: { lower.contains($0) }) {
            candidates.append((.systemCommand, 0.85))
        }

        // ─── Branch 7: Config Changes ───
        let configKeywords = ["enable", "disable", "toggle", "set", "configure", "config",
                             "啟用", "停用", "切換", "設定", "配置"]
        if configKeywords.contains(where: { lower.contains($0) }) {
            candidates.append((.configChange, 0.80))
        }

        // ─── Branch 8: Pattern Match ───
        let patternKeywords = ["similar", "like this", "pattern", "example",
                              "類似", "像這樣", "模式", "範例"]
        if patternKeywords.contains(where: { lower.contains($0) }) {
            candidates.append((.patternMatch, 0.70))
        }

        // ─── Resolve: pick best candidate ───
        candidates.sort { $0.1 > $1.1 }

        let primary = candidates.first ?? (.unknown, 0.3)
        let secondary = candidates.dropFirst().prefix(2).map { IntentScore(intent: $0.0, score: $0.1) }

        return QueryClassification(
            primaryIntent: primary.0,
            confidence: primary.1,
            secondaryIntents: Array(secondary),
            extractedEntities: entities,
            queryComplexity: assessComplexity(preprocessed)
        )
    }

    // MARK: - Tier 2: Enhanced Heuristic (Confidence Booster)

    private func enhanceClassification(_ initial: QueryClassification, preprocessed: PreprocessedQuery) -> QueryClassification {
        var result = initial

        // Boost confidence if entities strongly correlate with intent
        let entityTypes = Set(preprocessed.entities.map(\.type))

        switch result.primaryIntent {
        case .codeSearch, .codeExplain, .codeFix:
            if entityTypes.contains(.className) || entityTypes.contains(.functionName) {
                result = QueryClassification(
                    primaryIntent: result.primaryIntent,
                    confidence: min(result.confidence + 0.15, 1.0),
                    secondaryIntents: result.secondaryIntents,
                    extractedEntities: result.extractedEntities,
                    queryComplexity: result.queryComplexity
                )
            }
        case .fileNavigation:
            if entityTypes.contains(.fileName) || entityTypes.contains(.filePath) {
                result = QueryClassification(
                    primaryIntent: result.primaryIntent,
                    confidence: min(result.confidence + 0.20, 1.0),
                    secondaryIntents: result.secondaryIntents,
                    extractedEntities: result.extractedEntities,
                    queryComplexity: result.queryComplexity
                )
            }
        case .errorDiagnosis:
            if entityTypes.contains(.errorMessage) {
                result = QueryClassification(
                    primaryIntent: result.primaryIntent,
                    confidence: min(result.confidence + 0.20, 1.0),
                    secondaryIntents: result.secondaryIntents,
                    extractedEntities: result.extractedEntities,
                    queryComplexity: result.queryComplexity
                )
            }
        default:
            break
        }

        return result
    }

    // MARK: - Complexity Assessment

    private func assessComplexity(_ preprocessed: PreprocessedQuery) -> QueryComplexity {
        let tokenCount = preprocessed.tokens.count
        let entityCount = preprocessed.entities.count
        let hasMultipleSentences = preprocessed.originalQuery.components(separatedBy: CharacterSet(charactersIn: ".!?\n。！？"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count > 1

        if tokenCount <= 2 { return .trivial }
        if tokenCount <= 6 && entityCount <= 1 { return .simple }
        if tokenCount <= 15 || entityCount <= 2 { return .moderate }
        if hasMultipleSentences || entityCount >= 3 { return .compound }
        return .complex
    }

    // MARK: - Async Classification with AI Fallback

    /// Classify with AI fallback when rule-based confidence is below threshold
    func classifyAsync(_ preprocessed: PreprocessedQuery, projectContext: String = "", recentFiles: [String] = []) async -> QueryClassification {
        // Tier 1: Rule-based (same as sync)
        let ruleResult = classifyWithRules(preprocessed)

        if ruleResult.confidence >= aiThreshold {
            lastClassification = ruleResult
            return ruleResult
        }

        // Tier 2: Try AI classification via Anthropic API
        let aiResult = await callAIClassification(
            query: preprocessed.originalQuery,
            preprocessed: preprocessed,
            projectContext: projectContext,
            recentFiles: recentFiles
        )

        if let aiResult = aiResult, aiResult.confidence > ruleResult.confidence {
            lastClassification = aiResult
            return aiResult
        }

        // Fallback: enhanced heuristic
        let enhanced = enhanceClassification(ruleResult, preprocessed: preprocessed)
        lastClassification = enhanced
        return enhanced
    }

    /// Call the Anthropic Messages API for intent classification
    private func callAIClassification(query: String, preprocessed: PreprocessedQuery, projectContext: String, recentFiles: [String]) async -> QueryClassification? {
        guard let apiKey = Self.resolveAnthropicAPIKey(), !apiKey.isEmpty else {
            return nil
        }

        let template = SemanticPromptTemplate.intentClassificationTemplate
        let userPrompt = buildAIClassificationPrompt(query: query, projectContext: projectContext, recentFiles: recentFiles)

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
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse Anthropic response format
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                return nil
            }

            // Extract JSON from response text (may have surrounding text)
            let jsonString = extractJSON(from: text)
            return parseAIResponse(jsonString, originalQuery: preprocessed)
        } catch {
            return nil
        }
    }

    /// Resolve the Anthropic API key from environment or UserDefaults
    static func resolveAnthropicAPIKey() -> String? {
        // Priority 1: Environment variable
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        // Priority 2: UserDefaults
        if let storedKey = UserDefaults.standard.string(forKey: "anthropic_api_key"), !storedKey.isEmpty {
            return storedKey
        }
        return nil
    }

    /// Extract JSON object from potentially mixed text response
    private func extractJSON(from text: String) -> String {
        // Try to find JSON between { and }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[start...end])
    }

    // MARK: - Helpers

    private func scoreKeywordMatch(_ text: String, keywords: [String]) -> Float {
        let matchCount = keywords.reduce(0) { count, keyword in
            count + (text.contains(keyword) ? 1 : 0)
        }
        return min(Float(matchCount) / 3.0, 1.0) // normalize: 3+ matches = 1.0
    }
}
