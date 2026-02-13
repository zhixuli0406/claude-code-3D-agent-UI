# RAG Search Engine Architecture Design

## RAG 搜尋引擎完整架構設計文檔

---

## 1. Architecture Overview (架構總覽)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Application Layer                            │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │ RAGSearchResults │  │ RAGKnowledge     │  │ RAGStatus         │  │
│  │ Overlay          │  │ GraphView        │  │ Overlay           │  │
│  └────────┬────────┘  └────────┬─────────┘  └────────┬──────────┘  │
│           │                    │                      │             │
│  ┌────────▼────────────────────▼──────────────────────▼──────────┐  │
│  │                      AppState (Publisher)                     │  │
│  └──────────────────────────┬───────────────────────────────────┘  │
├─────────────────────────────┼───────────────────────────────────────┤
│                    Orchestration Layer                              │
│  ┌──────────────────────────▼───────────────────────────────────┐  │
│  │                   RAGSystemManager                            │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐  │  │
│  │  │ Indexing     │  │ Search       │  │ File Watcher        │  │  │
│  │  │ Pipeline     │  │ Orchestrator │  │ (Incremental Update)│  │  │
│  │  └──────┬──────┘  └──────┬───────┘  └──────────┬──────────┘  │  │
│  └─────────┼────────────────┼─────────────────────┼─────────────┘  │
├─────────────┼────────────────┼─────────────────────┼────────────────┤
│                        Search Engine Layer                          │
│  ┌─────────▼────────────────▼─────────────────────▼─────────────┐  │
│  │                   RAGSearchEngine (NEW)                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │  │
│  │  │ Vector Store  │  │ FTS5 Engine  │  │ Hybrid Ranker     │   │  │
│  │  │ (Embeddings)  │  │ (Keyword)    │  │ (Score Fusion)    │   │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────┬────────┘   │  │
│  └─────────┼────────────────┼──────────────────────┼────────────┘  │
├─────────────┼────────────────┼──────────────────────┼────────────────┤
│                        Storage Layer                                │
│  ┌─────────▼────────────────▼──────────────────────▼─────────────┐  │
│  │                  RAGDatabaseManager (SQLite)                   │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │  │
│  │  │ documents    │  │ documents_fts│  │ embeddings (NEW)  │   │  │
│  │  │ relationships│  │ (FTS5)       │  │ chunks (NEW)      │   │  │
│  │  └──────────────┘  └──────────────┘  └───────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Flow (數據流)

### 2.1 Indexing Data Flow (索引數據流)

```
File System               Chunking              Embedding              Storage
   │                        │                      │                     │
   ▼                        ▼                      ▼                     ▼
┌──────┐   collectFiles  ┌──────────┐  chunk()  ┌──────────┐  store()  ┌──────┐
│ .swift│ ──────────────► │ Content  │ ────────► │ Embedding│ ────────► │SQLite│
│ .py   │                 │ Chunker  │           │ Generator│           │  DB  │
│ .ts   │                 └──────────┘           └──────────┘           └──────┘
│ ...   │                      │                      │                    │
└──────┘                       ▼                      ▼                    ▼
                          ┌──────────┐           ┌──────────┐        ┌──────────┐
                          │ Chunks   │           │ Float[]  │        │embeddings│
                          │ Table    │           │ vectors  │        │ chunks   │
                          └──────────┘           └──────────┘        │ docs_fts │
                                                                     └──────────┘
```

### 2.2 Search Data Flow (搜尋數據流)

```
User Query
    │
    ▼
┌───────────────────────────────────┐
│       Query Preprocessor          │
│  • tokenize                       │
│  • expand synonyms (optional)     │
│  • generate query embedding       │
└───────────┬───────────────────────┘
            │
    ┌───────┴───────────┐
    ▼                   ▼
┌──────────┐     ┌──────────────┐
│ FTS5     │     │ Vector       │
│ Keyword  │     │ Similarity   │
│ Search   │     │ Search       │
│ (BM25)   │     │ (Cosine)     │
└────┬─────┘     └──────┬───────┘
     │                  │
     ▼                  ▼
┌──────────────────────────────────┐
│       Hybrid Ranker               │
│  • Reciprocal Rank Fusion (RRF)   │
│  • Score normalization             │
│  • Metadata boosting               │
└───────────┬──────────────────────┘
            │
            ▼
┌──────────────────────────────────┐
│       Result Assembler            │
│  • Deduplicate                    │
│  • Snippet extraction             │
│  • Context window assembly        │
└───────────┬──────────────────────┘
            │
            ▼
     [RAGSearchResult]
```

