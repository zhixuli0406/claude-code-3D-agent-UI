import Foundation

// MARK: - H1: RAG (Retrieval-Augmented Generation) System Models

/// Represents an indexed file in the RAG knowledge base
struct RAGDocument: Identifiable, Codable, Hashable {
    let id: String
    var filePath: String
    var fileName: String
    var fileType: RAGFileType
    var contentPreview: String
    var lineCount: Int
    var fileSize: Int64
    var lastModified: Date
    var indexedAt: Date
    var relevanceScore: Float?

    init(filePath: String, fileName: String, fileType: RAGFileType, contentPreview: String, lineCount: Int, fileSize: Int64, lastModified: Date) {
        self.id = filePath.data(using: .utf8).map { data in
            var hash = 0
            for byte in data { hash = hash &* 31 &+ Int(byte) }
            return String(format: "%08x", abs(hash))
        } ?? UUID().uuidString
        self.filePath = filePath
        self.fileName = fileName
        self.fileType = fileType
        self.contentPreview = contentPreview
        self.lineCount = lineCount
        self.fileSize = fileSize
        self.lastModified = lastModified
        self.indexedAt = Date()
    }
}

/// Supported file types for indexing
enum RAGFileType: String, Codable, CaseIterable {
    case swift
    case python
    case javascript
    case typescript
    case markdown
    case json
    case yaml
    case html
    case css
    case text
    case other

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .html: return "HTML"
        case .css: return "CSS"
        case .text: return "Text"
        case .other: return "Other"
        }
    }

    var colorHex: String {
        switch self {
        case .swift: return "#F05138"
        case .python: return "#3776AB"
        case .javascript: return "#F7DF1E"
        case .typescript: return "#3178C6"
        case .markdown: return "#4CAF50"
        case .json: return "#FF9800"
        case .yaml: return "#CB171E"
        case .html: return "#E34F26"
        case .css: return "#1572B6"
        case .text: return "#9E9E9E"
        case .other: return "#607D8B"
        }
    }

    var extensions: [String] {
        switch self {
        case .swift: return ["swift"]
        case .python: return ["py"]
        case .javascript: return ["js", "jsx", "mjs"]
        case .typescript: return ["ts", "tsx"]
        case .markdown: return ["md", "markdown"]
        case .json: return ["json"]
        case .yaml: return ["yml", "yaml"]
        case .html: return ["html", "htm"]
        case .css: return ["css", "scss", "less"]
        case .text: return ["txt", "log"]
        case .other: return []
        }
    }

    static func from(extension ext: String) -> RAGFileType {
        let lower = ext.lowercased()
        return RAGFileType.allCases.first { $0.extensions.contains(lower) } ?? .other
    }
}

/// Search result from RAG knowledge base
struct RAGSearchResult: Identifiable {
    let id: String
    let document: RAGDocument
    let matchedSnippet: String
    let score: Float
    let lineNumber: Int?

    init(document: RAGDocument, matchedSnippet: String, score: Float, lineNumber: Int? = nil) {
        self.id = "\(document.id)-\(score)-\(lineNumber ?? 0)"
        self.document = document
        self.matchedSnippet = matchedSnippet
        self.score = score
        self.lineNumber = lineNumber
    }
}

/// Index statistics for the RAG knowledge base
struct RAGIndexStats: Codable {
    var totalDocuments: Int
    var totalLines: Int
    var totalSizeBytes: Int64
    var lastIndexedAt: Date?
    var indexDurationMs: Int?

    static let empty = RAGIndexStats(totalDocuments: 0, totalLines: 0, totalSizeBytes: 0)

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}

/// Relationship between files (import/dependency)
struct RAGRelationship: Codable, Hashable {
    let sourceId: String
    let targetId: String
    let type: RelationType

    enum RelationType: String, Codable {
        case imports
        case references
        case inherits
    }
}

// MARK: - Chunk Models

/// A semantic chunk of a source file
struct RAGChunk: Identifiable {
    let id: Int
    let documentId: String
    let chunkIndex: Int
    let chunkType: RAGChunkType
    let content: String
    let startLine: Int
    let endLine: Int
    let symbolName: String?
}

/// Types of code chunks
enum RAGChunkType: String, Codable, CaseIterable {
    case header
    case classDefinition
    case functionBody
    case commentBlock
    case genericBlock

    var maxLines: Int {
        switch self {
        case .header: return 50
        case .classDefinition: return 100
        case .functionBody: return 80
        case .commentBlock: return 40
        case .genericBlock: return 60
        }
    }

    var overlap: Int {
        switch self {
        case .header: return 0
        case .classDefinition: return 10
        case .functionBody: return 5
        case .commentBlock: return 0
        case .genericBlock: return 10
        }
    }
}

/// Search mode for the RAG engine
enum RAGSearchMode: String, Codable, CaseIterable {
    case hybrid
    case keyword
    case semantic

    var displayName: String {
        switch self {
        case .hybrid: return "Hybrid"
        case .keyword: return "Keyword"
        case .semantic: return "Semantic"
        }
    }

    var iconName: String {
        switch self {
        case .hybrid: return "arrow.triangle.merge"
        case .keyword: return "textformat"
        case .semantic: return "brain"
        }
    }
}

/// Search configuration parameters
struct RAGSearchConfig {
    var hybridWeight: Float = 0.6
    var rrfK: Int = 60
    var maxResults: Int = 20
    var metadataBoostEnabled: Bool = true
    var recencyBoostEnabled: Bool = true
    var relationshipBoostEnabled: Bool = true
    var minScore: Float = 0.01
}

/// Optional search filters
struct RAGSearchFilters {
    var fileTypes: Set<RAGFileType>?
    var pathPrefix: String?
    var modifiedAfter: Date?
    var modifiedBefore: Date?
    var excludePaths: [String]?
}

/// Database record for stored chunk
struct ChunkRecord {
    let id: Int?
    let documentId: String
    let chunkIndex: Int
    let chunkType: String
    let content: String
    let startLine: Int
    let endLine: Int
    let symbolName: String?
}

/// Extended statistics including chunk/embedding counts
struct RAGExtendedStats {
    var base: RAGIndexStats
    var totalChunks: Int
    var totalEmbeddings: Int
    var embeddingDimension: Int
    var vectorStoreSizeBytes: Int64
}

// MARK: - Semantic-Aware Search Configuration

/// Configuration for how RAG search integrates with the semantic pipeline (H5)
struct RAGSemanticConfig: Codable {
    var enableSemanticSearch: Bool
    var enableTermExpansion: Bool
    var enableEntityBoost: Bool
    var enableMemoryContext: Bool
    var maxSnippetsForPrompt: Int
    var scoringWeightsPreset: String  // "default", "codeSearch", "errorDiagnosis"

    static let `default` = RAGSemanticConfig(
        enableSemanticSearch: true,
        enableTermExpansion: true,
        enableEntityBoost: true,
        enableMemoryContext: true,
        maxSnippetsForPrompt: 7,
        scoringWeightsPreset: "default"
    )
}

// MARK: - Vector Serialization

extension Array where Element == Float {
    /// Serialize [Float] → Data (BLOB)
    var asBlob: Data {
        withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    /// Deserialize Data (BLOB) → [Float]
    static func fromBlob(_ data: Data) -> [Float] {
        data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }
}
