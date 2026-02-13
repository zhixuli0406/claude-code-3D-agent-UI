import Foundation

// MARK: - RAG Search Engine (Core Hybrid Search)

/// Central search engine coordinating keyword (FTS5) + vector (semantic) search,
/// with hybrid ranking via Reciprocal Rank Fusion (RRF).
@MainActor
class RAGSearchEngine {

    private let dbManager: RAGDatabaseManager
    private let embedder: RAGEmbeddingService
    private let chunker: RAGContentChunker
    private let ranker: RAGHybridRanker

    var searchConfig = RAGSearchConfig()

    // MARK: - Embedding Cache (LRU)

    private var embeddingCache: [(chunkId: Int, documentId: String, vector: [Float])] = []
    private var cacheLoaded = false

    init(dbManager: RAGDatabaseManager) {
        self.dbManager = dbManager
        self.embedder = RAGEmbeddingService()
        self.chunker = RAGContentChunker()
        self.ranker = RAGHybridRanker()
    }

    // MARK: - Primary Hybrid Search

    /// Hybrid search combining FTS5 keyword + vector similarity
    func search(query: String, limit: Int = 20, filters: RAGSearchFilters? = nil) -> [RAGSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        // Run keyword search
        let ftsResults = keywordSearch(query: query, limit: limit)

        // Run vector search
        let vectorResults = vectorSearch(query: query, topK: limit)

        // Fuse results via RRF
        var ranked = ranker.fuse(
            ftsResults: ftsResults,
            vectorResults: vectorResults,
            k: searchConfig.rrfK
        )

        // Apply metadata boosting
        if searchConfig.metadataBoostEnabled {
            let documents = dbManager.fetchAllDocuments()
            let relationships = dbManager.fetchRelationships()
            ranked = ranker.applyBoosts(
                results: ranked,
                documents: documents,
                relationships: relationships,
                query: query
            )
        }

        // Deduplicate
        ranked = ranker.deduplicate(ranked, maxPerDocument: 3)

        // Filter by minimum score
        ranked = ranked.filter { $0.finalScore >= searchConfig.minScore }

        // Apply optional filters
        if let filters = filters {
            ranked = applyFilters(ranked, filters: filters)
        }

        // Convert to RAGSearchResult and limit
        return ranked.prefix(limit).map { result in
            let doc = dbManager.fetchAllDocuments().first { $0.id == result.documentId }
            ?? RAGDocument(filePath: result.filePath, fileName: URL(fileURLWithPath: result.filePath).lastPathComponent, fileType: .other, contentPreview: "", lineCount: 0, fileSize: 0, lastModified: Date())

            return RAGSearchResult(
                document: doc,
                matchedSnippet: result.snippet,
                score: result.finalScore,
                lineNumber: result.lineNumber
            )
        }
    }

    // MARK: - Semantic-Only Search

    /// Semantic search using vector similarity only
    func semanticSearch(query: String, topK: Int = 10) -> [RAGSearchResult] {
        let vectorResults = vectorSearch(query: query, topK: topK)

        return vectorResults.map { result in
            let doc = dbManager.fetchAllDocuments().first { $0.id == result.documentId }
            ?? RAGDocument(filePath: result.filePath, fileName: URL(fileURLWithPath: result.filePath).lastPathComponent, fileType: .other, contentPreview: "", lineCount: 0, fileSize: 0, lastModified: Date())

            return RAGSearchResult(
                document: doc,
                matchedSnippet: result.snippet,
                score: result.score,
                lineNumber: result.startLine
            )
        }
    }

    // MARK: - Keyword-Only Search

    /// Keyword search using existing FTS5 index
    func keywordSearch(query: String, limit: Int = 20) -> [RAGSearchResult] {
        return dbManager.search(query: query, limit: limit)
    }

    // MARK: - Vector Search (Internal)

    private func vectorSearch(
        query: String,
        topK: Int
    ) -> [(chunkId: Int, documentId: String, score: Float, snippet: String, startLine: Int, symbolName: String?, filePath: String)] {
        // Generate query embedding
        guard let queryVector = embedder.embedQuery(query: query) else { return [] }

        // Load embeddings (cached)
        loadEmbeddingCacheIfNeeded()

        guard !embeddingCache.isEmpty else { return [] }

        // Compute cosine similarity against all stored vectors
        let similarities = RAGEmbeddingService.batchCosineSimilarity(
            query: queryVector,
            candidates: embeddingCache.map(\.vector)
        )

        // Build scored results
        var scored: [(index: Int, score: Float)] = []
        for (i, sim) in similarities.enumerated() {
            if sim > 0.1 { // threshold to reduce noise
                scored.append((index: i, score: sim))
            }
        }

        // Sort by score descending
        scored.sort { $0.score > $1.score }

        // Take top-K and resolve chunk metadata
        return scored.prefix(topK).compactMap { item in
            let entry = embeddingCache[item.index]
            guard let chunk = dbManager.fetchChunk(id: entry.chunkId) else { return nil }
            let doc = dbManager.fetchAllDocuments().first { $0.id == entry.documentId }
            let filePath = doc?.filePath ?? ""

            // Build snippet: first few lines of chunk content
            let snippetLines = chunk.content.components(separatedBy: "\n").prefix(5)
            let snippet = snippetLines.joined(separator: "\n")

            return (
                chunkId: entry.chunkId,
                documentId: entry.documentId,
                score: item.score,
                snippet: snippet,
                startLine: chunk.startLine,
                symbolName: chunk.symbolName,
                filePath: filePath
            )
        }
    }

