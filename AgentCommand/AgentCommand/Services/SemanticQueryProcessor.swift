import Foundation
import NaturalLanguage

// MARK: - H5: Semantic Query Processor (NLP Preprocessing Pipeline)

/// Preprocesses natural language queries through tokenization, entity extraction,
/// language detection, stop-word removal, stemming, and query expansion.
///
/// ## Processing Pipeline (Flow Chart):
/// ```
/// ┌─────────────────┐
/// │  Raw User Query  │
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 1. Normalize     │  lowercase, trim whitespace, collapse spaces
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 2. Detect Lang   │  NLLanguageRecognizer → en/zh-Hant/zh-Hans/ja/mixed
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 3. Tokenize      │  NLTokenizer (word-level)
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 4. Remove Stops  │  language-aware stop word removal
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 5. Stem/Lemma    │  NLTagger lemmatization
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 6. Extract Ents  │  regex + heuristic entity extraction
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 7. Expand Terms  │  synonym map + code-aware expansion
/// └────────┬────────┘
///          ▼
/// ┌─────────────────┐
/// │ 8. Build FTS     │  construct FTS5-ready query string
/// └────────┬────────┘
///          ▼
/// ┌─────────────────────┐
/// │  PreprocessedQuery   │
/// └─────────────────────┘
/// ```
@MainActor
class SemanticQueryProcessor: ObservableObject {

    @Published var lastPreprocessed: PreprocessedQuery?

    /// Known project entities for matching (populated from RAG index)
    var knownFileNames: Set<String> = []
    var knownClassNames: Set<String> = []
    var knownFunctionNames: Set<String> = []

    // MARK: - Main Pipeline

    /// Run the full preprocessing pipeline on a raw query
    func preprocess(_ rawQuery: String) -> PreprocessedQuery {
        var result = PreprocessedQuery(originalQuery: rawQuery)

        // Step 1: Normalize
        result.normalizedQuery = normalize(rawQuery)

        // Step 2: Detect language
        result.detectedLanguage = detectLanguage(result.normalizedQuery)

        // Step 3: Tokenize
        result.tokens = tokenize(result.normalizedQuery)

        // Step 4: Remove stop words
        result.stopWordsRemoved = removeStopWords(result.tokens, language: result.detectedLanguage)

        // Step 5: Stem / lemmatize
        result.stemmedTokens = lemmatize(result.stopWordsRemoved, language: result.detectedLanguage)

        // Step 6: Extract entities
        result.entities = extractEntities(from: rawQuery)

        // Step 7: Expand terms
        result.expandedTerms = expandTerms(result.stemmedTokens, entities: result.entities)

        // Step 8: Build FTS5 query
        result.ftsQuery = buildFTSQuery(stemmed: result.stemmedTokens, expanded: result.expandedTerms, entities: result.entities)

        // Derive semantic keywords (top terms by importance)
        result.semanticKeywords = deriveSemanticKeywords(result)

        result.preprocessedAt = Date()
        lastPreprocessed = result
        return result
    }

    // MARK: - Step 1: Normalization

    private func normalize(_ query: String) -> String {
        var normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple spaces into one
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }

        // Remove leading/trailing quotes if wrapping the entire query
        if normalized.hasPrefix("\"") && normalized.hasSuffix("\"") && normalized.count > 2 {
            normalized = String(normalized.dropFirst().dropLast())
        }