### 2.3 Real-time Update Data Flow (實時更新數據流)

```
┌──────────┐   DispatchSource   ┌──────────────┐   needsReindex?   ┌──────────┐
│ File     │ ─────────────────► │ File Watcher │ ────────────────► │ Diff     │
│ System   │   .write/.rename   │ (debounce 2s)│                   │ Checker  │
│ Events   │   /.delete         └──────────────┘                   └────┬─────┘
└──────────┘                                                            │
                                                                   ┌────▼─────┐
                                                          YES ◄────┤ Changed? │
                                                            │      └────┬─────┘
                                                            ▼           │ NO
                                                     ┌──────────┐      ▼
                                                     │ Re-chunk │   (skip)
                                                     │ Re-embed │
                                                     │ Update DB│
                                                     └──────────┘
```

---

## 3. Vector Storage Design (向量化存儲設計)

### 3.1 Embedding Strategy

#### On-device Embedding Generation

由於此為 macOS 原生應用（SwiftUI），建議使用 Apple 原生框架以避免外部依賴：

| 方案 | 框架 | 維度 | 優點 | 缺點 |
|------|------|------|------|------|
| **方案 A (推薦)** | `NaturalLanguage.framework` `NLEmbedding` | 512 | 零依賴、系統內建、速度快 | 僅支援通用語言，程式碼語義有限 |
| 方案 B | CoreML + 自訂模型 | 768 | 可使用 code-specific 模型 | 需打包模型檔（~100MB） |
| 方案 C | Tokenizer-based Hash | 128 | 極輕量、無需模型 | 語義理解較弱 |

**推薦方案 A + 增強策略**：使用 `NLEmbedding` 作為基礎，配合程式碼感知的 token 增強。

#### Code-Aware Embedding Enhancement

```swift
/// Embedding generation strategy for code content
struct EmbeddingConfig {
    let dimension: Int = 512
    let language: NLLanguage = .english
    let codeTokenWeight: Float = 1.5    // boost code identifiers
    let commentWeight: Float = 1.0       // natural language comments
    let structureWeight: Float = 1.2     // function/class signatures
}
```

### 3.2 Chunking Strategy (分塊策略)

程式碼檔案需要語義感知的分塊方式，而非單純的固定長度切割：

```
┌─────────────────────────────────────────────────┐
│              Source File                          │
│  ┌───────────────────────────────────────────┐   │
│  │ import statements (chunk: header)          │   │
│  ├───────────────────────────────────────────┤   │
│  │ class Foo {                                │   │
│  │   // properties    (chunk: class_Foo_props)│   │
│  │   var x: Int                               │   │
│  │   var y: String                            │   │
│  ├───────────────────────────────────────────┤   │
│  │   func doSomething() {                     │   │
│  │     // method body (chunk: class_Foo_doSm) │   │
│  │     ...                                    │   │
│  │   }                                        │   │
│  ├───────────────────────────────────────────┤   │
│  │   func anotherMethod() {                   │   │
│  │     // method body (chunk: class_Foo_anoM) │   │
│  │     ...                                    │   │
│  │   }                                        │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

**Chunk Types:**

| Type | Description | Max Lines | Overlap |
|------|-------------|-----------|---------|
| `header` | Import/module declarations | 50 | 0 |
| `class_definition` | Class/struct/enum + properties | 100 | 10 |
| `function_body` | Single function/method | 80 | 5 |
| `comment_block` | Multi-line comments/docs | 40 | 0 |
| `generic_block` | Fallback fixed-size | 60 | 10 |

### 3.3 Database Schema Extension (資料庫擴展)

在現有 `RAGDatabaseManager` 基礎上新增兩張表：

```sql
-- Chunk-level content storage
CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,        -- order within document
    chunk_type TEXT NOT NULL,             -- 'header'|'class_definition'|'function_body'|...
    content TEXT NOT NULL,               -- raw chunk text
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    symbol_name TEXT,                     -- e.g., "class Foo", "func doSomething"
    created_at REAL NOT NULL,
    UNIQUE(document_id, chunk_index)
);

