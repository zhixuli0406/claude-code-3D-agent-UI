import Foundation
import SQLite3

// MARK: - H2: Agent Memory Database Manager (SQLite)

@MainActor
class AgentMemoryDatabaseManager {
    private var db: OpaquePointer?
    private let dbDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dbDirectory = appSupport.appendingPathComponent("AgentCommand/Memory")
    }

    // MARK: - Database Lifecycle

    func openDatabase() {
        do {
            try FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        } catch {
            print("[MemoryDB] Failed to create directory: \(error)")
            return
        }

        let dbPath = dbDirectory.appendingPathComponent("agent_memory.db").path
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[MemoryDB] Failed to open database")
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
        let createMemories = """
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                agent_name TEXT NOT NULL,
                task_title TEXT NOT NULL,
                summary TEXT NOT NULL,
                category TEXT NOT NULL,
                relevance_score REAL DEFAULT 1.0,
                created_at REAL NOT NULL,
                last_accessed_at REAL NOT NULL,
                access_count INTEGER DEFAULT 0,
                related_files TEXT,
                tags TEXT
            );
        """

        let createFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
                agent_name,
                task_title,
                summary,
                tags,
                content='',
                tokenize='unicode61'
            );
        """

        let createShared = """
            CREATE TABLE IF NOT EXISTS shared_memories (
                id TEXT PRIMARY KEY,
                source_agent TEXT NOT NULL,
                target_agent TEXT NOT NULL,
                memory_id TEXT NOT NULL,
                shared_at REAL NOT NULL,
                FOREIGN KEY (memory_id) REFERENCES memories(id)
            );
        """

        let createIndex = """
            CREATE INDEX IF NOT EXISTS idx_memories_agent ON memories(agent_name);
        """

        execute(createMemories)
        execute(createFTS)
        execute(createShared)
        execute(createIndex)
    }

    // MARK: - Memory CRUD

    func insertMemory(_ memory: AgentMemory) {
        let sql = """
            INSERT OR REPLACE INTO memories (id, agent_name, task_title, summary, category, relevance_score, created_at, last_accessed_at, access_count, related_files, tags)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        let relatedFiles = memory.relatedFilesPaths.joined(separator: "|")
        let tags = memory.tags.joined(separator: "|")

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (memory.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (memory.agentName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (memory.taskTitle as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (memory.summary as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (memory.category.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 6, Double(memory.relevanceScore))
            sqlite3_bind_double(stmt, 7, memory.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 8, memory.lastAccessedAt.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 9, Int32(memory.accessCount))
            sqlite3_bind_text(stmt, 10, (relatedFiles as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 11, (tags as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Update FTS index
        deleteFTSEntry(memoryId: memory.id)
        insertFTSEntry(memory)
    }

    private func insertFTSEntry(_ memory: AgentMemory) {
        let sql = "INSERT INTO memories_fts (rowid, agent_name, task_title, summary, tags) VALUES ((SELECT rowid FROM memories WHERE id = ?), ?, ?, ?, ?);"
        let tags = memory.tags.joined(separator: " ")

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (memory.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (memory.agentName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (memory.taskTitle as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (memory.summary as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (tags as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func deleteFTSEntry(memoryId: String) {
        let sql = "DELETE FROM memories_fts WHERE rowid IN (SELECT rowid FROM memories WHERE id = ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (memoryId as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func deleteMemory(id: String) {
        deleteFTSEntry(memoryId: id)
        execute("DELETE FROM memories WHERE id = '\(id)';")
        execute("DELETE FROM shared_memories WHERE memory_id = '\(id)';")
    }

    func clearAll() {
        execute("DELETE FROM memories_fts;")
        execute("DELETE FROM memories;")
        execute("DELETE FROM shared_memories;")
    }

    // MARK: - Query

    func fetchMemories(forAgent agentName: String, limit: Int = 50) -> [AgentMemory] {
        let sql = "SELECT * FROM memories WHERE agent_name = ? ORDER BY last_accessed_at DESC LIMIT ?;"
        return queryMemories(sql: sql, bindings: [.text(agentName), .int(Int32(limit))])
    }

    func fetchAllMemories(limit: Int = 100) -> [AgentMemory] {
        let sql = "SELECT * FROM memories ORDER BY created_at DESC LIMIT ?;"
        return queryMemories(sql: sql, bindings: [.int(Int32(limit))])
    }

    func search(query: String, agentName: String? = nil, limit: Int = 20) -> [AgentMemory] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let escapedQuery = query
            .replacingOccurrences(of: "\"", with: "\"\"")
            .split(separator: " ")
            .map { "\"\($0)\"" }
            .joined(separator: " OR ")

        let sql: String
        if let agentName = agentName {
            sql = """
                SELECT m.* FROM memories m
                JOIN memories_fts ON memories_fts.rowid = m.rowid
                WHERE memories_fts MATCH ? AND m.agent_name = ?
                ORDER BY bm25(memories_fts)
                LIMIT ?;
            """
            return queryMemories(sql: sql, bindings: [.text(escapedQuery), .text(agentName), .int(Int32(limit))])
        } else {
            sql = """
                SELECT m.* FROM memories m
                JOIN memories_fts ON memories_fts.rowid = m.rowid
                WHERE memories_fts MATCH ?
                ORDER BY bm25(memories_fts)
                LIMIT ?;
            """
            return queryMemories(sql: sql, bindings: [.text(escapedQuery), .int(Int32(limit))])
        }
    }

    /// Recall relevant memories for context injection
    func recallRelevant(query: String, agentName: String, limit: Int = 5) -> [AgentMemory] {
        var memories = search(query: query, agentName: agentName, limit: limit)

        // Also include shared memories
        let sharedIds = fetchSharedMemoryIds(forAgent: agentName)
        if !sharedIds.isEmpty {
            let placeholders = sharedIds.map { _ in "?" }.joined(separator: ",")
            let sql = "SELECT * FROM memories WHERE id IN (\(placeholders)) LIMIT ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                for (i, id) in sharedIds.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), (id as NSString).utf8String, -1, nil)
                }
                sqlite3_bind_int(stmt, Int32(sharedIds.count + 1), Int32(limit))
                let sharedMemories = parseMemoryRows(stmt: stmt)
                memories.append(contentsOf: sharedMemories)
            }
            sqlite3_finalize(stmt)
        }

        // Update access count for recalled memories
        for memory in memories {
            touchMemory(id: memory.id)
        }

        // Sort by decayed score and deduplicate
        let seen = NSMutableSet()
        memories = memories.filter { seen.add($0.id); return seen.count == memories.filter({ seen.contains($0.id) }).count }.isEmpty ? memories : Array(Set(memories))
        return memories.sorted { $0.decayedScore > $1.decayedScore }.prefix(limit).map { $0 }
    }

    /// Increment access count and update last accessed time
    func touchMemory(id: String) {
        let sql = "UPDATE memories SET access_count = access_count + 1, last_accessed_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Shared Memories

    func shareMemory(from sourceAgent: String, to targetAgent: String, memoryId: String) {
        let shared = SharedMemory(sourceAgentName: sourceAgent, targetAgentName: targetAgent, memoryId: memoryId)
        let sql = "INSERT OR IGNORE INTO shared_memories (id, source_agent, target_agent, memory_id, shared_at) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (shared.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (shared.sourceAgentName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (shared.targetAgentName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (shared.memoryId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 5, shared.sharedAt.timeIntervalSince1970)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func fetchSharedMemoryIds(forAgent agentName: String) -> [String] {
        let sql = "SELECT memory_id FROM shared_memories WHERE target_agent = ?;"
        var ids: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (agentName as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    ids.append(String(cString: ptr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return ids
    }

    // MARK: - Statistics

    func getStats() -> MemoryStats {
        var stats = MemoryStats.empty

        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*), COUNT(DISTINCT agent_name), MIN(created_at), MAX(created_at) FROM memories;"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                stats.totalMemories = Int(sqlite3_column_int(stmt, 0))
                stats.totalAgents = Int(sqlite3_column_int(stmt, 1))
                let oldest = sqlite3_column_double(stmt, 2)
                let newest = sqlite3_column_double(stmt, 3)
                if oldest > 0 { stats.oldestMemoryDate = Date(timeIntervalSince1970: oldest) }
                if newest > 0 { stats.newestMemoryDate = Date(timeIntervalSince1970: newest) }
            }
        }
        sqlite3_finalize(stmt)

        // Category counts
        let catSql = "SELECT category, COUNT(*) FROM memories GROUP BY category;"
        if sqlite3_prepare_v2(db, catSql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let catPtr = sqlite3_column_text(stmt, 0) {
                    let cat = String(cString: catPtr)
                    let count = Int(sqlite3_column_int(stmt, 1))
                    stats.categoryCounts[cat] = count
                }
            }
        }
        sqlite3_finalize(stmt)

        stats.databaseSizeBytes = databaseSizeBytes
        return stats
    }

    /// Distinct agent names that have memories
    func agentNames() -> [String] {
        let sql = "SELECT DISTINCT agent_name FROM memories ORDER BY agent_name;"
        var names: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    names.append(String(cString: ptr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return names
    }

    // MARK: - Private Helpers

    private enum SQLBinding {
        case text(String)
        case int(Int32)
        case double(Double)
    }

    private func queryMemories(sql: String, bindings: [SQLBinding]) -> [AgentMemory] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        for (i, binding) in bindings.enumerated() {
            let idx = Int32(i + 1)
            switch binding {
            case .text(let value):
                sqlite3_bind_text(stmt, idx, (value as NSString).utf8String, -1, nil)
            case .int(let value):
                sqlite3_bind_int(stmt, idx, value)
            case .double(let value):
                sqlite3_bind_double(stmt, idx, value)
            }
        }

        let results = parseMemoryRows(stmt: stmt)
        sqlite3_finalize(stmt)
        return results
    }

    private func parseMemoryRows(stmt: OpaquePointer?) -> [AgentMemory] {
        var memories: [AgentMemory] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(stmt, 0),
                  let namePtr = sqlite3_column_text(stmt, 1),
                  let titlePtr = sqlite3_column_text(stmt, 2),
                  let summaryPtr = sqlite3_column_text(stmt, 3),
                  let catPtr = sqlite3_column_text(stmt, 4) else { continue }

            let relatedFilesStr = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? ""
            let tagsStr = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""

            let category = MemoryCategory(rawValue: String(cString: catPtr)) ?? .taskSummary

            var memory = AgentMemory(
                agentName: String(cString: namePtr),
                taskTitle: String(cString: titlePtr),
                summary: String(cString: summaryPtr),
                category: category,
                relevanceScore: Float(sqlite3_column_double(stmt, 5)),
                relatedFilesPaths: relatedFilesStr.isEmpty ? [] : relatedFilesStr.components(separatedBy: "|"),
                tags: tagsStr.isEmpty ? [] : tagsStr.components(separatedBy: "|")
            )

            // Override generated fields with stored values
            let storedId = String(cString: idPtr)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
            let lastAccessedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
            let accessCount = Int(sqlite3_column_int(stmt, 8))

            // Use reflection-free approach: create new with stored id via a wrapper
            memory = AgentMemory.restored(
                id: storedId,
                agentName: memory.agentName,
                taskTitle: memory.taskTitle,
                summary: memory.summary,
                category: memory.category,
                relevanceScore: memory.relevanceScore,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                accessCount: accessCount,
                relatedFilesPaths: memory.relatedFilesPaths,
                tags: memory.tags
            )

            memories.append(memory)
        }
        return memories
    }

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("[MemoryDB] SQL error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    var databaseSizeBytes: Int64 {
        let dbPath = dbDirectory.appendingPathComponent("agent_memory.db")
        let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path)
        return (attrs?[.size] as? Int64) ?? 0
    }
}

// MARK: - AgentMemory restoration helper

extension AgentMemory {
    /// Create a memory with all fields restored from database
    static func restored(
        id: String,
        agentName: String,
        taskTitle: String,
        summary: String,
        category: MemoryCategory,
        relevanceScore: Float,
        createdAt: Date,
        lastAccessedAt: Date,
        accessCount: Int,
        relatedFilesPaths: [String],
        tags: [String]
    ) -> AgentMemory {
        return AgentMemory(
            restoredId: id,
            agentName: agentName,
            taskTitle: taskTitle,
            summary: summary,
            category: category,
            relevanceScore: relevanceScore,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            accessCount: accessCount,
            relatedFilesPaths: relatedFilesPaths,
            tags: tags
        )
    }

    /// Internal initializer for restoring from database
    init(restoredId: String, agentName: String, taskTitle: String, summary: String, category: MemoryCategory, relevanceScore: Float, createdAt: Date, lastAccessedAt: Date, accessCount: Int, relatedFilesPaths: [String], tags: [String]) {
        self.id = restoredId
        self.agentName = agentName
        self.taskTitle = taskTitle
        self.summary = summary
        self.category = category
        self.relevanceScore = relevanceScore
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.relatedFilesPaths = relatedFilesPaths
        self.tags = tags
    }
}
