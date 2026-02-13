import Foundation
import Combine

/// Manages prompt quality analysis, history tracking, pattern detection, A/B testing, and version management
@MainActor
class PromptOptimizationManager: ObservableObject {
    // MARK: - Published State

    @Published var lastScore: PromptQualityScore?
    @Published var suggestions: [PromptSuggestion] = []
    @Published var autocompleteSuggestions: [PromptAutocompleteSuggestion] = []
    @Published var history: [PromptHistoryRecord] = []
    @Published var patterns: [PromptPattern] = []
    @Published var abTests: [PromptABTest] = []
    @Published var versions: [PromptVersion] = []
    @Published var isAnalyzing: Bool = false
    @Published var lastReport: PromptAnalysisReport?
    @Published var detectedAntiPatterns: [PromptAntiPattern] = []
    @Published var lastRewrite: PromptRewriteSuggestion?

    // History filtering, sorting & statistics
    @Published var historyFilterTag: String? = nil
    @Published var historyFilterSuccess: Bool? = nil
    @Published var historySortOption: PromptHistorySortOption = .dateDesc
    @Published var historyGrouping: PromptHistoryTimeGrouping = .daily
    @Published var filteredHistory: [PromptHistoryRecord] = []
    @Published var groupedStats: [PromptHistoryStats] = []
    @Published var categoryStats: [PromptCategoryStats] = []

    private static let historyKey = "promptOptimizationHistory"
    private static let patternsKey = "promptOptimizationPatterns"
    private static let abTestsKey = "promptOptimizationABTests"
    private static let versionsKey = "promptOptimizationVersions"

    // MARK: - Analysis Cache (LRU)

    /// Maximum entries in the analysis score cache
    private static let maxCacheSize = 50
    /// LRU cache: prompt hash → (score, timestamp)
    private var scoreCache: [Int: (score: PromptQualityScore, cachedAt: Date)] = [:]
    /// Ordered keys for LRU eviction (most recent at end)
    private var scoreCacheOrder: [Int] = []
    /// Cache expiry duration (5 minutes)
    private static let cacheExpirySeconds: TimeInterval = 300

    /// Whether initial history has been loaded from disk
    private var isHistoryLoaded = false

    // MARK: - Memory Limits

    /// Maximum number of history records to retain
    static let maxHistoryRecords = 200
    /// Maximum number of A/B tests to retain
    static let maxABTests = 50
    /// Maximum number of versions to retain globally
    static let maxVersions = 500

    init() {
        load()
    }

    // MARK: - Prompt Quality Analysis

    /// Analyze a prompt and return a quality score with suggestions
    func analyzePrompt(_ prompt: String) -> PromptQualityScore {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let clarity = analyzeClarity(prompt)
        let specificity = analyzeSpecificity(prompt)
        let context = analyzeContext(prompt)
        let actionability = analyzeActionability(prompt)
        let tokenEfficiency = analyzeTokenEfficiency(prompt)
        let estimatedTokens = estimateTokenCount(prompt)
        let estimatedCost = estimateCost(tokenCount: estimatedTokens)

        let overall = (clarity * 0.25 + specificity * 0.25 + context * 0.2 + actionability * 0.2 + tokenEfficiency * 0.1)

        let score = PromptQualityScore(
            id: UUID().uuidString,
            overallScore: overall,
            clarity: clarity,
            specificity: specificity,
            context: context,
            actionability: actionability,
            tokenEfficiency: tokenEfficiency,
            estimatedTokens: estimatedTokens,
            estimatedCostUSD: estimatedCost,
            analyzedAt: Date()
        )

        lastScore = score
        suggestions = generateSuggestions(for: prompt, score: score)
        detectedAntiPatterns = detectAntiPatterns(in: prompt)
        lastRewrite = generateRewrite(for: prompt, score: score, antiPatterns: detectedAntiPatterns)

        lastReport = PromptAnalysisReport(
            id: UUID().uuidString,
            prompt: prompt,
            score: score,
            suggestions: suggestions,
            antiPatterns: detectedAntiPatterns,
            rewriteSuggestion: lastRewrite,
            analyzedAt: Date()
        )

        return score
    }

    // MARK: - Quick Analysis (Cached, Lightweight)

    /// Lightweight analysis that checks the cache first, used for live UI feedback.
    /// Does NOT update published state (suggestions, antiPatterns, etc.) — only returns a score.
    func quickAnalyze(_ prompt: String) -> PromptQualityScore {
        let key = prompt.hashValue

        // Check cache
        if let cached = scoreCache[key],
           Date().timeIntervalSince(cached.cachedAt) < Self.cacheExpirySeconds {
            // Move to end (most recently used)
            scoreCacheOrder.removeAll { $0 == key }
            scoreCacheOrder.append(key)
            return cached.score
        }

        // Compute score (analysis only, no side effects)
        let clarity = analyzeClarity(prompt)
        let specificity = analyzeSpecificity(prompt)
        let context = analyzeContext(prompt)
        let actionability = analyzeActionability(prompt)
        let tokenEfficiency = analyzeTokenEfficiency(prompt)
        let estimatedTokens = estimateTokenCount(prompt)
        let estimatedCost = estimateCost(tokenCount: estimatedTokens)

        let overall = (clarity * 0.25 + specificity * 0.25 + context * 0.2 + actionability * 0.2 + tokenEfficiency * 0.1)

        let score = PromptQualityScore(
            id: UUID().uuidString,
            overallScore: overall,
            clarity: clarity,
            specificity: specificity,
            context: context,
            actionability: actionability,
            tokenEfficiency: tokenEfficiency,
            estimatedTokens: estimatedTokens,
            estimatedCostUSD: estimatedCost,
            analyzedAt: Date()
        )

        // Insert into cache with LRU eviction
        insertIntoCache(key: key, score: score)
        return score
    }