CREATE INDEX idx_chunks_document ON chunks(document_id);
CREATE INDEX idx_chunks_symbol ON chunks(symbol_name);

-- Vector embeddings storage
CREATE TABLE IF NOT EXISTS embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chunk_id INTEGER NOT NULL REFERENCES chunks(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    vector BLOB NOT NULL,                -- Float32 array serialized as BLOB
    dimension INTEGER NOT NULL DEFAULT 512,
    model_version TEXT NOT NULL DEFAULT 'nlembedding_v1',
    created_at REAL NOT NULL,
    UNIQUE(chunk_id)
);

CREATE INDEX idx_embeddings_document ON embeddings(document_id);
```

### 3.4 Vector Serialization (向量序列化)

```swift
// Store Float array as BLOB for efficient SQLite storage
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
```

---

## 4. Similarity Search Algorithm (相似度搜尋算法)

### 4.1 Cosine Similarity (餘弦相似度)

主要的向量搜尋算法，計算 query embedding 與所有 stored embeddings 的相似度：

```swift
/// Brute-force cosine similarity search (suitable for < 100K vectors)
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    precondition(a.count == b.count)
    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    let denom = sqrt(normA) * sqrt(normB)
    return denom > 0 ? dot / denom : 0
}
```

### 4.2 SIMD-Accelerated Search (SIMD 加速搜尋)

利用 Apple Accelerate framework 進行高效向量運算：

```swift
import Accelerate

/// SIMD-optimized cosine similarity using vDSP
func cosineSimilaritySIMD(_ a: [Float], _ b: [Float]) -> Float {
    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0

    vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
    vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
    vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

    let denom = sqrt(normA) * sqrt(normB)
    return denom > 0 ? dot / denom : 0
}

/// Batch similarity: query vs all stored vectors
func batchCosineSimilarity(query: [Float], candidates: [[Float]]) -> [Float] {
    // Use vDSP for batch computation
    return candidates.map { cosineSimilaritySIMD(query, $0) }
}
```

### 4.3 Approximate Nearest Neighbor (近似最近鄰) — 未來擴展

當向量數量超過 50K 時，引入 ANN 索引：

```
                     IVF (Inverted File Index)
                     ┌─────────────────────────┐
                     │  Cluster 0: [v12, v45..] │
 query ──► nearest ──│  Cluster 1: [v3, v78..]  │──► top-K candidates
           cluster   │  Cluster 2: [v56, v91..] │    ──► exact cosine
                     │  ...                      │
                     │  Cluster N: [v22, v67..] │
                     └─────────────────────────┘

 Tradeoff: nprobe (clusters to search) vs accuracy
 Recommended: nClusters = sqrt(N), nprobe = 10
```

---

## 5. Retrieval Ranking Mechanism (檢索排序機制)

### 5.1 Hybrid Search: Reciprocal Rank Fusion (RRF)

結合 FTS5 (keyword) 和 Vector (semantic) 兩路搜尋結果：

```
Query: "how to handle authentication"
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
    FTS5 Search           Vector Search
    (BM25 ranking)        (Cosine ranking)
         │                     │
         ▼                     ▼
  Rank  Doc                Rank  Doc
  1.    AuthService.swift  1.    LoginManager.swift
  2.    LoginManager.swift 2.    AuthService.swift
  3.    UserModel.swift    3.    TokenStore.swift
  4.    TokenStore.swift   4.    UserModel.swift
         │                     │
         └─────────┬───────────┘
                   ▼
            RRF Score Fusion
            ┌─────────────────────────────┐
            │ RRF(d) = Σ 1 / (k + rank_i) │
            │ k = 60 (standard constant)   │
            └─────────────┬───────────────┘
                          ▼
              Final Ranked Results:
              1. AuthService.swift    (0.0328)
              2. LoginManager.swift   (0.0328)
              3. TokenStore.swift     (0.0163)
              4. UserModel.swift      (0.0163)
```

### 5.2 Score Computation Formula

```
FinalScore(doc) = α × RRF_score
                + β × metadata_boost
                + γ × recency_boost
                + δ × relationship_boost

