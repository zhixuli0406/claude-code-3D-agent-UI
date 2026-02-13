import Foundation
import NaturalLanguage
import Accelerate

// MARK: - RAG Embedding Service (NLEmbedding Wrapper)

/// Generates text embeddings using Apple's NaturalLanguage framework.
/// Uses NLEmbedding for word-level vectors, combined via mean pooling for sentence/chunk embeddings.
class RAGEmbeddingService {

    private let embedding: NLEmbedding?
    let dimension: Int = 512

    init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
    }

    // MARK: - Public API

    /// Generate embedding for a text chunk by averaging word vectors (mean pooling)
    func embed(text: String) -> [Float]? {
        guard let embedding = embedding else { return nil }
        let preprocessed = preprocessForEmbedding(text)
        let tokens = tokenize(preprocessed)
        guard !tokens.isEmpty else { return nil }

        var accumulated = [Double](repeating: 0.0, count: dimension)
        var count = 0

        for token in tokens {
            if let vector = embedding.vector(for: token) {
                for i in 0..<min(vector.count, dimension) {
                    accumulated[i] += vector[i]
                }
                count += 1
            }
        }

        guard count > 0 else { return nil }

        // Mean pooling
        let divisor = Double(count)
        var result = accumulated.map { Float($0 / divisor) }

        // L2 normalize
        l2Normalize(&result)

        return result
    }

    /// Generate embedding for a search query
    func embedQuery(query: String) -> [Float]? {
        return embed(text: query)
    }

    /// Batch embed multiple chunks
    func embedBatch(texts: [String]) -> [[Float]?] {
        return texts.map { embed(text: $0) }
    }

    // MARK: - Code-Aware Preprocessing

    /// Preprocess code content for better embedding quality
    func preprocessForEmbedding(_ code: String) -> String {
        var result = code

        // Split camelCase and PascalCase identifiers into separate words
        result = splitCamelCase(result)

        // Split snake_case
        result = result.replacingOccurrences(of: "_", with: " ")

        // Remove common syntax noise
        let syntaxNoise = ["(", ")", "{", "}", "[", "]", ";", ":", ",", "->", "=>", "//", "/*", "*/", "///", "#"]
        for noise in syntaxNoise {
            result = result.replacingOccurrences(of: noise, with: " ")
        }

        // Collapse whitespace
        result = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return result.lowercased()
    }

    // MARK: - Private Helpers

    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if word.count >= 2 { // skip single chars
                tokens.append(word)
            }
            return true
        }
        return tokens
    }

    private func splitCamelCase(_ text: String) -> String {
        var result = ""
        var prevWasUppercase = false
        var prevWasLetter = false

        for char in text {
            if char.isUppercase && prevWasLetter && !prevWasUppercase {
                result += " "
            }
            result += String(char)
            prevWasUppercase = char.isUppercase
            prevWasLetter = char.isLetter
        }
        return result
    }

    /// L2 normalize a vector in-place using vDSP
    private func l2Normalize(_ vector: inout [Float]) {
        var sumOfSquares: Float = 0
        vDSP_dotpr(vector, 1, vector, 1, &sumOfSquares, vDSP_Length(vector.count))
        let norm = sqrt(sumOfSquares)
        guard norm > 0 else { return }
        var divisor = norm
        vDSP_vsdiv(vector, 1, &divisor, &vector, 1, vDSP_Length(vector.count))
    }

    // MARK: - SIMD Cosine Similarity

    /// Compute cosine similarity between two vectors using vDSP for SIMD acceleration
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    /// Batch cosine similarity: query vs all stored vectors
    static func batchCosineSimilarity(query: [Float], candidates: [[Float]]) -> [Float] {
        return candidates.map { cosineSimilarity(query, $0) }
    }
}