    /// Insert a score into the LRU cache, evicting oldest if full
    private func insertIntoCache(key: Int, score: PromptQualityScore) {
        // Remove existing entry if present
        if scoreCache[key] != nil {
            scoreCacheOrder.removeAll { $0 == key }
        }

        // Evict oldest if at capacity
        while scoreCacheOrder.count >= Self.maxCacheSize {
            let oldest = scoreCacheOrder.removeFirst()
            scoreCache.removeValue(forKey: oldest)
        }

        scoreCache[key] = (score: score, cachedAt: Date())
        scoreCacheOrder.append(key)
    }

    /// Clear all cached analysis scores
    func clearAnalysisCache() {
        scoreCache.removeAll()
        scoreCacheOrder.removeAll()
    }

    // MARK: - Autocomplete

    /// Generate autocomplete suggestions based on project context and history
    func generateAutocompleteSuggestions(prefix: String, projectFiles: [String] = []) -> [PromptAutocompleteSuggestion] {
        var results: [PromptAutocompleteSuggestion] = []
        let lowPrefix = prefix.lowercased()

        // History-based suggestions
        let historyMatches = history
            .filter { $0.wasSuccessful == true && $0.prompt.lowercased().hasPrefix(lowPrefix) }
            .prefix(3)
            .enumerated()
            .map { idx, record in
                PromptAutocompleteSuggestion(
                    id: "history-\(idx)",
                    text: record.prompt,
                    category: "History",
                    relevanceScore: 0.8,
                    source: .history
                )
            }
        results.append(contentsOf: historyMatches)

        // Context-based suggestions from common patterns
        let contextSuggestions = generateContextSuggestions(prefix: lowPrefix, files: projectFiles)
        results.append(contentsOf: contextSuggestions)

        autocompleteSuggestions = results
        return results
    }

    // MARK: - History Management

    /// Record a prompt submission for tracking (auto-analyzes quality if no score provided)
    @discardableResult
    func recordPrompt(_ prompt: String, score: PromptQualityScore? = nil) -> PromptHistoryRecord {
        let finalScore = score ?? analyzePrompt(prompt)
        let record = PromptHistoryRecord(
            id: UUID().uuidString,
            prompt: prompt,
            qualityScore: finalScore,
            sentAt: Date(),
            completedAt: nil,
            wasSuccessful: nil,
            taskDuration: nil,
            tokenCount: finalScore.estimatedTokens,
            costUSD: finalScore.estimatedCostUSD,
            tags: extractTags(from: prompt),
            patternId: matchPattern(prompt)
        )
        history.insert(record, at: 0)

        // Keep history limited
        if history.count > 200 {
            history = Array(history.prefix(200))
        }

        applyFilterAndSort()
        save()
        return record
    }

    /// Update a history record with completion data
    func recordCompletion(recordId: String, success: Bool, duration: TimeInterval?, tokenCount: Int?, costUSD: Double?) {
        guard let idx = history.firstIndex(where: { $0.id == recordId }) else { return }
        history[idx].completedAt = Date()
        history[idx].wasSuccessful = success
        history[idx].taskDuration = duration
        if let tokens = tokenCount { history[idx].tokenCount = tokens }
        if let cost = costUSD { history[idx].costUSD = cost }

        // Update pattern stats
        if let patternId = history[idx].patternId {
            updatePatternStats(patternId: patternId)
        }

        save()
    }

    // MARK: - Pattern Detection

    /// Detect patterns from prompt history
    func detectPatterns() {
        let completed = history.filter { $0.isCompleted }
        guard completed.count >= 5 else { return }

        var detected: [PromptPattern] = []

        // Detect by tags
        var tagGroups: [String: [PromptHistoryRecord]] = [:]
        for record in completed {
            for tag in record.tags {
                tagGroups[tag, default: []].append(record)
            }
        }

        for (tag, records) in tagGroups where records.count >= 3 {
            let successCount = records.filter { $0.wasSuccessful == true }.count
            let avgDuration = records.compactMap(\.taskDuration).reduce(0, +) / max(Double(records.count), 1)
            let avgTokens = records.compactMap(\.tokenCount).reduce(0, +) / max(records.count, 1)

            let pattern = PromptPattern(
                id: "pattern-\(tag)",
                name: tag.capitalized,
                description: "Tasks related to \(tag)",
                matchCount: records.count,
                avgSuccessRate: Double(successCount) / Double(records.count),
                avgDuration: avgDuration,
                avgTokens: avgTokens,
                examplePrompts: Array(records.prefix(3).map(\.prompt)),
                detectedAt: Date()
            )
            detected.append(pattern)
        }

        patterns = detected.sorted { $0.matchCount > $1.matchCount }
        save()
    }

    // MARK: - A/B Testing

