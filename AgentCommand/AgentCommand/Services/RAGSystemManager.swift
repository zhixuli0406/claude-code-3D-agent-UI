import Foundation
import Combine

// MARK: - H1: RAG System Manager

@MainActor
class RAGSystemManager: ObservableObject {

    // MARK: - Published State

    @Published var indexStats: RAGIndexStats = .empty
    @Published var isIndexing: Bool = false
    @Published var indexProgress: Double = 0
    @Published var searchResults: [RAGSearchResult] = []
    @Published var searchQuery: String = ""
    @Published var documents: [RAGDocument] = []
    @Published var relationships: [RAGRelationship] = []
    @Published var isAutoIndexEnabled: Bool = true
    @Published var searchMode: RAGSearchMode = .hybrid
    @Published var searchFilters: RAGSearchFilters?
    @Published var extendedStats: RAGExtendedStats?

    let dbManager = RAGDatabaseManager()
    private(set) var searchEngine: RAGSearchEngine!

    /// Directories to exclude from indexing
    private let excludedDirs: Set<String> = [
        ".git", "node_modules", ".build", "build", "DerivedData",
        ".swiftpm", "Pods", ".cocoapods", "vendor", "dist",
        "__pycache__", ".venv", "venv", ".env", ".idea",
        ".vs", ".vscode", "xcuserdata", ".DS_Store"
    ]

    /// Max file size to index (1 MB)
    private let maxFileSize: Int64 = 1_048_576

    /// Supported file extensions
    private var supportedExtensions: Set<String> {
        Set(RAGFileType.allCases.flatMap(\.extensions))
    }

    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var watchedDirectoryFD: Int32 = -1
    private var currentDirectory: URL?

    // MARK: - Initialization

    func initialize() {
        dbManager.openDatabase()
        searchEngine = RAGSearchEngine(dbManager: dbManager)
        refreshFromDatabase()
    }

    func shutdown() {
        stopWatching()
        dbManager.closeDatabase()
    }

    // MARK: - Indexing

    func indexDirectory(_ url: URL) {
        guard !isIndexing else { return }

        currentDirectory = url
        isIndexing = true
        indexProgress = 0

        let startTime = Date()

        Task.detached { [weak self] in
            guard let self = self else { return }

            // Collect all eligible files
            let files = await self.collectFiles(in: url)
            let total = files.count

            for (index, fileURL) in files.enumerated() {
                // Phase 1: Standard document indexing (FTS5)
                await self.indexFile(fileURL, baseDirectory: url)

                // Phase 2: Chunk + embed for vector search
                await self.searchEngine.indexDocument(fileURL, baseDirectory: url)

                await MainActor.run {
                    self.indexProgress = Double(index + 1) / Double(max(total, 1))
                }
            }

            // Analyze relationships after indexing
            await self.analyzeRelationships(baseDirectory: url)

            let duration = Int(Date().timeIntervalSince(startTime) * 1000)

            await MainActor.run {
                self.isIndexing = false
                self.indexProgress = 1.0
                self.indexStats.indexDurationMs = duration
                self.searchEngine.invalidateCache()
                self.refreshFromDatabase()
            }
        }
    }

    func reindexFile(_ url: URL) {
        guard let baseDir = currentDirectory else { return }
        Task.detached { [weak self] in
            await self?.indexFile(url, baseDirectory: baseDir)
            await MainActor.run { [weak self] in
                self?.refreshFromDatabase()
            }
        }
    }

    func clearIndex() {
        dbManager.clearAll()
        searchEngine.invalidateCache()
        refreshFromDatabase()
    }

    // MARK: - Search

    func search(query: String) {
        searchQuery = query
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        switch searchMode {
        case .hybrid:
            searchResults = searchEngine.search(query: query, filters: searchFilters)
        case .keyword:
            searchResults = searchEngine.keywordSearch(query: query)
        case .semantic:
            searchResults = searchEngine.semanticSearch(query: query)
        }
    }

    /// Get context snippets for prompt augmentation (uses hybrid search)
    func getContextForPrompt(query: String, maxSnippets: Int = 5) -> String {
        return searchEngine.getContextForPrompt(query: query, maxTokens: 2000)
    }

    // MARK: - File Watching (Incremental Indexing)

