import Foundation
import SQLite3

// MARK: - H1: RAG Database Manager (SQLite + FTS5)

@MainActor
class RAGDatabaseManager {
    private var db: OpaquePointer?
    private let dbDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dbDirectory = appSupport.appendingPathComponent("AgentCommand/RAG")
    }

    // MARK: - Database Lifecycle

    func openDatabase() {
        do {
            try FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        } catch {
            print("[RAGDatabase] Failed to create directory: \(error)")
            return
        }

        let dbPath = dbDirectory.appendingPathComponent("knowledge.db").path
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[RAGDatabase] Failed to open database")
            return
        }

        createTables()
    }

    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createTables() {
        let createDocuments = """
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                file_path TEXT NOT NULL UNIQUE,
                file_name TEXT NOT NULL,
                file_type TEXT NOT NULL,
                content_preview TEXT,
                line_count INTEGER DEFAULT 0,
                file_size INTEGER DEFAULT 0,
                last_modified REAL,
                indexed_at REAL
            );
        """

        let createFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
                file_path,
                file_name,
                content,
                file_type,
                content='',
                tokenize='unicode61'
            );
        """

        let createRelationships = """
            CREATE TABLE IF NOT EXISTS relationships (
                source_id TEXT NOT NULL,
                target_id TEXT NOT NULL,
                type TEXT NOT NULL,
                PRIMARY KEY (source_id, target_id, type)
            );
        """

        let createChunks = """
            CREATE TABLE IF NOT EXISTS chunks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                chunk_type TEXT NOT NULL,
                content TEXT NOT NULL,
                start_line INTEGER NOT NULL,
                end_line INTEGER NOT NULL,
                symbol_name TEXT,
                created_at REAL NOT NULL,
                UNIQUE(document_id, chunk_index)
            );
        """

        let createChunksIndex1 = "CREATE INDEX IF NOT EXISTS idx_chunks_document ON chunks(document_id);"
        let createChunksIndex2 = "CREATE INDEX IF NOT EXISTS idx_chunks_symbol ON chunks(symbol_name);"

        let createEmbeddings = """
            CREATE TABLE IF NOT EXISTS embeddings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chunk_id INTEGER NOT NULL,
                document_id TEXT NOT NULL,
                vector BLOB NOT NULL,
                dimension INTEGER NOT NULL DEFAULT 512,
                model_version TEXT NOT NULL DEFAULT 'nlembedding_v1',
                created_at REAL NOT NULL,
                UNIQUE(chunk_id)
            );
        """

        let createEmbeddingsIndex = "CREATE INDEX IF NOT EXISTS idx_embeddings_document ON embeddings(document_id);"

        execute(createDocuments)
        execute(createFTS)
        execute(createRelationships)
        execute(createChunks)
        execute(createChunksIndex1)
        execute(createChunksIndex2)
        execute(createEmbeddings)
        execute(createEmbeddingsIndex)
    }

    // MARK: - Document CRUD

    func insertDocument(_ doc: RAGDocument, content: String) {
        let insertDoc = """
            INSERT OR REPLACE INTO documents (id, file_path, file_name, file_type, content_preview, line_count, file_size, last_modified, indexed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertDoc, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (doc.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (doc.filePath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (doc.fileName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (doc.fileType.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (doc.contentPreview as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 6, Int32(doc.lineCount))
            sqlite3_bind_int64(stmt, 7, doc.fileSize)
            sqlite3_bind_double(stmt, 8, doc.lastModified.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 9, doc.indexedAt.timeIntervalSince1970)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Delete old FTS entry then insert new one
        deleteFTSEntry(docId: doc.id)
        insertFTSEntry(doc: doc, content: content)
    }

    private func insertFTSEntry(doc: RAGDocument, content: String) {
        let insertFTS = "INSERT INTO documents_fts (rowid, file_path, file_name, content, file_type) VALUES ((SELECT rowid FROM documents WHERE id = ?), ?, ?, ?, ?);"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertFTS, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (doc.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (doc.filePath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (doc.fileName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (content as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (doc.fileType.rawValue as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func deleteFTSEntry(docId: String) {
        let sql = "DELETE FROM documents_fts WHERE rowid IN (SELECT rowid FROM documents WHERE id = ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (docId as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func deleteDocument(id: String) {
        deleteFTSEntry(docId: id)
        execute("DELETE FROM documents WHERE id = '\(id)';")
        execute("DELETE FROM relationships WHERE source_id = '\(id)' OR target_id = '\(id)';")
    }

    func clearAll() {
        execute("DELETE FROM documents_fts;")
        execute("DELETE FROM documents;")
        execute("DELETE FROM relationships;")
        execute("DELETE FROM embeddings;")
        execute("DELETE FROM chunks;")
    }

    // MARK: - Search

    func search(query: String, limit: Int = 20) -> [RAGSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        // Escape the query for FTS5
        let escapedQuery = query
            .replacingOccurrences(of: "\"", with: "\"\"")
            .split(separator: " ")
            .map { "\"\($0)\"" }
            .joined(separator: " OR ")

        let sql = """
            SELECT d.id, d.file_path, d.file_name, d.file_type, d.content_preview,
                   d.line_count, d.file_size, d.last_modified, d.indexed_at,
                   snippet(documents_fts, 2, '>>>', '<<<', '...', 40) as matched_snippet,
                   bm25(documents_fts) as score
            FROM documents_fts
            JOIN documents d ON documents_fts.rowid = d.rowid
            WHERE documents_fts MATCH ?
            ORDER BY score
            LIMIT ?;
        """

        var results: [RAGSearchResult] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (escapedQuery as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                let _ = String(cString: sqlite3_column_text(stmt, 0)) // document id
                let filePath = String(cString: sqlite3_column_text(stmt, 1))
                let fileName = String(cString: sqlite3_column_text(stmt, 2))
                let fileTypeRaw = String(cString: sqlite3_column_text(stmt, 3))
                let contentPreview = String(cString: sqlite3_column_text(stmt, 4))
                let lineCount = Int(sqlite3_column_int(stmt, 5))
                let fileSize = sqlite3_column_int64(stmt, 6)
                let lastModified = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
                let _ = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8)) // indexedAt

                let matchedSnippet: String
                if let snippetPtr = sqlite3_column_text(stmt, 9) {
                    matchedSnippet = String(cString: snippetPtr)
                } else {
                    matchedSnippet = contentPreview
                }
                let score = Float(sqlite3_column_double(stmt, 10))

                var doc = RAGDocument(
                    filePath: filePath,
                    fileName: fileName,
                    fileType: RAGFileType(rawValue: fileTypeRaw) ?? .other,
                    contentPreview: contentPreview,
                    lineCount: lineCount,
                    fileSize: fileSize,
                    lastModified: lastModified
                )
                // Override generated id with stored id
                let mirror = doc
                doc = RAGDocument(
                    filePath: mirror.filePath,
                    fileName: mirror.fileName,
                    fileType: mirror.fileType,
                    contentPreview: mirror.contentPreview,
                    lineCount: mirror.lineCount,
                    fileSize: mirror.fileSize,
                    lastModified: mirror.lastModified
                )

                let result = RAGSearchResult(
                    document: doc,
                    matchedSnippet: matchedSnippet,
                    score: abs(score)
                )
                results.append(result)
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Fetch All Documents

    func fetchAllDocuments() -> [RAGDocument] {
        let sql = "SELECT id, file_path, file_name, file_type, content_preview, line_count, file_size, last_modified, indexed_at FROM documents ORDER BY file_name;"

        var documents: [RAGDocument] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let filePath = String(cString: sqlite3_column_text(stmt, 1))
                let fileName = String(cString: sqlite3_column_text(stmt, 2))
                let fileTypeRaw = String(cString: sqlite3_column_text(stmt, 3))
                let contentPreview = String(cString: sqlite3_column_text(stmt, 4))
                let lineCount = Int(sqlite3_column_int(stmt, 5))
                let fileSize = sqlite3_column_int64(stmt, 6)
                let lastModified = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))

                let doc = RAGDocument(
                    filePath: filePath,
                    fileName: fileName,
                    fileType: RAGFileType(rawValue: fileTypeRaw) ?? .other,
                    contentPreview: contentPreview,
                    lineCount: lineCount,
                    fileSize: fileSize,
                    lastModified: lastModified
                )
                documents.append(doc)
            }
        }
        sqlite3_finalize(stmt)
        return documents
    }

    // MARK: - Statistics

    func getStats() -> RAGIndexStats {
        var stats = RAGIndexStats.empty

        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*), COALESCE(SUM(line_count), 0), COALESCE(SUM(file_size), 0), MAX(indexed_at) FROM documents;"

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                stats.totalDocuments = Int(sqlite3_column_int(stmt, 0))
                stats.totalLines = Int(sqlite3_column_int(stmt, 1))
                stats.totalSizeBytes = sqlite3_column_int64(stmt, 2)
                let lastIndexed = sqlite3_column_double(stmt, 3)
                if lastIndexed > 0 {
                    stats.lastIndexedAt = Date(timeIntervalSince1970: lastIndexed)
                }
            }
        }
        sqlite3_finalize(stmt)
        return stats
    }

    // MARK: - Relationships

    func insertRelationship(_ rel: RAGRelationship) {
        let sql = "INSERT OR IGNORE INTO relationships (source_id, target_id, type) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (rel.sourceId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (rel.targetId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (rel.type.rawValue as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func fetchRelationships() -> [RAGRelationship] {
        let sql = "SELECT source_id, target_id, type FROM relationships;"
        var results: [RAGRelationship] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let sourceId = String(cString: sqlite3_column_text(stmt, 0))
                let targetId = String(cString: sqlite3_column_text(stmt, 1))
                let typeRaw = String(cString: sqlite3_column_text(stmt, 2))
                if let type = RAGRelationship.RelationType(rawValue: typeRaw) {
                    results.append(RAGRelationship(sourceId: sourceId, targetId: targetId, type: type))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Check if document needs re-indexing

    func needsReindex(filePath: String, lastModified: Date) -> Bool {
        let sql = "SELECT last_modified FROM documents WHERE file_path = ?;"
        var stmt: OpaquePointer?
        var needs = true

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (filePath as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let storedModified = sqlite3_column_double(stmt, 0)
                needs = lastModified.timeIntervalSince1970 > storedModified
            }
        }
        sqlite3_finalize(stmt)
        return needs
    }

    // MARK: - Chunks CRUD

    func insertChunks(_ chunks: [ChunkRecord], documentId: String) {
        // Delete existing chunks for this document first
        deleteChunks(documentId: documentId)

        let sql = """
            INSERT INTO chunks (document_id, chunk_index, chunk_type, content, start_line, end_line, symbol_name, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        for chunk in chunks {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (documentId as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, Int32(chunk.chunkIndex))
                sqlite3_bind_text(stmt, 3, (chunk.chunkType as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (chunk.content as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, Int32(chunk.startLine))
                sqlite3_bind_int(stmt, 6, Int32(chunk.endLine))
                if let symbolName = chunk.symbolName {
                    sqlite3_bind_text(stmt, 7, (symbolName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                sqlite3_bind_double(stmt, 8, Date().timeIntervalSince1970)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func fetchChunks(documentId: String) -> [ChunkRecord] {
        let sql = "SELECT id, document_id, chunk_index, chunk_type, content, start_line, end_line, symbol_name FROM chunks WHERE document_id = ? ORDER BY chunk_index;"
        var results: [ChunkRecord] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (documentId as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let docId = String(cString: sqlite3_column_text(stmt, 1))
                let chunkIndex = Int(sqlite3_column_int(stmt, 2))
                let chunkType = String(cString: sqlite3_column_text(stmt, 3))
                let content = String(cString: sqlite3_column_text(stmt, 4))
                let startLine = Int(sqlite3_column_int(stmt, 5))
                let endLine = Int(sqlite3_column_int(stmt, 6))
                let symbolName: String? = sqlite3_column_type(stmt, 7) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 7)) : nil

                results.append(ChunkRecord(
                    id: id, documentId: docId, chunkIndex: chunkIndex,
                    chunkType: chunkType, content: content,
                    startLine: startLine, endLine: endLine, symbolName: symbolName
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func deleteChunks(documentId: String) {
        // Cascading: delete embeddings first, then chunks
        deleteEmbeddings(documentId: documentId)
        let sql = "DELETE FROM chunks WHERE document_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (documentId as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// Get the last inserted chunk ID
    func lastInsertedChunkId() -> Int {
        return Int(sqlite3_last_insert_rowid(db))
    }

    /// Fetch chunk IDs for a document (for linking with embeddings)
    func fetchChunkIds(documentId: String) -> [Int] {
        let sql = "SELECT id FROM chunks WHERE document_id = ? ORDER BY chunk_index;"
        var ids: [Int] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (documentId as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                ids.append(Int(sqlite3_column_int(stmt, 0)))
            }
        }
        sqlite3_finalize(stmt)
        return ids
    }

    // MARK: - Embeddings CRUD

    func insertEmbedding(chunkId: Int, documentId: String, vector: [Float], dimension: Int = 512) {
        let sql = """
            INSERT OR REPLACE INTO embeddings (chunk_id, document_id, vector, dimension, model_version, created_at)
            VALUES (?, ?, ?, ?, 'nlembedding_v1', ?);
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(chunkId))
            sqlite3_bind_text(stmt, 2, (documentId as NSString).utf8String, -1, nil)
            let blob = vector.asBlob
            _ = blob.withUnsafeBytes { rawBuffer in
                sqlite3_bind_blob(stmt, 3, rawBuffer.baseAddress, Int32(blob.count), nil)
            }
            sqlite3_bind_int(stmt, 4, Int32(dimension))
            sqlite3_bind_double(stmt, 5, Date().timeIntervalSince1970)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func fetchAllEmbeddings() -> [(chunkId: Int, documentId: String, vector: [Float])] {
        let sql = "SELECT chunk_id, document_id, vector FROM embeddings;"
        var results: [(chunkId: Int, documentId: String, vector: [Float])] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let chunkId = Int(sqlite3_column_int(stmt, 0))
                let documentId = String(cString: sqlite3_column_text(stmt, 1))
                let blobSize = sqlite3_column_bytes(stmt, 2)
                if let blobPtr = sqlite3_column_blob(stmt, 2), blobSize > 0 {
                    let data = Data(bytes: blobPtr, count: Int(blobSize))
                    let vector = [Float].fromBlob(data)
                    results.append((chunkId: chunkId, documentId: documentId, vector: vector))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func fetchEmbeddings(documentId: String) -> [(chunkId: Int, vector: [Float])] {
        let sql = "SELECT chunk_id, vector FROM embeddings WHERE document_id = ?;"
        var results: [(chunkId: Int, vector: [Float])] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (documentId as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let chunkId = Int(sqlite3_column_int(stmt, 0))
                let blobSize = sqlite3_column_bytes(stmt, 1)
                if let blobPtr = sqlite3_column_blob(stmt, 1), blobSize > 0 {
                    let data = Data(bytes: blobPtr, count: Int(blobSize))
                    let vector = [Float].fromBlob(data)
                    results.append((chunkId: chunkId, vector: vector))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func deleteEmbeddings(documentId: String) {
        let sql = "DELETE FROM embeddings WHERE document_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (documentId as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getEmbeddingCount() -> Int {
        let sql = "SELECT COUNT(*) FROM embeddings;"
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // MARK: - Extended Stats

    func getExtendedStats() -> RAGExtendedStats {
        let base = getStats()
        let totalChunks: Int
        let totalEmbeddings: Int
        var vectorSizeBytes: Int64 = 0

        // Count chunks
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM chunks;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        totalChunks = count

        totalEmbeddings = getEmbeddingCount()

        // Estimate vector storage size
        if sqlite3_prepare_v2(db, "SELECT COALESCE(SUM(LENGTH(vector)), 0) FROM embeddings;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                vectorSizeBytes = sqlite3_column_int64(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)

        return RAGExtendedStats(
            base: base,
            totalChunks: totalChunks,
            totalEmbeddings: totalEmbeddings,
            embeddingDimension: 512,
            vectorStoreSizeBytes: vectorSizeBytes
        )
    }

    /// Fetch a single chunk by its ID
    func fetchChunk(id: Int) -> ChunkRecord? {
        let sql = "SELECT id, document_id, chunk_index, chunk_type, content, start_line, end_line, symbol_name FROM chunks WHERE id = ?;"
        var stmt: OpaquePointer?
        var result: ChunkRecord?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let cid = Int(sqlite3_column_int(stmt, 0))
                let docId = String(cString: sqlite3_column_text(stmt, 1))
                let chunkIndex = Int(sqlite3_column_int(stmt, 2))
                let chunkType = String(cString: sqlite3_column_text(stmt, 3))
                let content = String(cString: sqlite3_column_text(stmt, 4))
                let startLine = Int(sqlite3_column_int(stmt, 5))
                let endLine = Int(sqlite3_column_int(stmt, 6))
                let symbolName: String? = sqlite3_column_type(stmt, 7) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 7)) : nil

                result = ChunkRecord(
                    id: cid, documentId: docId, chunkIndex: chunkIndex,
                    chunkType: chunkType, content: content,
                    startLine: startLine, endLine: endLine, symbolName: symbolName
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Helpers

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("[RAGDatabase] SQL error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    /// Database file size on disk
    var databaseSizeBytes: Int64 {
        let dbPath = dbDirectory.appendingPathComponent("knowledge.db")
        let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path)
        return (attrs?[.size] as? Int64) ?? 0
    }
}
