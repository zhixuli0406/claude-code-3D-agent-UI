import XCTest
@testable import AgentCommand

// MARK: - H1: RAG Models Unit Tests

final class RAGFileTypeTests: XCTestCase {

    // MARK: - Display Name

    func testAllFileTypesHaveDisplayName() {
        for fileType in RAGFileType.allCases {
            XCTAssertFalse(fileType.displayName.isEmpty, "\(fileType) should have a non-empty displayName")
        }
    }

    func testSwiftDisplayName() {
        XCTAssertEqual(RAGFileType.swift.displayName, "Swift")
    }

    func testPythonDisplayName() {
        XCTAssertEqual(RAGFileType.python.displayName, "Python")
    }

    func testJavaScriptDisplayName() {
        XCTAssertEqual(RAGFileType.javascript.displayName, "JavaScript")
    }

    func testTypeScriptDisplayName() {
        XCTAssertEqual(RAGFileType.typescript.displayName, "TypeScript")
    }

    // MARK: - Color Hex

    func testAllFileTypesHaveColorHex() {
        for fileType in RAGFileType.allCases {
            XCTAssertTrue(fileType.colorHex.hasPrefix("#"), "\(fileType) colorHex should start with #")
            XCTAssertEqual(fileType.colorHex.count, 7, "\(fileType) colorHex should be 7 chars (#RRGGBB)")
        }
    }

    // MARK: - Extensions

    func testSwiftExtensions() {
        XCTAssertEqual(RAGFileType.swift.extensions, ["swift"])
    }

    func testJavaScriptExtensions() {
        XCTAssertEqual(RAGFileType.javascript.extensions, ["js", "jsx", "mjs"])
    }

    func testMarkdownExtensions() {
        XCTAssertEqual(RAGFileType.markdown.extensions, ["md", "markdown"])
    }

    func testCSSExtensions() {
        XCTAssertEqual(RAGFileType.css.extensions, ["css", "scss", "less"])
    }

    func testOtherHasNoExtensions() {
        XCTAssertTrue(RAGFileType.other.extensions.isEmpty)
    }

    // MARK: - From Extension

    func testFromExtension_Swift() {
        XCTAssertEqual(RAGFileType.from(extension: "swift"), .swift)
    }

    func testFromExtension_Python() {
        XCTAssertEqual(RAGFileType.from(extension: "py"), .python)
    }

    func testFromExtension_CaseInsensitive() {
        XCTAssertEqual(RAGFileType.from(extension: "SWIFT"), .swift)
        XCTAssertEqual(RAGFileType.from(extension: "Py"), .python)
    }

    func testFromExtension_Unknown() {
        XCTAssertEqual(RAGFileType.from(extension: "xyz"), .other)
        XCTAssertEqual(RAGFileType.from(extension: ""), .other)
    }

    func testFromExtension_TypeScript() {
        XCTAssertEqual(RAGFileType.from(extension: "ts"), .typescript)
        XCTAssertEqual(RAGFileType.from(extension: "tsx"), .typescript)
    }

    func testFromExtension_YAML() {
        XCTAssertEqual(RAGFileType.from(extension: "yml"), .yaml)
        XCTAssertEqual(RAGFileType.from(extension: "yaml"), .yaml)
    }

    func testFromExtension_HTML() {
        XCTAssertEqual(RAGFileType.from(extension: "html"), .html)
        XCTAssertEqual(RAGFileType.from(extension: "htm"), .html)
    }

    // MARK: - Codable

    func testFileTypeCodable() throws {
        let original = RAGFileType.swift
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RAGFileType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAllFileTypesCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for fileType in RAGFileType.allCases {
            let data = try encoder.encode(fileType)
            let decoded = try decoder.decode(RAGFileType.self, from: data)
            XCTAssertEqual(decoded, fileType)
        }
    }
}

// MARK: - RAGDocument Tests

final class RAGDocumentTests: XCTestCase {

    private func makeDocument(filePath: String = "/test/path/File.swift",
                              fileName: String = "File.swift",
                              fileType: RAGFileType = .swift) -> RAGDocument {
        RAGDocument(
            filePath: filePath,
            fileName: fileName,
            fileType: fileType,
            contentPreview: "import Foundation",
            lineCount: 100,
            fileSize: 2048,
            lastModified: Date()
        )
    }

