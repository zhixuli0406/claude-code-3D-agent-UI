import Foundation

// MARK: - RAG Content Chunker (Code-Aware Chunking)

/// Splits source files into semantically meaningful chunks based on language structure.
struct RAGContentChunker {

    struct Chunk {
        let content: String
        let type: RAGChunkType
        let startLine: Int
        let endLine: Int
        let symbolName: String?
    }

    // MARK: - Public API

    /// Chunk a source file based on its type
    func chunk(content: String, fileType: RAGFileType) -> [Chunk] {
        switch fileType {
        case .swift:
            return chunkSwift(content)
        case .python:
            return chunkPython(content)
        case .javascript, .typescript:
            return chunkJavaScript(content)
        default:
            return chunkGeneric(content)
        }
    }

    // MARK: - Swift Chunking

    /// Swift-specific chunking — splits on class/struct/enum/func boundaries
    func chunkSwift(_ content: String) -> [Chunk] {
        let lines = content.components(separatedBy: "\n")
        var chunks: [Chunk] = []
        var currentChunkLines: [String] = []
        var currentType: RAGChunkType = .header
        var currentSymbol: String?
        var currentStart = 0
        var braceDepth = 0
        var inHeader = true

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect header section (imports at the top)
            if inHeader {
                if trimmed.hasPrefix("import ") || trimmed.isEmpty || trimmed.hasPrefix("//") {
                    currentChunkLines.append(line)
                    continue
                } else {
                    // End header, flush it
                    if !currentChunkLines.isEmpty {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: .header,
                            startLine: 0,
                            endLine: index - 1,
                            symbolName: nil
                        ))
                    }
                    currentChunkLines = []
                    currentStart = index
                    inHeader = false
                }
            }

            // Detect class/struct/enum/protocol declarations
            if braceDepth == 0 {
                if let symbol = extractSwiftDeclaration(trimmed) {
                    // Flush current chunk
                    if !currentChunkLines.isEmpty {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: currentType,
                            startLine: currentStart,
                            endLine: index - 1,
                            symbolName: currentSymbol
                        ))
                    }
                    currentChunkLines = [line]
                    currentStart = index
                    currentType = symbol.type
                    currentSymbol = symbol.name
                    braceDepth = countBraces(in: line)
                    continue
                }

                // Detect top-level func
                if trimmed.hasPrefix("func ") || trimmed.contains(" func ") {
                    if !currentChunkLines.isEmpty {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: currentType,
                            startLine: currentStart,
                            endLine: index - 1,
                            symbolName: currentSymbol
                        ))
                    }
                    currentChunkLines = [line]
                    currentStart = index
                    currentType = .functionBody
                    currentSymbol = extractFuncName(trimmed)
                    braceDepth = countBraces(in: line)
                    continue
                }

                // Detect multi-line comment block
                if trimmed.hasPrefix("/*") || trimmed.hasPrefix("///") || trimmed.hasPrefix("/**") {
                    if !currentChunkLines.isEmpty && currentType != .commentBlock {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: currentType,
                            startLine: currentStart,
                            endLine: index - 1,
                            symbolName: currentSymbol
                        ))
                        currentChunkLines = [line]
                        currentStart = index
                        currentType = .commentBlock
                        currentSymbol = nil
                        continue
                    }
                }
            }

            currentChunkLines.append(line)
            braceDepth += countBraces(in: line)
            if braceDepth < 0 { braceDepth = 0 }

            // If we've closed all braces, the declaration/function is complete
            if braceDepth == 0 && (currentType == .functionBody || currentType == .classDefinition) && currentChunkLines.count > 1 {
                chunks.append(Chunk(
                    content: currentChunkLines.joined(separator: "\n"),
                    type: currentType,
                    startLine: currentStart,
                    endLine: index,
                    symbolName: currentSymbol
                ))
                currentChunkLines = []
                currentStart = index + 1
                currentType = .genericBlock
                currentSymbol = nil
            }

            // If generic block exceeds max lines, split it
            if currentType == .genericBlock && currentChunkLines.count >= RAGChunkType.genericBlock.maxLines {
                chunks.append(Chunk(
                    content: currentChunkLines.joined(separator: "\n"),
                    type: .genericBlock,
                    startLine: currentStart,
                    endLine: index,
                    symbolName: nil
                ))
                // Keep overlap lines
                let overlap = RAGChunkType.genericBlock.overlap
                if overlap > 0 && currentChunkLines.count > overlap {
                    currentChunkLines = Array(currentChunkLines.suffix(overlap))
                    currentStart = index - overlap + 1
                } else {
                    currentChunkLines = []
                    currentStart = index + 1
                }
            }
        }

        // Flush remaining
        if !currentChunkLines.isEmpty {
            let joined = currentChunkLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                chunks.append(Chunk(
                    content: joined,
                    type: currentType,
                    startLine: currentStart,
                    endLine: lines.count - 1,
                    symbolName: currentSymbol
                ))
            }
        }

        return chunks.isEmpty ? [Chunk(content: content, type: .genericBlock, startLine: 0, endLine: lines.count - 1, symbolName: nil)] : chunks
    }

    // MARK: - Python Chunking

    /// Python-specific chunking — splits on def/class at indent level 0
    func chunkPython(_ content: String) -> [Chunk] {
        let lines = content.components(separatedBy: "\n")
        var chunks: [Chunk] = []
        var currentChunkLines: [String] = []
        var currentType: RAGChunkType = .header
        var currentSymbol: String?
        var currentStart = 0
        var inHeader = true

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            // Detect header (imports at top)
            if inHeader {
                if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") || trimmed.isEmpty || trimmed.hasPrefix("#") {
                    currentChunkLines.append(line)
                    continue
                } else {
                    if !currentChunkLines.isEmpty {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: .header,
                            startLine: 0,
                            endLine: index - 1,
                            symbolName: nil
                        ))
                    }
                    currentChunkLines = []
                    currentStart = index
                    inHeader = false
                }
            }

            // Top-level class or function
            if indent == 0 && (trimmed.hasPrefix("class ") || trimmed.hasPrefix("def ")) {
                // Flush previous
                if !currentChunkLines.isEmpty {
                    chunks.append(Chunk(
                        content: currentChunkLines.joined(separator: "\n"),
                        type: currentType,
                        startLine: currentStart,
                        endLine: index - 1,
                        symbolName: currentSymbol
                    ))
                }
                currentChunkLines = [line]
                currentStart = index
                currentType = trimmed.hasPrefix("class ") ? .classDefinition : .functionBody
                currentSymbol = extractPythonName(trimmed)
                continue
            }

            currentChunkLines.append(line)

            // Split on max lines for generic blocks
            if currentType == .genericBlock && currentChunkLines.count >= RAGChunkType.genericBlock.maxLines {
                chunks.append(Chunk(
                    content: currentChunkLines.joined(separator: "\n"),
                    type: .genericBlock,
                    startLine: currentStart,
                    endLine: index,
                    symbolName: nil
                ))
                let overlap = RAGChunkType.genericBlock.overlap
                if overlap > 0 && currentChunkLines.count > overlap {
                    currentChunkLines = Array(currentChunkLines.suffix(overlap))
                    currentStart = index - overlap + 1
                } else {
                    currentChunkLines = []
                    currentStart = index + 1
                }
            }
        }

        // Flush remaining
        if !currentChunkLines.isEmpty {
            let joined = currentChunkLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                chunks.append(Chunk(
                    content: joined,
                    type: currentType,
                    startLine: currentStart,
                    endLine: lines.count - 1,
                    symbolName: currentSymbol
                ))
            }
        }

        return chunks.isEmpty ? [Chunk(content: content, type: .genericBlock, startLine: 0, endLine: lines.count - 1, symbolName: nil)] : chunks
    }

    // MARK: - JavaScript/TypeScript Chunking

    /// JavaScript/TypeScript chunking — splits on function/class/const patterns
    func chunkJavaScript(_ content: String) -> [Chunk] {
        let lines = content.components(separatedBy: "\n")
        var chunks: [Chunk] = []
        var currentChunkLines: [String] = []
        var currentType: RAGChunkType = .header
        var currentSymbol: String?
        var currentStart = 0
        var braceDepth = 0
        var inHeader = true

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Header detection (imports)
            if inHeader {
                if trimmed.hasPrefix("import ") || trimmed.hasPrefix("require(") || trimmed.isEmpty
                    || trimmed.hasPrefix("//") || trimmed.hasPrefix("'use ") || trimmed.hasPrefix("\"use ") {
                    currentChunkLines.append(line)
                    continue
                } else {
                    if !currentChunkLines.isEmpty {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: .header,
                            startLine: 0,
                            endLine: index - 1,
                            symbolName: nil
                        ))
                    }
                    currentChunkLines = []
                    currentStart = index
                    inHeader = false
                }
            }

            // Top-level declarations
            if braceDepth == 0 {
                if let name = extractJSDeclaration(trimmed) {
                    if !currentChunkLines.isEmpty {
                        chunks.append(Chunk(
                            content: currentChunkLines.joined(separator: "\n"),
                            type: currentType,
                            startLine: currentStart,
                            endLine: index - 1,
                            symbolName: currentSymbol
                        ))
                    }
                    currentChunkLines = [line]
                    currentStart = index
                    currentType = trimmed.contains("class ") ? .classDefinition : .functionBody
                    currentSymbol = name
                    braceDepth = countBraces(in: line)
                    continue
                }
            }

            currentChunkLines.append(line)
            braceDepth += countBraces(in: line)
            if braceDepth < 0 { braceDepth = 0 }

            // Close of top-level declaration
            if braceDepth == 0 && (currentType == .functionBody || currentType == .classDefinition) && currentChunkLines.count > 1 {
                chunks.append(Chunk(
                    content: currentChunkLines.joined(separator: "\n"),
                    type: currentType,
                    startLine: currentStart,
                    endLine: index,
                    symbolName: currentSymbol
                ))
                currentChunkLines = []
                currentStart = index + 1
                currentType = .genericBlock
                currentSymbol = nil
            }

            // Generic block overflow
            if currentType == .genericBlock && currentChunkLines.count >= RAGChunkType.genericBlock.maxLines {
                chunks.append(Chunk(
                    content: currentChunkLines.joined(separator: "\n"),
                    type: .genericBlock,
                    startLine: currentStart,
                    endLine: index,
                    symbolName: nil
                ))
                let overlap = RAGChunkType.genericBlock.overlap
                if overlap > 0 && currentChunkLines.count > overlap {
                    currentChunkLines = Array(currentChunkLines.suffix(overlap))
                    currentStart = index - overlap + 1
                } else {
                    currentChunkLines = []
                    currentStart = index + 1
                }
            }
        }

        // Flush remaining
        if !currentChunkLines.isEmpty {
            let joined = currentChunkLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                chunks.append(Chunk(
                    content: joined,
                    type: currentType,
                    startLine: currentStart,
                    endLine: lines.count - 1,
                    symbolName: currentSymbol
                ))
            }
        }

        return chunks.isEmpty ? [Chunk(content: content, type: .genericBlock, startLine: 0, endLine: lines.count - 1, symbolName: nil)] : chunks
    }

    // MARK: - Generic Chunking

    /// Generic line-based chunking with overlap for non-specific file types
    func chunkGeneric(_ content: String, maxLines: Int = 60, overlap: Int = 10) -> [Chunk] {
        let lines = content.components(separatedBy: "\n")
        guard lines.count > maxLines else {
            return [Chunk(content: content, type: .genericBlock, startLine: 0, endLine: lines.count - 1, symbolName: nil)]
        }

        var chunks: [Chunk] = []
        var start = 0

        while start < lines.count {
            let end = min(start + maxLines - 1, lines.count - 1)
            let chunkLines = Array(lines[start...end])
            chunks.append(Chunk(
                content: chunkLines.joined(separator: "\n"),
                type: .genericBlock,
                startLine: start,
                endLine: end,
                symbolName: nil
            ))
            start = end + 1 - overlap
            if start <= chunks.last.map({ $0.startLine }) ?? 0 {
                start = end + 1
            }
        }

        return chunks
    }

    // MARK: - Private Helpers

    private struct SymbolInfo {
        let name: String
        let type: RAGChunkType
    }

    private func extractSwiftDeclaration(_ line: String) -> SymbolInfo? {
        let patterns: [(prefix: String, type: RAGChunkType)] = [
            ("class ", .classDefinition),
            ("struct ", .classDefinition),
            ("enum ", .classDefinition),
            ("protocol ", .classDefinition),
            ("extension ", .classDefinition),
            ("actor ", .classDefinition),
        ]

        for pattern in patterns {
            // Match lines like "class Foo {", "public class Foo: Bar {"
            if line.contains(pattern.prefix) {
                let components = line.components(separatedBy: pattern.prefix)
                if components.count >= 2 {
                    let afterKeyword = components[1].trimmingCharacters(in: .whitespaces)
                    let name = afterKeyword.components(separatedBy: CharacterSet(charactersIn: " :{<")).first ?? afterKeyword
                    if !name.isEmpty {
                        return SymbolInfo(name: "\(pattern.prefix.trimmingCharacters(in: .whitespaces)) \(name)", type: pattern.type)
                    }
                }
            }
        }
        return nil
    }

    private func extractFuncName(_ line: String) -> String? {
        guard let funcRange = line.range(of: "func ") else { return nil }
        let afterFunc = String(line[funcRange.upperBound...])
        let name = afterFunc.components(separatedBy: CharacterSet(charactersIn: "( <")).first
        return name.map { "func \($0)" }
    }

    private func extractPythonName(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("class ") {
            let name = String(trimmed.dropFirst(6)).components(separatedBy: CharacterSet(charactersIn: "(: ")).first
            return name.map { "class \($0)" }
        }
        if trimmed.hasPrefix("def ") {
            let name = String(trimmed.dropFirst(4)).components(separatedBy: "(").first
            return name.map { "def \($0)" }
        }
        return nil
    }

    private func extractJSDeclaration(_ line: String) -> String? {
        // function name(
        if line.hasPrefix("function ") {
            let name = String(line.dropFirst(9)).components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces)
            return name
        }
        // export function name(
        if line.hasPrefix("export function ") {
            let name = String(line.dropFirst(16)).components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces)
            return name
        }
        // class Name
        if line.hasPrefix("class ") || line.hasPrefix("export class ") {
            let parts = line.components(separatedBy: "class ")
            if parts.count >= 2 {
                return parts[1].components(separatedBy: CharacterSet(charactersIn: " {")).first
            }
        }
        // const name = () => {
        if (line.hasPrefix("const ") || line.hasPrefix("export const ")) && line.contains("=>") {
            let parts = line.components(separatedBy: "const ")
            if parts.count >= 2 {
                return parts[1].components(separatedBy: " ").first
            }
        }
        return nil
    }

    private func countBraces(in line: String) -> Int {
        var count = 0
        var inString = false
        var stringChar: Character = "\""
        var prevChar: Character = " "

        for char in line {
            if !inString {
                if char == "\"" || char == "'" || char == "`" {
                    inString = true
                    stringChar = char
                } else if char == "{" {
                    count += 1
                } else if char == "}" {
                    count -= 1
                } else if char == "/" && prevChar == "/" {
                    break // rest is a comment
                }
            } else {
                if char == stringChar && prevChar != "\\" {
                    inString = false
                }
            }
            prevChar = char
        }
        return count
    }
}