    /// Create a new A/B test
    func createABTest(task: String, promptA: String, promptB: String) -> PromptABTest {
        let test = PromptABTest(
            id: UUID().uuidString,
            taskDescription: task,
            variantA: PromptVariant(id: UUID().uuidString, label: "A", prompt: promptA),
            variantB: PromptVariant(id: UUID().uuidString, label: "B", prompt: promptB),
            status: .pending,
            createdAt: Date()
        )
        abTests.insert(test, at: 0)
        save()
        return test
    }

    /// Update a variant result in an A/B test
    func updateABTestVariant(testId: String, variant: String, success: Bool, duration: TimeInterval?, tokenCount: Int?, costUSD: Double?) {
        guard let idx = abTests.firstIndex(where: { $0.id == testId }) else { return }

        if variant == "A" {
            abTests[idx].variantA.wasSuccessful = success
            abTests[idx].variantA.duration = duration
            abTests[idx].variantA.tokenCount = tokenCount
            abTests[idx].variantA.costUSD = costUSD
        } else {
            abTests[idx].variantB.wasSuccessful = success
            abTests[idx].variantB.duration = duration
            abTests[idx].variantB.tokenCount = tokenCount
            abTests[idx].variantB.costUSD = costUSD
        }

        // Check if both variants are complete
        if abTests[idx].variantA.wasSuccessful != nil && abTests[idx].variantB.wasSuccessful != nil {
            abTests[idx].status = .completed
            abTests[idx].completedAt = Date()

            // Determine winner
            let scoreA = calculateVariantScore(abTests[idx].variantA)
            let scoreB = calculateVariantScore(abTests[idx].variantB)
            abTests[idx].winnerVariant = scoreA >= scoreB ? "A" : "B"
        } else {
            abTests[idx].status = .running
        }

        save()
    }

    // MARK: - Version Management

    /// Save a prompt version
    func saveVersion(promptId: String, content: String, note: String? = nil) {
        let existingVersions = versions.filter { $0.promptId == promptId }
        let nextVersion = (existingVersions.map(\.version).max() ?? 0) + 1

        let version = PromptVersion(
            id: UUID().uuidString,
            promptId: promptId,
            version: nextVersion,
            content: content,
            note: note,
            createdAt: Date()
        )
        versions.insert(version, at: 0)

        // Limit versions per prompt
        let allForPrompt = versions.filter { $0.promptId == promptId }
        if allForPrompt.count > 20 {
            let toRemove = allForPrompt.suffix(from: 20).map(\.id)
            versions.removeAll { toRemove.contains($0.id) }
        }

        save()
    }

    /// Get version history for a specific prompt
    func versionsForPrompt(_ promptId: String) -> [PromptVersion] {
        versions.filter { $0.promptId == promptId }.sorted { $0.version > $1.version }
    }

    // MARK: - Statistics

    var totalPromptsAnalyzed: Int { history.count }
    var avgQualityScore: Double {
        let scores = history.compactMap { $0.qualityScore?.overallScore }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }
    var bestPatternName: String? {
        patterns.max(by: { $0.avgSuccessRate < $1.avgSuccessRate })?.name
    }
    var activeABTests: Int {
        abTests.filter { $0.status == .running || $0.status == .pending }.count
    }

    // MARK: - Private Analysis Methods

    private func analyzeClarity(_ prompt: String) -> Double {
        var score = 0.5

        // Longer prompts tend to be clearer
        let wordCount = prompt.split(separator: " ").count
        if wordCount >= 5 { score += 0.1 }
        if wordCount >= 10 { score += 0.1 }
        if wordCount >= 20 { score += 0.1 }

        // Check for clear sentence structure
        if prompt.contains(".") || prompt.contains("。") { score += 0.05 }
        if prompt.hasSuffix(".") || prompt.hasSuffix("。") { score += 0.05 }

        // Penalize all caps
        let uppercaseRatio = Double(prompt.filter(\.isUppercase).count) / max(Double(prompt.count), 1)
        if uppercaseRatio > 0.5 { score -= 0.15 }

        return min(max(score, 0), 1)
    }

    private func analyzeSpecificity(_ prompt: String) -> Double {
        var score = 0.3
        let lower = prompt.lowercased()

        // Check for specific technical terms
        let technicalTerms = ["function", "class", "method", "api", "endpoint", "database", "test", "component",
                              "file", "module", "bug", "error", "feature", "refactor", "deploy", "config",
                              "函數", "類別", "方法", "測試", "元件", "檔案", "模組", "錯誤", "功能", "重構"]
        for term in technicalTerms where lower.contains(term) {
            score += 0.05
        }

        // Check for file paths or code references
        if lower.contains(".swift") || lower.contains(".ts") || lower.contains(".py") || lower.contains(".js") {
            score += 0.1
        }

        // Check for specific actions
        let actionWords = ["add", "remove", "fix", "update", "create", "delete", "implement", "change", "modify",
                          "新增", "移除", "修復", "更新", "建立", "刪除", "實作", "變更", "修改"]
        for word in actionWords where lower.contains(word) {
            score += 0.05
            break
        }

        // Check for constraints or requirements
        let constraintWords = ["must", "should", "need", "require", "without", "ensure", "make sure",
                              "必須", "應該", "需要", "確保"]
        for word in constraintWords where lower.contains(word) {
            score += 0.1
            break
        }

        return min(max(score, 0), 1)
    }