    func testDocumentIdIsDeterministic() {
        let doc1 = makeDocument(filePath: "/same/path.swift")
        let doc2 = makeDocument(filePath: "/same/path.swift")
        XCTAssertEqual(doc1.id, doc2.id)
    }

    func testDocumentIdDiffersForDifferentPaths() {
        let doc1 = makeDocument(filePath: "/path/a.swift")
        let doc2 = makeDocument(filePath: "/path/b.swift")
        XCTAssertNotEqual(doc1.id, doc2.id)
    }

    func testDocumentIdFormat() {
        let doc = makeDocument()
        // ID should be 8 hex chars
        XCTAssertEqual(doc.id.count, 8)
        XCTAssertTrue(doc.id.allSatisfy { $0.isHexDigit })
    }

    func testDocumentCodable() throws {
        let original = makeDocument()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RAGDocument.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.filePath, original.filePath)
        XCTAssertEqual(decoded.fileName, original.fileName)
        XCTAssertEqual(decoded.fileType, original.fileType)
        XCTAssertEqual(decoded.lineCount, original.lineCount)
        XCTAssertEqual(decoded.fileSize, original.fileSize)
    }

    func testDocumentHashable() {
        let doc1 = makeDocument(filePath: "/a.swift")
        let doc3 = makeDocument(filePath: "/b.swift")
        // Same filePath → same id, but indexedAt differs, so Hashable may differ
        // Verify documents with different paths have different ids
        XCTAssertNotEqual(doc1.id, doc3.id)
        // Verify same path produces same id
        let doc2 = makeDocument(filePath: "/a.swift")
        XCTAssertEqual(doc1.id, doc2.id)
    }
}

// MARK: - RAGChunkType Tests

final class RAGChunkTypeTests: XCTestCase {

    func testMaxLines() {
        XCTAssertEqual(RAGChunkType.header.maxLines, 50)
        XCTAssertEqual(RAGChunkType.classDefinition.maxLines, 100)
        XCTAssertEqual(RAGChunkType.functionBody.maxLines, 80)
        XCTAssertEqual(RAGChunkType.commentBlock.maxLines, 40)
        XCTAssertEqual(RAGChunkType.genericBlock.maxLines, 60)
    }

    func testOverlap() {
        XCTAssertEqual(RAGChunkType.header.overlap, 0)
        XCTAssertEqual(RAGChunkType.classDefinition.overlap, 10)
        XCTAssertEqual(RAGChunkType.functionBody.overlap, 5)
        XCTAssertEqual(RAGChunkType.commentBlock.overlap, 0)
        XCTAssertEqual(RAGChunkType.genericBlock.overlap, 10)
    }

    func testCodable() throws {
        for chunkType in RAGChunkType.allCases {
            let data = try JSONEncoder().encode(chunkType)
            let decoded = try JSONDecoder().decode(RAGChunkType.self, from: data)
            XCTAssertEqual(decoded, chunkType)
        }
    }
}

// MARK: - RAGSearchMode Tests

final class RAGSearchModeTests: XCTestCase {

    func testDisplayName() {
        XCTAssertEqual(RAGSearchMode.hybrid.displayName, "Hybrid")
        XCTAssertEqual(RAGSearchMode.keyword.displayName, "Keyword")
        XCTAssertEqual(RAGSearchMode.semantic.displayName, "Semantic")
    }

    func testIconName() {
        XCTAssertFalse(RAGSearchMode.hybrid.iconName.isEmpty)
        XCTAssertFalse(RAGSearchMode.keyword.iconName.isEmpty)
        XCTAssertFalse(RAGSearchMode.semantic.iconName.isEmpty)
    }
}

// MARK: - RAGIndexStats Tests

final class RAGIndexStatsTests: XCTestCase {

    func testEmptyStats() {
        let stats = RAGIndexStats.empty
        XCTAssertEqual(stats.totalDocuments, 0)
        XCTAssertEqual(stats.totalLines, 0)
        XCTAssertEqual(stats.totalSizeBytes, 0)
        XCTAssertNil(stats.lastIndexedAt)
        XCTAssertNil(stats.indexDurationMs)
    }