Where:
  α = 1.0   (base RRF weight)
  β = 0.15  (metadata relevance: file type match, symbol match)
  γ = 0.10  (recency: recently modified files get slight boost)
  δ = 0.05  (graph proximity: documents connected via imports)
```

### 5.3 Metadata Boosting Rules

| Factor | Boost | Condition |
|--------|-------|-----------|
| File type match | +0.15 | Query mentions "swift" and doc is `.swift` |
| Symbol match | +0.20 | Query contains exact function/class name |
| Recency (< 1 day) | +0.10 | File modified within last 24 hours |
| Recency (< 7 days) | +0.05 | File modified within last week |
| Import relationship | +0.05 | Document imports or is imported by a top result |
| File size penalty | -0.05 | Very large files (> 500 lines) slightly penalized per chunk |

---

## 6. Key Components (關鍵組件定義)

### 6.1 RAGSearchEngine (NEW — 核心搜尋引擎)

```swift
/// Central search engine coordinating keyword + vector search
@MainActor
class RAGSearchEngine {

    private let dbManager: RAGDatabaseManager
    private let embedder: RAGEmbeddingService
    private let chunker: RAGContentChunker
    private let ranker: RAGHybridRanker

    // Configuration
    var searchConfig = RAGSearchConfig()

    init(dbManager: RAGDatabaseManager) {
        self.dbManager = dbManager
        self.embedder = RAGEmbeddingService()
        self.chunker = RAGContentChunker()
        self.ranker = RAGHybridRanker()
    }

    /// Primary hybrid search API
    func search(query: String, limit: Int = 20,
                filters: RAGSearchFilters? = nil) -> [RAGSearchResult]

    /// Semantic-only search
    func semanticSearch(query: String, topK: Int = 10) -> [RAGSearchResult]

    /// Keyword-only search (existing FTS5)
    func keywordSearch(query: String, limit: Int = 20) -> [RAGSearchResult]

    /// Index a single document (chunk + embed + store)
    func indexDocument(_ url: URL, baseDirectory: URL) async

    /// Batch index multiple documents
    func indexDocuments(_ urls: [URL], baseDirectory: URL,
                        progress: @escaping (Double) -> Void) async

    /// Remove document and its chunks/embeddings
    func removeDocument(id: String)

    /// Get context for LLM prompt augmentation
    func getContextForPrompt(query: String, maxTokens: Int = 2000) -> String
}
```

### 6.2 RAGEmbeddingService (NEW — 向量化服務)

```swift
/// Generates embeddings using NaturalLanguage framework
class RAGEmbeddingService {

    private let embedding: NLEmbedding?
    let dimension: Int = 512

    init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
    }

    /// Generate embedding for a text chunk
    func embed(text: String) -> [Float]?

    /// Generate embedding for a search query
    func embedQuery(query: String) -> [Float]?

    /// Batch embed multiple chunks (parallel processing)
    func embedBatch(texts: [String]) async -> [[Float]?]

    /// Code-aware text preprocessing
    func preprocessForEmbedding(_ code: String,
                                 fileType: RAGFileType) -> String
}
```

### 6.3 RAGContentChunker (NEW — 內容分塊器)

```swift
/// Splits source files into semantically meaningful chunks
struct RAGContentChunker {

    struct Chunk {
        let content: String
        let type: ChunkType
        let startLine: Int
        let endLine: Int
        let symbolName: String?
    }

    enum ChunkType: String {
        case header
        case classDefinition
        case functionBody
        case commentBlock
        case genericBlock
    }

    /// Chunk a source file based on its type
    func chunk(content: String, fileType: RAGFileType) -> [Chunk]

    /// Swift-specific chunking (class/struct/func boundaries)
    func chunkSwift(_ content: String) -> [Chunk]

    /// Python-specific chunking (def/class boundaries)
    func chunkPython(_ content: String) -> [Chunk]

    /// JavaScript/TypeScript chunking
    func chunkJavaScript(_ content: String) -> [Chunk]

    /// Generic line-based chunking with overlap
    func chunkGeneric(_ content: String,
                      maxLines: Int = 60,
                      overlap: Int = 10) -> [Chunk]
}
```

### 6.4 RAGHybridRanker (NEW — 混合排序器)

```swift
/// Fuses keyword and vector search results using RRF
struct RAGHybridRanker {

