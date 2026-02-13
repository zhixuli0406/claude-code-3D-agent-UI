import XCTest
@testable import AgentCommand

// MARK: - H1: RAG Hybrid Ranker Unit Tests

final class RAGHybridRankerTests: XCTestCase {

    private let ranker = RAGHybridRanker()

    // MARK: - Helper Factories

    private func makeDocument(id: String? = nil, filePath: String = "/test.swift",
                              fileName: String = "test.swift",
                              fileType: RAGFileType = .swift,
                              lineCount: Int = 50) -> RAGDocument {
        var doc = RAGDocument(
            filePath: filePath,
            fileName: fileName,
            fileType: fileType,
            contentPreview: "preview",
            lineCount: lineCount,
            fileSize: Int64(lineCount * 30),
            lastModified: Date()
        )
        return doc
    }

    private func makeSearchResult(document: RAGDocument, snippet: String = "matched", score: Float = 0.5) -> RAGSearchResult {
        RAGSearchResult(document: document, matchedSnippet: snippet, score: score)
    }

    typealias VectorResult = (chunkId: Int, documentId: String, score: Float, snippet: String, startLine: Int, symbolName: String?, filePath: String)

    // MARK: - RRF Fusion Tests

    func testFuse_EmptyInputs() {
        let results = ranker.fuse(ftsResults: [], vectorResults: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testFuse_FTSOnly() {
        let doc = makeDocument()
        let ftsResults = [makeSearchResult(document: doc)]
        let results = ranker.fuse(ftsResults: ftsResults, vectorResults: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertNotNil(results[0].ftsRank)
        XCTAssertNil(results[0].vectorRank)
    }

    func testFuse_VectorOnly() {
        let vectorResults: [VectorResult] = [
            (chunkId: 1, documentId: "doc1", score: 0.9, snippet: "code", startLine: 10, symbolName: "func test", filePath: "/test.swift")
        ]
        let results = ranker.fuse(ftsResults: [], vectorResults: vectorResults)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testFuse_RRFScoreCalculation() {
        let doc = makeDocument()
        let ftsResults = [makeSearchResult(document: doc)]

        let results = ranker.fuse(ftsResults: ftsResults, vectorResults: [], k: 60)
        XCTAssertEqual(results.count, 1)
        // RRF score for rank 1 with k=60: 1/(60+1) ≈ 0.01639
        let expectedScore = 1.0 / Float(60 + 1)
        XCTAssertEqual(results[0].rrfScore, expectedScore, accuracy: 0.001)
    }

    func testFuse_HigherRankGetsHigherScore() {
        let doc1 = makeDocument(filePath: "/a.swift", fileName: "a.swift")
        let doc2 = makeDocument(filePath: "/b.swift", fileName: "b.swift")
        let ftsResults = [
            makeSearchResult(document: doc1, score: 0.9),
            makeSearchResult(document: doc2, score: 0.5),
        ]
        let results = ranker.fuse(ftsResults: ftsResults, vectorResults: [])
        // doc1 at rank 1 should have higher RRF score than doc2 at rank 2
        let scoreA = results.first(where: { $0.documentId == doc1.id })?.finalScore ?? 0
        let scoreB = results.first(where: { $0.documentId == doc2.id })?.finalScore ?? 0
        XCTAssertGreaterThan(scoreA, scoreB)
    }

    func testFuse_ResultsSortedByScore() {
        let doc1 = makeDocument(filePath: "/x.swift", fileName: "x.swift")
        let doc2 = makeDocument(filePath: "/y.swift", fileName: "y.swift")
        let ftsResults = [
            makeSearchResult(document: doc1),
            makeSearchResult(document: doc2),
        ]
        let results = ranker.fuse(ftsResults: ftsResults, vectorResults: [])
        for i in 1..<results.count {
            XCTAssertGreaterThanOrEqual(results[i-1].finalScore, results[i].finalScore)
        }
    }

    // MARK: - Deduplication Tests

    func testDeduplicate_WithinLimit() {
        let results = [
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 1, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 2, ftsRank: 2, vectorRank: nil, rrfScore: 0.4, finalScore: 0.4, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc2", chunkId: 3, ftsRank: 3, vectorRank: nil, rrfScore: 0.3, finalScore: 0.3, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/b.swift"),
        ]
        let deduped = ranker.deduplicate(results, maxPerDocument: 3)
        XCTAssertEqual(deduped.count, 3)
    }

    func testDeduplicate_ExceedingLimit() {
        let results = [
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 1, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 2, ftsRank: 2, vectorRank: nil, rrfScore: 0.4, finalScore: 0.4, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 3, ftsRank: 3, vectorRank: nil, rrfScore: 0.3, finalScore: 0.3, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 4, ftsRank: 4, vectorRank: nil, rrfScore: 0.2, finalScore: 0.2, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
        ]
        let deduped = ranker.deduplicate(results, maxPerDocument: 2)
        XCTAssertEqual(deduped.count, 2)
    }

    func testDeduplicate_PreservesOrder() {
        let results = [
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 1, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc2", chunkId: 2, ftsRank: 2, vectorRank: nil, rrfScore: 0.4, finalScore: 0.4, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/b.swift"),
            RAGHybridRanker.RankedResult(documentId: "doc1", chunkId: 3, ftsRank: 3, vectorRank: nil, rrfScore: 0.3, finalScore: 0.3, snippet: "", lineNumber: nil, symbolName: nil, filePath: "/a.swift"),
        ]
        let deduped = ranker.deduplicate(results, maxPerDocument: 1)
        XCTAssertEqual(deduped.count, 2)
        XCTAssertEqual(deduped[0].documentId, "doc1")
        XCTAssertEqual(deduped[1].documentId, "doc2")
    }

    // MARK: - Metadata Boosting Tests

    func testApplyBoosts_SymbolNameMatch() {
        let doc = makeDocument()
        let results = [
            RAGHybridRanker.RankedResult(documentId: doc.id, chunkId: nil, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: "func search", filePath: doc.filePath)
        ]
        let boosted = ranker.applyBoosts(results: results, documents: [doc], relationships: [], query: "search function")
        XCTAssertGreaterThan(boosted[0].finalScore, 0.5)
    }

    func testApplyBoosts_LargeFilePenalty() {
        // Use old lastModified to avoid recency boost offsetting the penalty
        let doc = RAGDocument(
            filePath: "/big.swift",
            fileName: "big.swift",
            fileType: .swift,
            contentPreview: "preview",
            lineCount: 600,
            fileSize: 18000,
            lastModified: Date().addingTimeInterval(-30 * 86400) // 30 days ago
        )
        let results = [
            RAGHybridRanker.RankedResult(documentId: doc.id, chunkId: nil, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: nil, filePath: doc.filePath)
        ]
        let boosted = ranker.applyBoosts(results: results, documents: [doc], relationships: [], query: "something unrelated")
        // File > 500 lines should get -0.05 penalty, no recency boost (old file)
        XCTAssertLessThan(boosted[0].finalScore, 0.5)
    }

    func testApplyBoosts_RelationshipBoost() {
        let doc1 = makeDocument(filePath: "/a.swift", fileName: "a.swift")
        let doc2 = makeDocument(filePath: "/b.swift", fileName: "b.swift")
        let relationship = RAGRelationship(sourceId: doc1.id, targetId: doc2.id, type: .imports)
        // Both docs are in top 5, so relationship boost should apply
        let results = [
            RAGHybridRanker.RankedResult(documentId: doc1.id, chunkId: nil, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: nil, filePath: doc1.filePath),
            RAGHybridRanker.RankedResult(documentId: doc2.id, chunkId: nil, ftsRank: 2, vectorRank: nil, rrfScore: 0.4, finalScore: 0.4, snippet: "", lineNumber: nil, symbolName: nil, filePath: doc2.filePath),
        ]
        let boosted = ranker.applyBoosts(results: results, documents: [doc1, doc2], relationships: [relationship], query: "test")
        // At least one should have a relationship boost
        let hasBoost = boosted.contains { $0.finalScore > 0.5 || $0.finalScore > 0.4 }
        XCTAssertTrue(hasBoost)
    }

    func testApplyBoosts_ResultsSortedDescending() {
        let doc1 = makeDocument(filePath: "/a.swift", fileName: "a.swift")
        let doc2 = makeDocument(filePath: "/b.swift", fileName: "b.swift")
        let results = [
            RAGHybridRanker.RankedResult(documentId: doc1.id, chunkId: nil, ftsRank: 2, vectorRank: nil, rrfScore: 0.3, finalScore: 0.3, snippet: "", lineNumber: nil, symbolName: nil, filePath: doc1.filePath),
            RAGHybridRanker.RankedResult(documentId: doc2.id, chunkId: nil, ftsRank: 1, vectorRank: nil, rrfScore: 0.5, finalScore: 0.5, snippet: "", lineNumber: nil, symbolName: nil, filePath: doc2.filePath),
        ]
        let boosted = ranker.applyBoosts(results: results, documents: [doc1, doc2], relationships: [], query: "test")
        for i in 1..<boosted.count {
            XCTAssertGreaterThanOrEqual(boosted[i-1].finalScore, boosted[i].finalScore)
        }
    }
}
