import Foundation

// MARK: - RAG Hybrid Ranker (Reciprocal Rank Fusion)

/// Fuses keyword (FTS5) and vector search results using Reciprocal Rank Fusion (RRF),
/// then applies metadata boosting for final ranking.
struct RAGHybridRanker {

    struct RankedResult {
        let documentId: String
        let chunkId: Int?
        let ftsRank: Int?
        let vectorRank: Int?
        let rrfScore: Float
        var finalScore: Float
        let snippet: String
        let lineNumber: Int?
        let symbolName: String?
        let filePath: String
    }

    // MARK: - Score Fusion

    /// Fuse two ranked lists using Reciprocal Rank Fusion
    ///
    /// RRF(d) = Σ 1 / (k + rank_i)
    /// k = 60 (standard constant)
    func fuse(
        ftsResults: [RAGSearchResult],
        vectorResults: [(chunkId: Int, documentId: String, score: Float, snippet: String, startLine: Int, symbolName: String?, filePath: String)],
        k: Int = 60
    ) -> [RankedResult] {
        var scoreMap: [String: RankedResult] = [:]

        // Process FTS results
        for (rank, result) in ftsResults.enumerated() {
            let key = result.document.id
            let rrfContribution = 1.0 / Float(k + rank + 1)

            if var existing = scoreMap[key] {
                existing.finalScore += rrfContribution
                scoreMap[key] = RankedResult(
                    documentId: existing.documentId,
                    chunkId: existing.chunkId,
                    ftsRank: rank + 1,
                    vectorRank: existing.vectorRank,
                    rrfScore: existing.rrfScore + rrfContribution,
                    finalScore: existing.finalScore,
                    snippet: existing.snippet,
                    lineNumber: existing.lineNumber,
                    symbolName: existing.symbolName,
                    filePath: existing.filePath
                )
            } else {
                scoreMap[key] = RankedResult(
                    documentId: result.document.id,
                    chunkId: nil,
                    ftsRank: rank + 1,
                    vectorRank: nil,
                    rrfScore: rrfContribution,
                    finalScore: rrfContribution,
                    snippet: result.matchedSnippet,
                    lineNumber: result.lineNumber,
                    symbolName: nil,
                    filePath: result.document.filePath
                )
            }
        }

        // Process vector results
        for (rank, result) in vectorResults.enumerated() {
            let key = "\(result.documentId)-chunk-\(result.chunkId)"
            let rrfContribution = 1.0 / Float(k + rank + 1)

            if var existing = scoreMap[key] {
                existing.finalScore += rrfContribution
                scoreMap[key] = RankedResult(
                    documentId: existing.documentId,
                    chunkId: result.chunkId,
                    ftsRank: existing.ftsRank,
                    vectorRank: rank + 1,
                    rrfScore: existing.rrfScore + rrfContribution,
                    finalScore: existing.finalScore,
                    snippet: existing.snippet,
                    lineNumber: existing.lineNumber,
                    symbolName: existing.symbolName,
                    filePath: existing.filePath
                )
            } else {
                scoreMap[key] = RankedResult(
                    documentId: result.documentId,
                    chunkId: result.chunkId,
                    ftsRank: nil,
                    vectorRank: rank + 1,
                    rrfScore: rrfContribution,
                    finalScore: rrfContribution,
                    snippet: result.snippet,
                    lineNumber: result.startLine,
                    symbolName: result.symbolName,
                    filePath: result.filePath
                )
            }

            // Also contribute to document-level score
            let docKey = result.documentId
            if var existing = scoreMap[docKey] {
                let docContribution = rrfContribution * 0.5 // partial contribution
                existing.finalScore += docContribution
                scoreMap[docKey] = RankedResult(
                    documentId: existing.documentId,
                    chunkId: existing.chunkId,
                    ftsRank: existing.ftsRank,
                    vectorRank: existing.vectorRank,
                    rrfScore: existing.rrfScore + docContribution,
                    finalScore: existing.finalScore,
                    snippet: existing.snippet,
                    lineNumber: existing.lineNumber,
                    symbolName: existing.symbolName,
                    filePath: existing.filePath
                )
            }
        }

        return Array(scoreMap.values).sorted { $0.finalScore > $1.finalScore }
    }

    // MARK: - Metadata Boosting

    /// Apply metadata boosting to RRF scores
    func applyBoosts(
        results: [RankedResult],
        documents: [RAGDocument],
        relationships: [RAGRelationship],
        query: String
    ) -> [RankedResult] {
        let queryLower = query.lowercased()
        let topDocIds = Set(results.prefix(5).map(\.documentId))
        let docLookup = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })

        return results.map { result in
            var boosted = result
            guard let doc = docLookup[result.documentId] else { return boosted }

            // File type match boost (+0.15)
            let fileTypeNames = RAGFileType.allCases.map(\.rawValue)
            for typeName in fileTypeNames {
                if queryLower.contains(typeName) && doc.fileType.rawValue == typeName {
                    boosted.finalScore += 0.15
                    break
                }
            }

            // Symbol name match boost (+0.20)
            if let symbolName = result.symbolName {
                let symbolLower = symbolName.lowercased()
                let queryWords = queryLower.split(separator: " ").map(String.init)
                for word in queryWords {
                    if symbolLower.contains(word) {
                        boosted.finalScore += 0.20
                        break
                    }
                }
            }

            // Recency boost
            let elapsed = Date().timeIntervalSince(doc.lastModified)
            if elapsed < 86400 { // < 1 day
                boosted.finalScore += 0.10
            } else if elapsed < 604800 { // < 7 days
                boosted.finalScore += 0.05
            }

            // Import relationship boost (+0.05)
            let relatedDocs = relationships.filter {
                ($0.sourceId == result.documentId || $0.targetId == result.documentId)
            }
            for rel in relatedDocs {
                let otherId = rel.sourceId == result.documentId ? rel.targetId : rel.sourceId
                if topDocIds.contains(otherId) {
                    boosted.finalScore += 0.05
                    break
                }
            }

            // File size penalty (-0.05 for very large files)
            if doc.lineCount > 500 {
                boosted.finalScore -= 0.05
            }

            return boosted
        }
        .sorted { $0.finalScore > $1.finalScore }
    }

    // MARK: - Deduplication

    /// Deduplicate results from same document, keeping at most maxPerDocument entries
    func deduplicate(_ results: [RankedResult], maxPerDocument: Int = 3) -> [RankedResult] {
        var docCounts: [String: Int] = [:]
        var deduped: [RankedResult] = []

        for result in results {
            let count = docCounts[result.documentId, default: 0]
            if count < maxPerDocument {
                deduped.append(result)
                docCounts[result.documentId] = count + 1
            }
        }

        return deduped
    }
}