    struct RankedResult {
        let documentId: String
        let chunkId: Int?
        let ftsRank: Int?       // position in FTS results
        let vectorRank: Int?    // position in vector results
        let rrfScore: Float     // combined RRF score
        let finalScore: Float   // after boosting
        let snippet: String
        let lineNumber: Int?
    }

    /// Fuse two ranked lists using Reciprocal Rank Fusion
    func fuse(ftsResults: [RAGSearchResult],
              vectorResults: [(chunkId: Int, score: Float, snippet: String)],
              k: Int = 60) -> [RankedResult]

    /// Apply metadata boosting to RRF scores
    func applyBoosts(results: [RankedResult],
                     documents: [RAGDocument],
                     relationships: [RAGRelationship],
                     query: String) -> [RankedResult]

    /// Deduplicate results from same document
    func deduplicate(_ results: [RankedResult],
                     maxPerDocument: Int = 3) -> [RankedResult]
}
```

### 6.5 RAGSearchConfig & RAGSearchFilters (NEW — 設定與篩選)

```swift
/// Search configuration parameters
struct RAGSearchConfig {
    var hybridWeight: Float = 0.6       // vector vs keyword weight
    var rrfK: Int = 60                  // RRF constant
    var maxResults: Int = 20
    var metadataBoostEnabled: Bool = true
    var recencyBoostEnabled: Bool = true
    var relationshipBoostEnabled: Bool = true
    var minScore: Float = 0.01          // filter out low-score results
}

/// Optional search filters
struct RAGSearchFilters {
    var fileTypes: Set<RAGFileType>?
    var pathPrefix: String?
    var modifiedAfter: Date?
    var modifiedBefore: Date?
    var minLineCount: Int?
    var maxLineCount: Int?
    var excludePaths: [String]?
}
```

---

## 7. API Interface Definition (API 接口定義)

### 7.1 RAGSystemManager Extended API

與現有 `RAGSystemManager` 的集成方式——在現有架構中引入 `RAGSearchEngine` 作為內部元件：

```swift
@MainActor
class RAGSystemManager: ObservableObject {

    // EXISTING properties (unchanged)
    @Published var indexStats: RAGIndexStats = .empty
    @Published var isIndexing: Bool = false
    @Published var indexProgress: Double = 0
    @Published var searchResults: [RAGSearchResult] = []
    @Published var searchQuery: String = ""
    @Published var documents: [RAGDocument] = []
    @Published var relationships: [RAGRelationship] = []
    @Published var isAutoIndexEnabled: Bool = true

    // EXISTING
    let dbManager = RAGDatabaseManager()

    // NEW — search engine instance
    private(set) var searchEngine: RAGSearchEngine!

    // NEW Published state
    @Published var searchMode: SearchMode = .hybrid
    @Published var searchFilters: RAGSearchFilters? = nil

    enum SearchMode: String, CaseIterable {
        case hybrid    // keyword + vector
        case keyword   // FTS5 only (existing behavior)
        case semantic  // vector only
    }

    // MODIFIED — initialize includes search engine
    func initialize() {
        dbManager.openDatabase()
        searchEngine = RAGSearchEngine(dbManager: dbManager)
        refreshFromDatabase()
    }

    // MODIFIED — search routes through search engine
    func search(query: String) {
        searchQuery = query
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        switch searchMode {
        case .hybrid:
            searchResults = searchEngine.search(
                query: query,
                filters: searchFilters
            )
        case .keyword:
            searchResults = searchEngine.keywordSearch(query: query)
        case .semantic:
            searchResults = searchEngine.semanticSearch(query: query)
        }
    }

    // MODIFIED — indexing also generates chunks + embeddings
    func indexDirectory(_ url: URL) {
        guard !isIndexing else { return }
        currentDirectory = url
        isIndexing = true
        indexProgress = 0

        Task.detached { [weak self] in
            guard let self else { return }
            let files = await self.collectFiles(in: url)
            await self.searchEngine.indexDocuments(files, baseDirectory: url) { progress in
                Task { @MainActor in
                    self.indexProgress = progress
                }
            }
            await self.analyzeRelationships(baseDirectory: url)
            await MainActor.run {
                self.isIndexing = false
                self.indexProgress = 1.0
                self.refreshFromDatabase()
            }
        }
    }