    func startWatching(directory: URL) {
        stopWatching()

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else {
            print("[RAGSystem] Failed to open directory for watching: \(directory.path)")
            return
        }

        watchedDirectoryFD = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self, self.isAutoIndexEnabled, let dir = self.currentDirectory else { return }
            // Debounce: re-index after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.indexDirectory(dir)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatcherSource = source
    }

    func stopWatching() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
        watchedDirectoryFD = -1
    }

    // MARK: - Relationship Analysis

    private func analyzeRelationships(baseDirectory: URL) async {
        let docs = await MainActor.run { self.documents }
        var newRelationships: [RAGRelationship] = []

        for doc in docs {
            let fileURL = URL(fileURLWithPath: doc.filePath)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let imports = extractImports(from: content, fileType: doc.fileType)
            for importName in imports {
                // Find matching document
                if let target = docs.first(where: { $0.fileName.hasPrefix(importName) || $0.filePath.contains(importName) }) {
                    let rel = RAGRelationship(sourceId: doc.id, targetId: target.id, type: .imports)
                    newRelationships.append(rel)
                }
            }
        }

        await MainActor.run {
            for rel in newRelationships {
                self.dbManager.insertRelationship(rel)
            }
            self.relationships = self.dbManager.fetchRelationships()
        }
    }

    private func extractImports(from content: String, fileType: RAGFileType) -> [String] {
        var imports: [String] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines.prefix(100) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            switch fileType {
            case .swift:
                if trimmed.hasPrefix("import ") {
                    let name = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { imports.append(name) }
                }
            case .python:
                if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") {
                    let parts = trimmed.split(separator: " ")
                    if parts.count >= 2 {
                        imports.append(String(parts[1]))
                    }
                }
            case .javascript, .typescript:
                if trimmed.contains("import ") || trimmed.contains("require(") {
                    // Extract from 'path' or "path"
                    if let range = trimmed.range(of: #"['"]([^'"]+)['"]"#, options: .regularExpression) {
                        let path = String(trimmed[range]).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                        imports.append(path)
                    }
                }
            default:
                break
            }
        }

        return imports
    }

    // MARK: - Private Helpers

    private func collectFiles(in directory: URL) async -> [URL] {
        let excludedDirs = self.excludedDirs
        let maxFileSize = self.maxFileSize
        let supportedExtensions = self.supportedExtensions
        return await Task.detached {
            var files: [URL] = []
            let fm = FileManager.default

            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return files }

            while let obj = enumerator.nextObject() {
                guard let fileURL = obj as? URL else { continue }
                let fileName = fileURL.lastPathComponent
                let dirName = fileURL.deletingLastPathComponent().lastPathComponent

                // Skip excluded directories
                if excludedDirs.contains(dirName) || excludedDirs.contains(fileName) {
                    enumerator.skipDescendants()
                    continue
                }

                // Check if it's a regular file
                guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true else { continue }

                // Check file size
                let fileSize = Int64(values.fileSize ?? 0)
                if fileSize > maxFileSize || fileSize == 0 { continue }

                // Check extension
                let ext = fileURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    files.append(fileURL)
                }
            }

            return files
        }.value
    }

    private func indexFile(_ fileURL: URL, baseDirectory: URL) async {
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        let lastModified = values.contentModificationDate ?? Date()
        let filePath = fileURL.path

        // Check if re-indexing is needed
        let needsUpdate = await MainActor.run { self.dbManager.needsReindex(filePath: filePath, lastModified: lastModified) }
        guard needsUpdate else { return }

        // Read file content
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }

        let fileName = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()
        let fileType = RAGFileType.from(extension: ext)
        let lines = content.components(separatedBy: .newlines)
        let lineCount = lines.count
        let fileSize = Int64(values.fileSize ?? 0)
        let preview = String(content.prefix(500))

        let doc = RAGDocument(
            filePath: filePath,
            fileName: fileName,
            fileType: fileType,
            contentPreview: preview,
            lineCount: lineCount,
            fileSize: fileSize,
            lastModified: lastModified
        )

        await MainActor.run {
            self.dbManager.insertDocument(doc, content: content)
        }
    }

    private func refreshFromDatabase() {
        documents = dbManager.fetchAllDocuments()
        relationships = dbManager.fetchRelationships()
        indexStats = dbManager.getStats()
        extendedStats = dbManager.getExtendedStats()
    }
}