    // MARK: - Indexing

    /// Index a single document: chunk → embed → store
    func indexDocument(_ url: URL, baseDirectory: URL) async {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        let ext = url.pathExtension.lowercased()
        let fileType = RAGFileType.from(extension: ext)
        let filePath = url.path

        // Compute document ID same way as RAGDocument
        let docId = filePath.data(using: .utf8).map { data in
            var hash = 0
            for byte in data { hash = hash &* 31 &+ Int(byte) }
            return String(format: "%08x", abs(hash))
        } ?? UUID().uuidString

        // Chunk the content
        let chunks = chunker.chunk(content: content, fileType: fileType)

        // Convert to ChunkRecords and insert
        let chunkRecords = chunks.enumerated().map { index, chunk in
            ChunkRecord(
                id: nil,
                documentId: docId,
                chunkIndex: index,
                chunkType: chunk.type.rawValue,
                content: chunk.content,
                startLine: chunk.startLine,
                endLine: chunk.endLine,
                symbolName: chunk.symbolName
            )
        }

        await MainActor.run {
            dbManager.insertChunks(chunkRecords, documentId: docId)
        }

        // Fetch stored chunk IDs
        let storedChunkIds = await MainActor.run {
            dbManager.fetchChunkIds(documentId: docId)
        }

        // Generate and store embeddings
        let texts = chunks.map(\.content)
        let embeddings = embedder.embedBatch(texts: texts)

        await MainActor.run {
            for (i, vector) in embeddings.enumerated() {
                guard let vec = vector, i < storedChunkIds.count else { continue }
                dbManager.insertEmbedding(
                    chunkId: storedChunkIds[i],
                    documentId: docId,
                    vector: vec,
                    dimension: embedder.dimension
                )
            }
        }

        // Invalidate cache
        cacheLoaded = false
    }

    /// Batch index multiple documents with progress callback
    func indexDocuments(_ urls: [URL], baseDirectory: URL, progress: @escaping (Double) -> Void) async {
        let total = urls.count
        for (index, url) in urls.enumerated() {
            await indexDocument(url, baseDirectory: baseDirectory)
            let p = Double(index + 1) / Double(max(total, 1))
            await MainActor.run { progress(p) }
        }
    }

    /// Remove a document and its chunks/embeddings
    func removeDocument(id: String) {
        dbManager.deleteChunks(documentId: id)
        cacheLoaded = false
    }

    // MARK: - Context for LLM Prompt

    /// Build context string from hybrid search results for prompt augmentation
    func getContextForPrompt(query: String, maxTokens: Int = 2000) -> String {
        let results = search(query: query, limit: 5)
        guard !results.isEmpty else { return "" }

        var context = "--- Relevant context from project files ---\n"
        var currentLength = context.count

        for result in results {
            let entry = "\n// File: \(result.document.filePath)"
                + (result.lineNumber.map { " (line \($0))" } ?? "")
                + "\n"
                + result.matchedSnippet
                    .replacingOccurrences(of: ">>>", with: "")
                    .replacingOccurrences(of: "<<<", with: "")
                + "\n"

            // Approximate token count (1 token ≈ 4 chars)
            if currentLength + entry.count > maxTokens * 4 { break }
            context += entry
            currentLength += entry.count
        }

        context += "--- End of context ---\n"
        return context
    }

    // MARK: - Cache Management

    private func loadEmbeddingCacheIfNeeded() {
        guard !cacheLoaded else { return }
        embeddingCache = dbManager.fetchAllEmbeddings()
        cacheLoaded = true
    }

    /// Force reload embedding cache (call after re-indexing)
    func invalidateCache() {
        cacheLoaded = false
        embeddingCache = []
    }

    // MARK: - Filter Application

    private func applyFilters(_ results: [RAGHybridRanker.RankedResult], filters: RAGSearchFilters) -> [RAGHybridRanker.RankedResult] {
        let docs = dbManager.fetchAllDocuments()
        let docLookup = Dictionary(uniqueKeysWithValues: docs.map { ($0.id, $0) })

        return results.filter { result in
            guard let doc = docLookup[result.documentId] else { return true }

            if let fileTypes = filters.fileTypes, !fileTypes.contains(doc.fileType) {
                return false
            }
            if let pathPrefix = filters.pathPrefix, !doc.filePath.hasPrefix(pathPrefix) {
                return false
            }
            if let after = filters.modifiedAfter, doc.lastModified < after {
                return false
            }
            if let before = filters.modifiedBefore, doc.lastModified > before {
                return false
            }
            if let excludePaths = filters.excludePaths {
                for excluded in excludePaths {
                    if doc.filePath.contains(excluded) { return false }
                }
            }
            return true
        }
    }
}
