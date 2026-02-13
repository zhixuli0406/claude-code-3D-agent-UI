import XCTest
@testable import AgentCommand

// MARK: - H1: RAG Embedding Service Unit Tests

final class RAGEmbeddingServiceTests: XCTestCase {

    // MARK: - Cosine Similarity (Static)

    func testCosineSimilarity_IdenticalVectors() {
        let v = [Float](repeating: 1.0, count: 10)
        let similarity = RAGEmbeddingService.cosineSimilarity(v, v)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_OrthogonalVectors() {
        let a: [Float] = [1, 0, 0, 0]
        let b: [Float] = [0, 1, 0, 0]
        let similarity = RAGEmbeddingService.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.001)
    }

    func testCosineSimilarity_OppositeVectors() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        let similarity = RAGEmbeddingService.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, -1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_EmptyVectors() {
        let similarity = RAGEmbeddingService.cosineSimilarity([], [])
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarity_DifferentLengths() {
        let a: [Float] = [1, 2, 3]
        let b: [Float] = [1, 2]
        // Should return 0 due to length mismatch
        let similarity = RAGEmbeddingService.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarity_SimilarVectors() {
        let a: [Float] = [1, 2, 3, 4, 5]
        let b: [Float] = [1.1, 2.1, 3.1, 4.1, 5.1]
        let similarity = RAGEmbeddingService.cosineSimilarity(a, b)
        // Very similar vectors should have similarity close to 1
        XCTAssertGreaterThan(similarity, 0.99)
    }

    func testCosineSimilarity_ZeroVector() {
        let a: [Float] = [0, 0, 0]
        let b: [Float] = [1, 2, 3]
        let similarity = RAGEmbeddingService.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0)
    }

    // MARK: - Batch Cosine Similarity

    func testBatchCosineSimilarity_Empty() {
        let query: [Float] = [1, 0, 0]
        let results = RAGEmbeddingService.batchCosineSimilarity(query: query, candidates: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testBatchCosineSimilarity_MultipleCandidates() {
        let query: [Float] = [1, 0, 0]
        let candidates: [[Float]] = [
            [1, 0, 0],   // identical
            [0, 1, 0],   // orthogonal
            [-1, 0, 0],  // opposite
        ]
        let results = RAGEmbeddingService.batchCosineSimilarity(query: query, candidates: candidates)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0], 1.0, accuracy: 0.001)  // identical
        XCTAssertEqual(results[1], 0.0, accuracy: 0.001)  // orthogonal
        XCTAssertEqual(results[2], -1.0, accuracy: 0.001) // opposite
    }

    // MARK: - Preprocessing

    func testPreprocessForEmbedding_CamelCase() {
        let service = RAGEmbeddingService()
        let result = service.preprocessForEmbedding("myVariableName")
        // Should split camelCase
        XCTAssertTrue(result.contains("my"))
        XCTAssertTrue(result.contains("variable"))
        XCTAssertTrue(result.contains("name"))
    }

    func testPreprocessForEmbedding_SnakeCase() {
        let service = RAGEmbeddingService()
        let result = service.preprocessForEmbedding("my_variable_name")
        // Underscores should be replaced with spaces
        XCTAssertFalse(result.contains("_"))
        XCTAssertTrue(result.contains("my"))
    }

    func testPreprocessForEmbedding_RemovesSyntaxNoise() {
        let service = RAGEmbeddingService()
        let result = service.preprocessForEmbedding("func hello() { return x; }")
        XCTAssertFalse(result.contains("("))
        XCTAssertFalse(result.contains(")"))
        XCTAssertFalse(result.contains("{"))
        XCTAssertFalse(result.contains("}"))
        XCTAssertFalse(result.contains(";"))
    }

    func testPreprocessForEmbedding_Lowercased() {
        let service = RAGEmbeddingService()
        let result = service.preprocessForEmbedding("MyClass")
        XCTAssertEqual(result, result.lowercased())
    }

    func testPreprocessForEmbedding_CollapsesWhitespace() {
        let service = RAGEmbeddingService()
        let result = service.preprocessForEmbedding("func   hello()   {   }")
        XCTAssertFalse(result.contains("  "))
    }

    // MARK: - Embed (Integration with NLEmbedding)

    func testEmbed_ReturnsVectorForEnglishText() {
        let service = RAGEmbeddingService()
        let vector = service.embed(text: "hello world function")
        // NLEmbedding may or may not be available in test environment
        if let vector = vector {
            XCTAssertEqual(vector.count, service.dimension)
            // Should be L2 normalized (magnitude ≈ 1)
            let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
            XCTAssertEqual(magnitude, 1.0, accuracy: 0.01)
        }
    }

    func testEmbed_EmptyString() {
        let service = RAGEmbeddingService()
        let vector = service.embed(text: "")
        // Empty text should return nil
        XCTAssertNil(vector)
    }

    func testEmbedQuery_SameAsEmbed() {
        let service = RAGEmbeddingService()
        let v1 = service.embed(text: "search query")
        let v2 = service.embedQuery(query: "search query")
        if let v1 = v1, let v2 = v2 {
            XCTAssertEqual(v1.count, v2.count)
            for (a, b) in zip(v1, v2) {
                XCTAssertEqual(a, b, accuracy: 1e-6)
            }
        }
    }

    func testEmbedBatch() {
        let service = RAGEmbeddingService()
        let texts = ["hello", "world", ""]
        let results = service.embedBatch(texts: texts)
        XCTAssertEqual(results.count, 3)
        // Empty string should yield nil
        XCTAssertNil(results[2])
    }
}