    private func analyzeContext(_ prompt: String) -> Double {
        var score = 0.3
        let lower = prompt.lowercased()

        // Check for background info
        if lower.contains("currently") || lower.contains("existing") || lower.contains("目前") || lower.contains("現有") {
            score += 0.15
        }

        // Check for reasons or goals
        if lower.contains("because") || lower.contains("so that") || lower.contains("in order to") ||
           lower.contains("因為") || lower.contains("為了") {
            score += 0.15
        }

        // Check for technology context
        let frameworks = ["swiftui", "react", "vue", "angular", "django", "flask", "express", "scenekit"]
        for fw in frameworks where lower.contains(fw) {
            score += 0.1
            break
        }

        // Word count context bonus
        let wordCount = prompt.split(separator: " ").count
        if wordCount >= 15 { score += 0.1 }
        if wordCount >= 30 { score += 0.1 }

        return min(max(score, 0), 1)
    }

    private func analyzeActionability(_ prompt: String) -> Double {
        var score = 0.3
        let lower = prompt.lowercased()

        // Check for clear action verbs at the start
        let actionStarters = ["add", "fix", "create", "implement", "update", "remove", "build", "write",
                             "refactor", "optimize", "debug", "test", "deploy", "configure", "setup",
                             "新增", "修復", "建立", "實作", "更新", "移除", "撰寫", "重構", "優化", "測試"]
        let firstWord = String(lower.prefix(while: { !$0.isWhitespace }))
        if actionStarters.contains(firstWord) {
            score += 0.2
        }

        // Check for expected output description
        if lower.contains("should") || lower.contains("expect") || lower.contains("output") ||
           lower.contains("result") || lower.contains("應該") || lower.contains("預期") || lower.contains("結果") {
            score += 0.15
        }

        // Check for step-by-step format
        if lower.contains("1.") || lower.contains("step") || lower.contains("first") || lower.contains("then") ||
           lower.contains("步驟") || lower.contains("首先") || lower.contains("然後") {
            score += 0.15
        }

        // Check for acceptance criteria
        if lower.contains("done when") || lower.contains("complete when") || lower.contains("verify") ||
           lower.contains("完成條件") || lower.contains("驗證") {
            score += 0.1
        }

        return min(max(score, 0), 1)
    }

    private func analyzeTokenEfficiency(_ prompt: String) -> Double {
        let tokens = estimateTokenCount(prompt)

        // Very short prompts are inefficient (too vague)
        if tokens < 5 { return 0.3 }
        // Sweet spot is 20-100 tokens
        if tokens >= 20 && tokens <= 100 { return 0.9 }
        // Slightly too long
        if tokens > 100 && tokens <= 200 { return 0.7 }
        // Too long, may have redundancy
        if tokens > 200 { return 0.5 }
        // Short but potentially ok
        return 0.6
    }

    private func estimateTokenCount(_ prompt: String) -> Int {
        // Rough estimate: ~4 chars per token for English, ~2 chars per token for CJK
        let cjkCount = prompt.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        let nonCjkCount = prompt.count - cjkCount
        return (nonCjkCount / 4) + (cjkCount * 2) + 1
    }

    private func estimateCost(tokenCount: Int) -> Double {
        // Rough cost estimate based on Claude Sonnet pricing
        // Input: ~$3/MTok, Output estimate: ~2x input tokens at ~$15/MTok
        let inputCost = Double(tokenCount) * 3.0 / 1_000_000
        let estimatedOutputTokens = tokenCount * 2
        let outputCost = Double(estimatedOutputTokens) * 15.0 / 1_000_000
        return inputCost + outputCost
    }

    // MARK: - Suggestion Generation

    private func generateSuggestions(for prompt: String, score: PromptQualityScore) -> [PromptSuggestion] {
        var results: [PromptSuggestion] = []

        if score.clarity < 0.6 {
            results.append(PromptSuggestion(
                id: UUID().uuidString,
                type: .improveStructure,
                title: "Improve Clarity",
                description: "Break the prompt into clear sentences and use punctuation.",
                originalSnippet: String(prompt.prefix(50)),
                suggestedSnippet: "Add periods to separate ideas. Use clear subject-verb structure.",
                impact: .high
            ))
        }

        if score.specificity < 0.6 {
            results.append(PromptSuggestion(
                id: UUID().uuidString,
                type: .beMoreSpecific,
                title: "Add Specific Details",
                description: "Include file names, function names, or specific requirements.",
                originalSnippet: String(prompt.prefix(50)),
                suggestedSnippet: "Mention specific files, classes, or functions to modify.",
                impact: .high
            ))
        }

        if score.context < 0.5 {
            results.append(PromptSuggestion(
                id: UUID().uuidString,
                type: .addContext,
                title: "Add Background Context",
                description: "Explain what currently exists and why the change is needed.",
                originalSnippet: String(prompt.prefix(50)),
                suggestedSnippet: "Add 'Currently, ... I want to change it because ...'",
                impact: .medium
            ))
        }

        if score.actionability < 0.5 {
            results.append(PromptSuggestion(
                id: UUID().uuidString,
                type: .addConstraints,
                title: "Define Expected Outcome",
                description: "Describe what 'done' looks like and any constraints.",
                originalSnippet: String(prompt.prefix(50)),
                suggestedSnippet: "Add 'The result should ...' or 'Make sure to ...'",
                impact: .medium
            ))
        }

        if score.tokenEfficiency < 0.6 && prompt.count > 500 {
            results.append(PromptSuggestion(
                id: UUID().uuidString,
                type: .simplify,
                title: "Reduce Redundancy",
                description: "The prompt may contain repetitive or unnecessary content.",
                originalSnippet: String(prompt.prefix(50)),
                suggestedSnippet: "Remove repeated phrases and keep only essential instructions.",
                impact: .low
            ))
        }

        let lower = prompt.lowercased()
        let ambiguousWords = ["it", "this", "that", "thing", "stuff", "somehow", "some",
                             "這個", "那個", "東西", "某些"]
        let hasAmbiguity = ambiguousWords.contains { lower.contains($0) }
        if hasAmbiguity && score.specificity < 0.7 {
            results.append(PromptSuggestion(
                id: UUID().uuidString,
                type: .reduceAmbiguity,
                title: "Reduce Ambiguous References",
                description: "Replace vague words like 'it', 'this', 'that' with specific names.",
                originalSnippet: String(prompt.prefix(50)),
                suggestedSnippet: "Replace 'fix it' with 'fix the login validation in AuthService'.",
                impact: .medium
            ))
        }

        return results
    }