    // MODIFIED — context for prompt uses hybrid search
    func getContextForPrompt(query: String, maxSnippets: Int = 5) -> String {
        return searchEngine.getContextForPrompt(
            query: query,
            maxTokens: 2000
        )
    }
}
```

### 7.2 RAGDatabaseManager Extended API

在現有 `RAGDatabaseManager` 中新增 chunk 和 embedding 的 CRUD 操作：

```swift
@MainActor
class RAGDatabaseManager {

    // ===== EXISTING API (unchanged) =====
    func openDatabase()
    func closeDatabase()
    func insertDocument(_ doc: RAGDocument, content: String)
    func deleteDocument(id: String)
    func clearAll()
    func search(query: String, limit: Int) -> [RAGSearchResult]
    func fetchAllDocuments() -> [RAGDocument]
    func getStats() -> RAGIndexStats
    func insertRelationship(_ rel: RAGRelationship)
    func fetchRelationships() -> [RAGRelationship]
    func needsReindex(filePath: String, lastModified: Date) -> Bool

    // ===== NEW API — Chunks =====

    /// Insert content chunks for a document
    func insertChunks(_ chunks: [ChunkRecord], documentId: String)

    /// Fetch chunks for a specific document
    func fetchChunks(documentId: String) -> [ChunkRecord]

    /// Delete all chunks for a document
    func deleteChunks(documentId: String)

    // ===== NEW API — Embeddings =====

    /// Store embedding vector for a chunk
    func insertEmbedding(chunkId: Int, documentId: String,
                         vector: [Float], dimension: Int)

    /// Fetch all embeddings (for brute-force search)
    func fetchAllEmbeddings() -> [(chunkId: Int, documentId: String,
                                    vector: [Float])]

    /// Fetch embeddings for specific document
    func fetchEmbeddings(documentId: String) -> [(chunkId: Int,
                                                   vector: [Float])]

    /// Delete embeddings for a document
    func deleteEmbeddings(documentId: String)

    /// Get total embedding count
    func getEmbeddingCount() -> Int

    // ===== NEW API — Extended Stats =====

    /// Extended stats including chunk/embedding counts
    func getExtendedStats() -> RAGExtendedStats
}