    func testFormattedSize() {
        var stats = RAGIndexStats.empty
        stats.totalSizeBytes = 1024
        let formatted = stats.formattedSize
        XCTAssertFalse(formatted.isEmpty)
    }

    func testCodable() throws {
        let stats = RAGIndexStats(totalDocuments: 10, totalLines: 500, totalSizeBytes: 1024 * 1024, lastIndexedAt: Date(), indexDurationMs: 150)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(RAGIndexStats.self, from: data)
        XCTAssertEqual(decoded.totalDocuments, stats.totalDocuments)
        XCTAssertEqual(decoded.totalLines, stats.totalLines)
        XCTAssertEqual(decoded.totalSizeBytes, stats.totalSizeBytes)
    }
}

// MARK: - RAGRelationship Tests

final class RAGRelationshipTests: XCTestCase {

    func testRelationTypeRawValues() {
        XCTAssertEqual(RAGRelationship.RelationType.imports.rawValue, "imports")
        XCTAssertEqual(RAGRelationship.RelationType.references.rawValue, "references")
        XCTAssertEqual(RAGRelationship.RelationType.inherits.rawValue, "inherits")
    }

    func testHashable() {
        let rel1 = RAGRelationship(sourceId: "a", targetId: "b", type: .imports)
        let rel2 = RAGRelationship(sourceId: "a", targetId: "b", type: .imports)
        let rel3 = RAGRelationship(sourceId: "a", targetId: "c", type: .imports)
        XCTAssertEqual(rel1, rel2)
        XCTAssertNotEqual(rel1, rel3)
    }
}

// MARK: - RAGSearchResult Tests

final class RAGSearchResultTests: XCTestCase {

    func testSearchResultIdIncludesScore() {
        let doc = RAGDocument(
            filePath: "/test.swift",
            fileName: "test.swift",
            fileType: .swift,
            contentPreview: "",
            lineCount: 10,
            fileSize: 100,
            lastModified: Date()
        )
        let result = RAGSearchResult(document: doc, matchedSnippet: "snippet", score: 0.95, lineNumber: 42)
        XCTAssertTrue(result.id.contains(doc.id))
        XCTAssertEqual(result.score, 0.95)
        XCTAssertEqual(result.lineNumber, 42)
    }
}

// MARK: - RAGSemanticConfig Tests

final class RAGSemanticConfigTests: XCTestCase {

    func testDefaultConfig() {
        let config = RAGSemanticConfig.default
        XCTAssertTrue(config.enableSemanticSearch)
        XCTAssertTrue(config.enableTermExpansion)
        XCTAssertTrue(config.enableEntityBoost)
        XCTAssertTrue(config.enableMemoryContext)
        XCTAssertEqual(config.maxSnippetsForPrompt, 7)
        XCTAssertEqual(config.scoringWeightsPreset, "default")
    }

    func testCodable() throws {
        let config = RAGSemanticConfig.default
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(RAGSemanticConfig.self, from: data)
        XCTAssertEqual(decoded.enableSemanticSearch, config.enableSemanticSearch)
        XCTAssertEqual(decoded.maxSnippetsForPrompt, config.maxSnippetsForPrompt)
    }
}

// MARK: - Float Array Blob Serialization Tests

final class FloatArrayBlobTests: XCTestCase {

    func testRoundTrip() {
        let original: [Float] = [1.0, 2.5, -3.14, 0.0, 100.0]
        let blob = original.asBlob
        let restored = [Float].fromBlob(blob)
        XCTAssertEqual(restored.count, original.count)
        for (a, b) in zip(original, restored) {
            XCTAssertEqual(a, b, accuracy: 1e-6)
        }
    }

    func testEmptyArray() {
        let empty: [Float] = []
        let blob = empty.asBlob
        let restored = [Float].fromBlob(blob)
        XCTAssertTrue(restored.isEmpty)
    }

    func testSingleElement() {
        let single: [Float] = [42.0]
        let blob = single.asBlob
        let restored = [Float].fromBlob(blob)
        XCTAssertEqual(restored, [42.0])
    }

    func testBlobSize() {
        let array: [Float] = [1.0, 2.0, 3.0]
        let blob = array.asBlob
        // Each Float is 4 bytes
        XCTAssertEqual(blob.count, 3 * MemoryLayout<Float>.size)
    }
}