    // MARK: - Anti-Pattern Detection

    private func detectAntiPatterns(in prompt: String) -> [PromptAntiPattern] {
        var results: [PromptAntiPattern] = []
        let lower = prompt.lowercased()
        let words = prompt.split(separator: " ")

        // 1. Vagueness: detect vague pronouns without antecedent
        let vaguePatterns: [(String, String)] = [
            ("do it", "Replace 'it' with the specific object or action"),
            ("fix this", "Replace 'this' with the specific item to fix"),
            ("make it work", "Describe what 'working' means specifically"),
            ("make it better", "Define what 'better' means with measurable criteria"),
            ("do something", "Specify exactly what action to take"),
            ("handle that", "Specify what 'that' refers to"),
            ("do stuff", "Replace 'stuff' with specific tasks"),
        ]
        for (pattern, fix) in vaguePatterns where lower.contains(pattern) {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .vagueness,
                title: "Vague reference: \"\(pattern)\"",
                description: "Vague references force the AI to guess your intent, leading to unreliable results.",
                matchedText: pattern,
                severity: .critical,
                fixSuggestion: fix
            ))
        }

        // 2. Overloading: too many distinct tasks in one prompt
        let taskSeparators = ["and also", "and then", "plus ", "additionally", "moreover", "furthermore",
                              "另外", "而且", "還有", "同時", "此外"]
        let taskCount = taskSeparators.reduce(0) { count, sep in
            count + (lower.contains(sep) ? 1 : 0)
        }
        if taskCount >= 2 {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .overloading,
                title: "Task overloading detected",
                description: "Multiple unrelated tasks in one prompt reduce quality. Found \(taskCount + 1) task conjunctions.",
                matchedText: taskSeparators.filter { lower.contains($0) }.joined(separator: ", "),
                severity: .warning,
                fixSuggestion: "Break into separate focused prompts, one task per prompt."
            ))
        }

        // 3. Missing constraints: no success criteria or boundaries
        let hasConstraints = lower.contains("must") || lower.contains("should") || lower.contains("ensure") ||
            lower.contains("limit") || lower.contains("maximum") || lower.contains("minimum") ||
            lower.contains("必須") || lower.contains("確保") || lower.contains("限制")
        if words.count > 15 && !hasConstraints {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .missingConstraints,
                title: "No constraints or boundaries",
                description: "Without constraints, the AI may produce results that don't match your expectations.",
                matchedText: "",
                severity: .warning,
                fixSuggestion: "Add constraints like 'must use...', 'should not exceed...', 'ensure that...'."
            ))
        }

        // 4. Negative framing: telling what NOT to do instead of what TO do
        let negativeStarters = ["don't", "do not", "never", "avoid", "without", "stop",
                                "不要", "不可以", "禁止", "避免"]
        let negativeCount = negativeStarters.reduce(0) { count, neg in
            count + (lower.contains(neg) ? 1 : 0)
        }
        let positiveActions = ["add", "create", "implement", "build", "write", "fix", "update",
                               "新增", "建立", "實作", "撰寫", "修復", "更新"]
        let positiveCount = positiveActions.reduce(0) { count, pos in
            count + (lower.contains(pos) ? 1 : 0)
        }
        if negativeCount > positiveCount && negativeCount >= 2 {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .negativeFraming,
                title: "Predominantly negative framing",
                description: "Focusing on what NOT to do leaves the AI uncertain about what TO do.",
                matchedText: negativeStarters.filter { lower.contains($0) }.joined(separator: ", "),
                severity: .warning,
                fixSuggestion: "Reframe as positive instructions: instead of 'don't use X', say 'use Y instead'."
            ))
        }

        // 5. Implicit assumptions: references to unnamed context
        let implicitRefs = ["as usual", "like before", "the same way", "you know",
                           "as discussed", "like last time", "照舊", "跟之前一樣", "你知道的"]
        for ref in implicitRefs where lower.contains(ref) {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .implicitAssumption,
                title: "Implicit assumption: \"\(ref)\"",
                description: "The AI has no memory of previous conversations. Implicit references cause confusion.",
                matchedText: ref,
                severity: .critical,
                fixSuggestion: "Explicitly state the context or reference. Include all necessary background info."
            ))
        }

        // 6. Redundancy: repeated phrases
        let sentences = prompt.components(separatedBy: CharacterSet(charactersIn: ".!?\n。！？"))
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        var seen: Set<String> = []
        var duplicates: [String] = []
        for s in sentences {
            if seen.contains(s) { duplicates.append(s) }
            seen.insert(s)
        }
        if !duplicates.isEmpty {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .redundancy,
                title: "Repeated content detected",
                description: "Found \(duplicates.count) repeated sentence(s). Redundancy wastes tokens without adding value.",
                matchedText: duplicates.first ?? "",
                severity: .info,
                fixSuggestion: "Remove duplicate sentences and consolidate overlapping instructions."
            ))
        }

        // 7. Scope creep: extremely long prompt with many topics
        if words.count > 200 {
            results.append(PromptAntiPattern(
                id: UUID().uuidString,
                category: .scopeCreep,
                title: "Prompt is excessively long (\(words.count) words)",
                description: "Very long prompts dilute focus and increase cost. Consider breaking into multiple prompts.",
                matchedText: "",
                severity: .warning,
                fixSuggestion: "Split into focused sub-prompts of 50-100 words each, executed sequentially."
            ))
        }

        return results.sorted { $0.severity < $1.severity }
    }

    // MARK: - Automated Rewrite

    private func generateRewrite(for prompt: String, score: PromptQualityScore, antiPatterns: [PromptAntiPattern]) -> PromptRewriteSuggestion? {
        guard score.overallScore < 0.8 else { return nil }

        var rewritten = prompt
        var appliedRules: [String] = []

        // Rule 1: Add action verb if missing
        let firstWord = String(rewritten.prefix(while: { !$0.isWhitespace })).lowercased()
        let actionVerbs = ["add", "fix", "create", "implement", "update", "remove", "build", "write",
                           "refactor", "optimize", "debug", "test", "deploy", "configure",
                           "新增", "修復", "建立", "實作", "更新", "移除", "撰寫", "重構", "優化", "測試"]
        if !actionVerbs.contains(firstWord) && !rewritten.isEmpty {
            // Detect if it's a question vs instruction
            let isQuestion = rewritten.hasSuffix("?") || rewritten.hasSuffix("？")
            if !isQuestion {
                rewritten = "Implement the following: " + rewritten
                appliedRules.append("Added action verb prefix")
            }
        }

        // Rule 2: Replace vague references
        let vagueReplacements: [(String, String)] = [
            ("fix it", "fix the [specific component]"),
            ("make it work", "ensure the [feature] produces [expected output]"),
            ("make it better", "improve [metric] by [criteria]"),
            ("do it", "perform [specific action]"),
        ]
        for (vague, replacement) in vagueReplacements {
            if rewritten.lowercased().contains(vague) {
                rewritten = rewritten.replacingOccurrences(of: vague, with: replacement,
                    options: .caseInsensitive)
                appliedRules.append("Replaced vague reference: '\(vague)'")
            }
        }

        // Rule 3: Add structure markers if long and unstructured
        let wordCount = rewritten.split(separator: " ").count
        if wordCount > 30 && !rewritten.contains("1.") && !rewritten.contains("-") && !rewritten.contains("*") {
            rewritten += "\n\nExpected outcome: [describe what success looks like]"
            appliedRules.append("Added outcome placeholder")
        }

        // Rule 4: Add constraints reminder if missing
        let lowerRewritten = rewritten.lowercased()
        let hasConstraintsNow = lowerRewritten.contains("must") || lowerRewritten.contains("should") ||
            lowerRewritten.contains("ensure") || lowerRewritten.contains("必須") || lowerRewritten.contains("確保")
        if !hasConstraintsNow && wordCount > 10 {
            rewritten += "\n\nConstraints: [add any requirements or limitations]"
            appliedRules.append("Added constraints placeholder")
        }

        guard !appliedRules.isEmpty else { return nil }

        let estimatedImprovement = min(Double(appliedRules.count) * 0.05, 0.2)

        return PromptRewriteSuggestion(
            id: UUID().uuidString,
            originalPrompt: prompt,
            rewrittenPrompt: rewritten,
            improvementSummary: "Applied \(appliedRules.count) optimization rule(s)",
            estimatedScoreImprovement: estimatedImprovement,
            appliedRules: appliedRules,
            createdAt: Date()
        )
    }

    // MARK: - Helper Methods

    private func extractTags(from prompt: String) -> [String] {
        let lower = prompt.lowercased()
        var tags: [String] = []

        let tagMap: [String: [String]] = [
            "bug-fix": ["fix", "bug", "error", "crash", "issue", "修復", "錯誤", "問題"],
            "feature": ["add", "new", "implement", "create", "feature", "新增", "實作", "功能"],
            "refactor": ["refactor", "clean", "improve", "optimize", "重構", "優化", "改善"],
            "test": ["test", "spec", "coverage", "測試"],
            "docs": ["document", "readme", "comment", "文件", "註解"],
            "style": ["style", "css", "ui", "design", "layout", "樣式", "設計", "介面"],
        ]

        for (tag, keywords) in tagMap {
            if keywords.contains(where: { lower.contains($0) }) {
                tags.append(tag)
            }
        }

        return tags
    }

    private func matchPattern(_ prompt: String) -> String? {
        for pattern in patterns {
            let tags = extractTags(from: prompt)
            if tags.contains(pattern.name.lowercased()) || tags.contains("pattern-\(pattern.name.lowercased())") {
                return pattern.id
            }
        }
        return nil
    }

    private func updatePatternStats(patternId: String) {
        guard let idx = patterns.firstIndex(where: { $0.id == patternId }) else { return }
        let relatedRecords = history.filter { $0.patternId == patternId && $0.isCompleted }
        let successCount = relatedRecords.filter { $0.wasSuccessful == true }.count
        patterns[idx].matchCount = relatedRecords.count
        patterns[idx].avgSuccessRate = relatedRecords.isEmpty ? 0 : Double(successCount) / Double(relatedRecords.count)
        patterns[idx].avgDuration = relatedRecords.compactMap(\.taskDuration).reduce(0, +) / max(Double(relatedRecords.count), 1)
        patterns[idx].avgTokens = relatedRecords.compactMap(\.tokenCount).reduce(0, +) / max(relatedRecords.count, 1)
    }

    private func calculateVariantScore(_ variant: PromptVariant) -> Double {
        var score = 0.0
        if variant.wasSuccessful == true { score += 50 }
        if let duration = variant.duration { score += max(0, 100 - duration / 10) }
        if let tokens = variant.tokenCount { score += max(0, 50 - Double(tokens) / 100) }
        return score
    }

    private func generateContextSuggestions(prefix: String, files: [String]) -> [PromptAutocompleteSuggestion] {
        let commonPrefixes: [(String, String)] = [
            ("fix", "Fix the bug in "),
            ("add", "Add a new feature to "),
            ("implement", "Implement the "),
            ("update", "Update the "),
            ("refactor", "Refactor the "),
            ("create", "Create a new "),
            ("test", "Write tests for "),
            ("optimize", "Optimize the performance of "),
            ("debug", "Debug the issue with "),
            ("remove", "Remove the deprecated "),
        ]

        return commonPrefixes
            .filter { $0.0.hasPrefix(prefix) || prefix.hasPrefix($0.0) }
            .prefix(3)
            .enumerated()
            .map { idx, pair in
                PromptAutocompleteSuggestion(
                    id: "context-\(idx)",
                    text: pair.1,
                    category: "Common",
                    relevanceScore: 0.6,
                    source: .projectContext
                )
            }
    }

    // MARK: - History Filtering & Sorting

    /// Apply current filter and sort to history, updating filteredHistory
    func applyFilterAndSort() {
        var results = history

        // Filter by tag
        if let tag = historyFilterTag {
            results = results.filter { $0.tags.contains(tag) }
        }

        // Filter by success/failed
        if let success = historyFilterSuccess {
            results = results.filter { $0.wasSuccessful == success }
        }

        // Sort
        results.sort { lhs, rhs in
            switch historySortOption {
            case .dateDesc:
                return lhs.sentAt > rhs.sentAt
            case .dateAsc:
                return lhs.sentAt < rhs.sentAt
            case .qualityDesc:
                return (lhs.qualityScore?.overallScore ?? 0) > (rhs.qualityScore?.overallScore ?? 0)
            case .qualityAsc:
                return (lhs.qualityScore?.overallScore ?? 0) < (rhs.qualityScore?.overallScore ?? 0)
            case .tokenDesc:
                return (lhs.tokenCount ?? 0) > (rhs.tokenCount ?? 0)
            case .costDesc:
                return (lhs.costUSD ?? 0) > (rhs.costUSD ?? 0)
            }
        }

        filteredHistory = results
    }

    /// Set tag filter and refresh
    func setFilterTag(_ tag: String?) {
        historyFilterTag = tag
        applyFilterAndSort()
    }

    /// Set success filter and refresh
    func setFilterSuccess(_ success: Bool?) {
        historyFilterSuccess = success
        applyFilterAndSort()
    }

    /// Set sort option and refresh
    func setSortOption(_ option: PromptHistorySortOption) {
        historySortOption = option
        applyFilterAndSort()
    }

    /// Set grouping and regenerate stats
    func setGrouping(_ grouping: PromptHistoryTimeGrouping) {
        historyGrouping = grouping
        generateGroupedStats()
    }

    /// Get all unique tags from history
    func getAllTags() -> [String] {
        var tags = Set<String>()
        for record in history {
            tags.formUnion(record.tags)
        }
        return Array(tags).sorted()
    }

    // MARK: - Statistics Aggregation

    /// Generate time-grouped statistics based on current grouping
    func generateGroupedStats() {
        guard !history.isEmpty else {
            groupedStats = []
            categoryStats = []
            return
        }

        let calendar = Calendar.current
        var groups: [String: [PromptHistoryRecord]] = [:]
        var periodDates: [String: (start: Date, end: Date)] = [:]

        for record in history {
            let key: String
            let periodStart: Date
            let periodEnd: Date

            switch historyGrouping {
            case .daily:
                let comp = calendar.dateComponents([.year, .month, .day], from: record.sentAt)
                key = String(format: "%04d-%02d-%02d", comp.year ?? 0, comp.month ?? 0, comp.day ?? 0)
                periodStart = calendar.startOfDay(for: record.sentAt)
                periodEnd = calendar.date(byAdding: .day, value: 1, to: periodStart) ?? periodStart

            case .weekly:
                let comp = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.sentAt)
                key = "W\(comp.weekOfYear ?? 0) \(comp.yearForWeekOfYear ?? 0)"
                periodStart = calendar.date(from: comp) ?? record.sentAt
                periodEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: periodStart) ?? periodStart

            case .monthly:
                let comp = calendar.dateComponents([.year, .month], from: record.sentAt)
                key = String(format: "%04d-%02d", comp.year ?? 0, comp.month ?? 0)
                periodStart = calendar.date(from: comp) ?? record.sentAt
                periodEnd = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
            }

            groups[key, default: []].append(record)
            if periodDates[key] == nil {
                periodDates[key] = (start: periodStart, end: periodEnd)
            }
        }

        var stats: [PromptHistoryStats] = []
        for (label, records) in groups {
            let successCount = records.filter { $0.wasSuccessful == true }.count
            let failedCount = records.filter { $0.wasSuccessful == false }.count
            let scores = records.compactMap { $0.qualityScore?.overallScore }
            let avgScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            let totalTokens = records.compactMap { $0.tokenCount }.reduce(0, +)
            let totalCost = records.compactMap { $0.costUSD }.reduce(0, +)

            var tagDist: [String: Int] = [:]
            for record in records {
                for tag in record.tags {
                    tagDist[tag, default: 0] += 1
                }
            }

            let dates = periodDates[label] ?? (start: Date(), end: Date())
            stats.append(PromptHistoryStats(
                id: label,
                periodLabel: label,
                periodStart: dates.start,
                periodEnd: dates.end,
                totalCount: records.count,
                successCount: successCount,
                failedCount: failedCount,
                avgQualityScore: avgScore,
                totalTokens: totalTokens,
                totalCostUSD: totalCost,
                tagDistribution: tagDist
            ))
        }

        groupedStats = stats.sorted { $0.periodStart > $1.periodStart }

        // Also generate category stats
        generateCategoryStats()
    }

    /// Generate category-based statistics grouped by tag
    private func generateCategoryStats() {
        guard !history.isEmpty else {
            categoryStats = []
            return
        }

        var tagGroups: [String: [PromptHistoryRecord]] = [:]
        for record in history {
            for tag in record.tags {
                tagGroups[tag, default: []].append(record)
            }
        }

        var stats: [PromptCategoryStats] = []
        for (tag, records) in tagGroups {
            let withResult = records.filter { $0.wasSuccessful != nil }
            let successCount = records.filter { $0.wasSuccessful == true }.count
            let successRate = withResult.isEmpty ? 0 : Double(successCount) / Double(withResult.count)
            let scores = records.compactMap { $0.qualityScore?.overallScore }
            let avgScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            let avgTokens = records.compactMap(\.tokenCount).reduce(0, +) / max(records.count, 1)
            let totalCost = records.compactMap(\.costUSD).reduce(0, +)
            let lastUsed = records.map(\.sentAt).max() ?? Date()

            stats.append(PromptCategoryStats(
                id: tag,
                categoryName: tag,
                count: records.count,
                successRate: successRate,
                avgQualityScore: avgScore,
                avgTokens: avgTokens,
                totalCostUSD: totalCost,
                lastUsed: lastUsed
            ))
        }

        categoryStats = stats.sorted { $0.count > $1.count }
    }

    // MARK: - Memory Management

    /// Prune data that exceeds memory limits
    func pruneOldData() {
        var didChange = false

        // Enforce history limit
        if history.count > Self.maxHistoryRecords {
            history = Array(history.prefix(Self.maxHistoryRecords))
            didChange = true
        }

        // Enforce A/B tests limit (keep newest)
        if abTests.count > Self.maxABTests {
            abTests = Array(abTests.prefix(Self.maxABTests))
            didChange = true
        }

        // Enforce global versions limit (keep newest)
        if versions.count > Self.maxVersions {
            versions = Array(versions.prefix(Self.maxVersions))
            didChange = true
        }

        // Expire stale cache entries
        let now = Date()
        let expiredKeys = scoreCache.filter { now.timeIntervalSince($0.value.cachedAt) > Self.cacheExpirySeconds }.map(\.key)
        for key in expiredKeys {
            scoreCache.removeValue(forKey: key)
            scoreCacheOrder.removeAll { $0 == key }
        }

        if didChange {
            applyFilterAndSort()
            save()
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
        if let data = try? JSONEncoder().encode(patterns) {
            UserDefaults.standard.set(data, forKey: Self.patternsKey)
        }
        if let data = try? JSONEncoder().encode(abTests) {
            UserDefaults.standard.set(data, forKey: Self.abTestsKey)
        }
        if let data = try? JSONEncoder().encode(versions) {
            UserDefaults.standard.set(data, forKey: Self.versionsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let decoded = try? JSONDecoder().decode([PromptHistoryRecord].self, from: data) {
            history = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.patternsKey),
           let decoded = try? JSONDecoder().decode([PromptPattern].self, from: data) {
            patterns = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.abTestsKey),
           let decoded = try? JSONDecoder().decode([PromptABTest].self, from: data) {
            abTests = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.versionsKey),
           let decoded = try? JSONDecoder().decode([PromptVersion].self, from: data) {
            versions = decoded
        }
        isHistoryLoaded = true

        // Prune on load to enforce limits on legacy data
        pruneOldData()

        applyFilterAndSort()
    }
}