/// Extended statistics model
struct RAGExtendedStats {
    var base: RAGIndexStats
    var totalChunks: Int
    var totalEmbeddings: Int
    var embeddingDimension: Int
    var vectorStoreSizeBytes: Int64
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
```

---

## 8. Integration with Existing System (與現有系統的集成)

### 8.1 Migration Strategy (遷移策略)

```
Phase 1: Add tables (non-breaking)
  └─ Create chunks + embeddings tables
  └─ Existing FTS5 search continues working

Phase 2: Background embedding generation
  └─ On next indexDirectory() call, also generate chunks + embeddings
  └─ Existing keyword search unaffected

Phase 3: Enable hybrid search
  └─ Switch searchMode to .hybrid by default
  └─ Keep .keyword as fallback option in UI
```

### 8.2 UI Integration Points

現有 UI 組件的修改計劃：

| Component | File | Change |
|-----------|------|--------|
| `RAGKnowledgeGraphView` | `RAGKnowledgeGraphView.swift` | Add search mode picker (hybrid/keyword/semantic) in search tab |
| `RAGSearchResultsOverlay` | `RAGSearchResultsOverlay.swift` | Show vector similarity score alongside BM25 score |
| `RAGStatusOverlay` | `RAGStatusOverlay.swift` | Add embedding stats (chunk count, vector store size) |
| `PromptInputBar` | `PromptInputBar.swift` | `getContextForPrompt()` now uses hybrid search |
| `RAGVisualizationBuilder` | `RAGVisualizationBuilder.swift` | (No change needed — operates on same `RAGDocument` model) |

### 8.3 AppState Integration

```swift
// In AppState — no structural changes needed
// RAGSystemManager's search() method is already called by UI
// The internal routing to hybrid/keyword/semantic is transparent

// Only new UI state needed:
@Published var ragSearchMode: RAGSystemManager.SearchMode = .hybrid
```

---

## 9. Performance Considerations (效能考量)

### 9.1 Memory Management

| Component | Memory Budget | Strategy |
|-----------|--------------|----------|
| Embedding cache | ~50 MB | LRU cache, 10K vectors max in memory |
| Chunk content | On-demand | Load from SQLite only when needed |
| FTS5 index | Managed by SQLite | Automatic |
| Search results | ~1 MB | Limited to top-20 results |

### 9.2 Performance Targets

| Operation | Target Latency | Strategy |
|-----------|---------------|----------|
| Keyword search (FTS5) | < 10ms | Existing, proven fast |
| Vector search (10K vectors) | < 50ms | vDSP batch cosine similarity |
| Hybrid search | < 100ms | Parallel FTS5 + vector, then fuse |
| Single file indexing | < 200ms | Chunk + embed + store |
| Full project index (1000 files) | < 30s | Parallel chunking, batch embedding |
| Incremental re-index (1 file) | < 300ms | Only re-chunk/re-embed changed file |

### 9.3 Scaling Thresholds

```
Vector Count     Strategy
─────────────    ──────────────────────────
< 10,000         Brute-force cosine (vDSP)
10K - 50K        Partitioned search (by file type)
50K - 200K       IVF index (future)
> 200K           Consider external vector DB (future)
```

---

## 10. Data Models Summary (資料模型摘要)

### New Models to Add

```swift
// Add to RAGModels.swift

/// A semantic chunk of a source file
struct RAGChunk: Identifiable, Codable {
    let id: Int
    let documentId: String
    let chunkIndex: Int
    let chunkType: RAGChunkType
    let content: String
    let startLine: Int
    let endLine: Int
    let symbolName: String?
}

enum RAGChunkType: String, Codable {
    case header
    case classDefinition
    case functionBody
    case commentBlock
    case genericBlock
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
}

/// Extended search result with vector score
struct RAGEnhancedSearchResult: Identifiable {
    let id: String
    let document: RAGDocument
    let chunk: RAGChunk?
    let matchedSnippet: String
    let keywordScore: Float?
    let vectorScore: Float?
    let finalScore: Float
    let lineNumber: Int?
    let matchType: MatchType

    enum MatchType {
        case keywordOnly
        case vectorOnly
        case hybrid
    }
}
```

---

## 11. File Structure (檔案結構)

```
AgentCommand/
└── AgentCommand/
    ├── Models/
    │   └── RAGModels.swift              ← ADD: RAGChunk, RAGChunkType,
    │                                          RAGSearchMode, RAGEnhancedSearchResult
    ├── Services/
    │   ├── RAGDatabaseManager.swift     ← EXTEND: chunks/embeddings CRUD
    │   ├── RAGSystemManager.swift       ← MODIFY: integrate RAGSearchEngine
    │   ├── RAGSearchEngine.swift        ← NEW: core hybrid search engine
    │   ├── RAGEmbeddingService.swift    ← NEW: NLEmbedding wrapper
    │   ├── RAGContentChunker.swift      ← NEW: code-aware chunking
    │   └── RAGHybridRanker.swift        ← NEW: RRF score fusion
    ├── Views/Overlays/
    │   ├── RAGSearchResultsOverlay.swift ← MINOR: show search mode
    │   ├── RAGStatusOverlay.swift        ← MINOR: show embedding stats
    │   └── RAGKnowledgeGraphView.swift   ← MINOR: add search mode picker
    └── Scene3D/Effects/
        └── RAGVisualizationBuilder.swift ← NO CHANGE
```

---

## 12. Implementation Priority (實作優先順序)

| Priority | Task | Estimated Effort |
|----------|------|-----------------|
| P0 | `RAGContentChunker` — code-aware chunking | Medium |
| P0 | Database schema migration (chunks + embeddings tables) | Small |
| P1 | `RAGEmbeddingService` — NLEmbedding integration | Medium |
| P1 | Embedding storage CRUD in `RAGDatabaseManager` | Small |
| P2 | `RAGSearchEngine` — vector search with vDSP | Medium |
| P2 | `RAGHybridRanker` — RRF fusion + boosting | Medium |
| P3 | `RAGSystemManager` integration | Small |
| P3 | UI updates (search mode picker, embedding stats) | Small |
| P4 | Performance optimization (batch embedding, caching) | Medium |
| P4 | IVF approximate search (future, if needed) | Large |