        return normalized
    }

    // MARK: - Step 2: Language Detection

    private func detectLanguage(_ text: String) -> QueryLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominant = recognizer.dominantLanguage else {
            return .english
        }

        // Check for CJK characters
        let cjkCount = text.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        let totalChars = max(text.count, 1)
        let cjkRatio = Float(cjkCount) / Float(totalChars)

        // Mixed language detection
        if cjkRatio > 0.1 && cjkRatio < 0.7 {
            return .mixed
        }

        switch dominant {
        case .traditionalChinese:
            return .chineseTraditional
        case .simplifiedChinese:
            return .chineseSimplified
        case .japanese:
            return .japanese
        default:
            return cjkRatio > 0.5 ? .chineseTraditional : .english
        }
    }

    // MARK: - Step 3: Tokenization

    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            if !token.trimmingCharacters(in: .whitespaces).isEmpty {
                tokens.append(token)
            }
            return true
        }

        return tokens
    }

    // MARK: - Step 4: Stop Word Removal

    private func removeStopWords(_ tokens: [String], language: QueryLanguage) -> [String] {
        let stopWords = Set(language.stopWords)
        return tokens.filter { !stopWords.contains($0.lowercased()) }
    }

    // MARK: - Step 5: Lemmatization

    private func lemmatize(_ tokens: [String], language: QueryLanguage) -> [String] {
        let nlLanguage: NLLanguage
        switch language {
        case .english: nlLanguage = .english
        case .chineseTraditional: nlLanguage = .traditionalChinese
        case .chineseSimplified: nlLanguage = .simplifiedChinese
        case .japanese: nlLanguage = .japanese
        case .mixed: nlLanguage = .english
        }

        let tagger = NLTagger(tagSchemes: [.lemma])
        var results: [String] = []

        for token in tokens {
            tagger.string = token
            tagger.setLanguage(nlLanguage, range: token.startIndex..<token.endIndex)

            var lemma = token
            tagger.enumerateTags(in: token.startIndex..<token.endIndex, unit: .word, scheme: .lemma) { tag, _ in
                if let tag = tag {
                    lemma = tag.rawValue
                }
                return true
            }
            results.append(lemma.lowercased())
        }

        return results
    }

    // MARK: - Step 6: Entity Extraction

    /// Extract code-related entities using regex patterns and known project names
    func extractEntities(from query: String) -> [QueryEntity] {
        var entities: [QueryEntity] = []

        // 6a. File names: word.ext pattern
        let filePattern = #"\b[\w\-]+\.(swift|py|js|ts|tsx|jsx|json|yaml|yml|md|html|css|scss|txt)\b"#
        entities.append(contentsOf: matchPattern(filePattern, in: query, type: .fileName))

        // 6b. File paths: contains /
        let pathPattern = #"[\w\-]+/[\w\-./]+"#
        entities.append(contentsOf: matchPattern(pathPattern, in: query, type: .filePath))

        // 6c. Class/Type names: PascalCase words (2+ uppercase transitions)
        let classPattern = #"\b[A-Z][a-z]+(?:[A-Z][a-z]+){1,}\b"#
        entities.append(contentsOf: matchPattern(classPattern, in: query, type: .className))

        // 6d. Function names: word( or word(param:)
        let funcPattern = #"\b\w+\([^)]*\)"#
        entities.append(contentsOf: matchPattern(funcPattern, in: query, type: .functionName))

        // 6e. Line numbers: "line 42", "L42", "行42"
        let linePattern = #"(?:line|L|行)\s*(\d+)"#
        entities.append(contentsOf: matchPattern(linePattern, in: query, type: .lineNumber))

        // 6f. Error messages: quoted strings that look like errors
        let errorPattern = #"['\"]([^'\"]*(?:error|crash|nil|fail|exception|undefined)[^'\"]*)['\"]"#
        entities.append(contentsOf: matchPattern(errorPattern, in: query, type: .errorMessage))

        // 6g. Framework names: known frameworks
        let frameworks = ["SwiftUI", "SceneKit", "UIKit", "AppKit", "Combine", "Foundation",
                         "CoreData", "CloudKit", "React", "Vue", "Angular", "Express",
                         "Django", "Flask", "NaturalLanguage", "SQLite"]
        for fw in frameworks {
            if query.localizedCaseInsensitiveContains(fw) {
                if let range = query.range(of: fw, options: .caseInsensitive) {
                    let startIdx = query.distance(from: query.startIndex, to: range.lowerBound)
                    entities.append(QueryEntity(
                        type: .frameworkName,
                        value: fw,
                        originalSpan: String(query[range]),
                        startIndex: startIdx
                    ))
                }
            }
        }

        // 6h. Match against known project entities
        for knownFile in knownFileNames {
            let nameWithoutExt = knownFile.components(separatedBy: ".").first ?? knownFile
            if query.localizedCaseInsensitiveContains(nameWithoutExt) && nameWithoutExt.count >= 3 {
                if let range = query.range(of: nameWithoutExt, options: .caseInsensitive) {
                    let startIdx = query.distance(from: query.startIndex, to: range.lowerBound)
                    entities.append(QueryEntity(
                        type: .fileName,
                        value: knownFile,
                        originalSpan: String(query[range]),
                        startIndex: startIdx,
                        confidence: 0.9
                    ))
                }
            }
        }

        for knownClass in knownClassNames {
            if query.localizedCaseInsensitiveContains(knownClass) && knownClass.count >= 3 {
                if let range = query.range(of: knownClass, options: .caseInsensitive) {
                    let startIdx = query.distance(from: query.startIndex, to: range.lowerBound)
                    entities.append(QueryEntity(
                        type: .className,
                        value: knownClass,
                        originalSpan: String(query[range]),
                        startIndex: startIdx,
                        confidence: 0.95
                    ))
                }
            }
        }

        // Deduplicate by overlapping spans
        return deduplicateEntities(entities)
    }

    // MARK: - Step 7: Term Expansion

    private func expandTerms(_ stemmed: [String], entities: [QueryEntity]) -> [String] {
        var expanded: [String] = []

        let synonymMap: [String: [String]] = [
            "fix": ["repair", "resolve", "patch", "debug"],
            "bug": ["issue", "defect", "error", "problem"],
            "error": ["exception", "failure", "crash", "fault"],
            "add": ["create", "implement", "insert", "introduce"],
            "remove": ["delete", "drop", "eliminate", "discard"],
            "search": ["find", "locate", "look", "query"],
            "function": ["method", "func", "procedure", "handler"],
            "class": ["struct", "type", "model", "entity"],
            "test": ["spec", "unittest", "assert", "verify"],
            "refactor": ["restructure", "reorganize", "clean", "simplify"],
            "performance": ["speed", "optimize", "fast", "slow", "latency"],
            "authentication": ["auth", "login", "signin", "credential"],
            "database": ["db", "storage", "persist", "sqlite", "repository"],
            "api": ["endpoint", "route", "handler", "service"],
            // CJK synonyms
            "搜尋": ["查找", "尋找", "檢索"],
            "修復": ["修正", "修改", "解決"],
            "錯誤": ["問題", "異常", "故障"],
            "新增": ["添加", "建立", "加入"],
            "刪除": ["移除", "清除", "去除"],
        ]

        for term in stemmed {
            if let synonyms = synonymMap[term.lowercased()] {
                expanded.append(contentsOf: synonyms)
            }
        }

        // Add entity values as search terms
        for entity in entities {
            expanded.append(entity.value)
        }

        return Array(Set(expanded)) // deduplicate
    }

    // MARK: - Step 8: FTS5 Query Builder

    private func buildFTSQuery(stemmed: [String], expanded: [String], entities: [QueryEntity]) -> String {
        var parts: [String] = []

        // Primary terms (stemmed, high priority) with OR
        let primaryTerms = stemmed
            .filter { $0.count >= 2 }
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        if !primaryTerms.isEmpty {
            parts.append(primaryTerms.joined(separator: " OR "))
        }

        // Entity values get exact-match priority
        let entityTerms = entities
            .map { "\"\($0.value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        if !entityTerms.isEmpty {
            parts.append(entityTerms.joined(separator: " OR "))
        }

        // Expanded terms (lower priority, also OR)
        let expandedTerms = expanded
            .prefix(5)
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        if !expandedTerms.isEmpty {
            parts.append(expandedTerms.joined(separator: " OR "))
        }

        return parts.joined(separator: " OR ")
    }

    // MARK: - Semantic Keywords

    private func deriveSemanticKeywords(_ processed: PreprocessedQuery) -> [String] {
        // Combine entity values + stemmed tokens, ranked by importance
        var keywords: [(String, Float)] = []

        for entity in processed.entities {
            keywords.append((entity.value, entity.confidence * 2.0)) // entities are high value
        }

        for token in processed.stemmedTokens {
            if token.count >= 3 {
                keywords.append((token, 1.0))
            }
        }

        // Sort by score, deduplicate, take top 10
        let sorted = keywords
            .sorted { $0.1 > $1.1 }
        var seen = Set<String>()
        var result: [String] = []
        for (kw, _) in sorted {
            let lower = kw.lowercased()
            if !seen.contains(lower) {
                seen.insert(lower)
                result.append(kw)
            }
            if result.count >= 10 { break }
        }

        return result
    }

    // MARK: - Helpers

    private func matchPattern(_ pattern: String, in text: String, type: QueryEntity.EntityType) -> [QueryEntity] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.map { match in
            let matchedText = nsText.substring(with: match.range)
            return QueryEntity(
                type: type,
                value: matchedText,
                originalSpan: matchedText,
                startIndex: match.range.location,
                confidence: 0.8
            )
        }
    }

    private func deduplicateEntities(_ entities: [QueryEntity]) -> [QueryEntity] {
        var result: [QueryEntity] = []
        let sorted = entities.sorted { $0.confidence > $1.confidence }

        for entity in sorted {
            let overlaps = result.contains { existing in
                let existingEnd = existing.startIndex + existing.originalSpan.count
                let entityEnd = entity.startIndex + entity.originalSpan.count
                return (entity.startIndex < existingEnd && entityEnd > existing.startIndex)
            }
            if !overlaps {
                result.append(entity)
            }
        }

        return result
    }

    // MARK: - Populate Known Entities from RAG

    /// Update known entities from the RAG document index
    func updateKnownEntities(documents: [RAGDocument]) {
        knownFileNames = Set(documents.map(\.fileName))

        // Extract class names from Swift files by scanning content previews
        var classes = Set<String>()
        let classPattern = #"(?:class|struct|enum|protocol)\s+(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: classPattern) else { return }

        for doc in documents where doc.fileType == .swift {
            let nsPreview = doc.contentPreview as NSString
            let matches = regex.matches(in: doc.contentPreview, range: NSRange(location: 0, length: nsPreview.length))
            for match in matches {
                if match.numberOfRanges >= 2 {
                    classes.insert(nsPreview.substring(with: match.range(at: 1)))
                }
            }
        }
        knownClassNames = classes
    }
}
