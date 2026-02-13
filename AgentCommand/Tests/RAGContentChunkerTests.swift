import XCTest
@testable import AgentCommand

// MARK: - H1: RAG Content Chunker Unit Tests

final class RAGContentChunkerTests: XCTestCase {

    private let chunker = RAGContentChunker()

    // MARK: - Swift Chunking

    func testChunkSwift_EmptyContent() {
        let chunks = chunker.chunkSwift("")
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].type, .genericBlock)
    }

    func testChunkSwift_HeaderOnly() {
        let content = """
        import Foundation
        import SwiftUI
        // A comment
        """
        let chunks = chunker.chunkSwift(content)
        XCTAssertGreaterThanOrEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].type, .header)
        XCTAssertTrue(chunks[0].content.contains("import Foundation"))
    }

    func testChunkSwift_SingleFunction() {
        let content = """
        import Foundation

        func helloWorld() {
            print("Hello")
        }
        """
        let chunks = chunker.chunkSwift(content)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        // First chunk should be header
        XCTAssertEqual(chunks[0].type, .header)
        // Second chunk should be function
        let funcChunk = chunks.first { $0.type == .functionBody }
        XCTAssertNotNil(funcChunk)
        XCTAssertEqual(funcChunk?.symbolName, "func helloWorld")
    }

    func testChunkSwift_ClassDeclaration() {
        let content = """
        import Foundation

        class MyManager {
            var name: String = ""
            func doWork() {
                print("working")
            }
        }
        """
        let chunks = chunker.chunkSwift(content)
        let classChunk = chunks.first { $0.type == .classDefinition }
        XCTAssertNotNil(classChunk)
        XCTAssertTrue(classChunk?.symbolName?.contains("MyManager") ?? false)
    }

    func testChunkSwift_StructDeclaration() {
        let content = """
        struct Point {
            var x: Double
            var y: Double
        }
        """
        let chunks = chunker.chunkSwift(content)
        let structChunk = chunks.first { $0.type == .classDefinition }
        XCTAssertNotNil(structChunk)
        XCTAssertTrue(structChunk?.symbolName?.contains("Point") ?? false)
    }

    func testChunkSwift_EnumDeclaration() {
        let content = """
        enum Direction {
            case north
            case south
            case east
            case west
        }
        """
        let chunks = chunker.chunkSwift(content)
        let enumChunk = chunks.first { $0.type == .classDefinition }
        XCTAssertNotNil(enumChunk)
        XCTAssertTrue(enumChunk?.symbolName?.contains("Direction") ?? false)
    }

    func testChunkSwift_MultipleDeclarations() {
        let content = """
        import Foundation

        struct Config {
            var value: Int
        }

        func process() {
            print("process")
        }

        class Manager {
            var state: Bool = false
        }
        """
        let chunks = chunker.chunkSwift(content)
        XCTAssertGreaterThanOrEqual(chunks.count, 3)
        let types = Set(chunks.map(\.type))
        XCTAssertTrue(types.contains(.header))
        XCTAssertTrue(types.contains(.classDefinition))
        XCTAssertTrue(types.contains(.functionBody))
    }

    func testChunkSwift_CommentBlock() {
        let content = """
        import Foundation

        /// This is a doc comment
        /// describing the function
        func documented() {
            print("hello")
        }
        """
        let chunks = chunker.chunkSwift(content)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
    }

    func testChunkSwift_LineNumbers() {
        let content = """
        import Foundation

        func first() {
            print("first")
        }
        """
        let chunks = chunker.chunkSwift(content)
        for chunk in chunks {
            XCTAssertGreaterThanOrEqual(chunk.startLine, 0)
            XCTAssertGreaterThanOrEqual(chunk.endLine, chunk.startLine)
        }
    }

    // MARK: - Python Chunking

    func testChunkPython_EmptyContent() {
        let chunks = chunker.chunkPython("")
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].type, .genericBlock)
    }

    func testChunkPython_HeaderImports() {
        let content = """
        import os
        from sys import argv
        # A comment

        def main():
            pass
        """
        let chunks = chunker.chunkPython(content)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].type, .header)
        XCTAssertTrue(chunks[0].content.contains("import os"))
    }

    func testChunkPython_FunctionDef() {
        let content = """
        def hello():
            print("hello")
            return True
        """
        let chunks = chunker.chunkPython(content)
        let funcChunk = chunks.first { $0.type == .functionBody }
        XCTAssertNotNil(funcChunk)
        XCTAssertEqual(funcChunk?.symbolName, "def hello")
    }

    func testChunkPython_ClassDef() {
        let content = """
        class MyClass:
            def __init__(self):
                self.value = 0

            def method(self):
                return self.value
        """
        let chunks = chunker.chunkPython(content)
        let classChunk = chunks.first { $0.type == .classDefinition }
        XCTAssertNotNil(classChunk)
        XCTAssertEqual(classChunk?.symbolName, "class MyClass")
    }

    // MARK: - JavaScript Chunking

    func testChunkJavaScript_EmptyContent() {
        let chunks = chunker.chunkJavaScript("")
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].type, .genericBlock)
    }

    func testChunkJavaScript_Function() {
        let content = """
        import React from 'react';

        function App() {
            return <div>Hello</div>;
        }
        """
        let chunks = chunker.chunkJavaScript(content)
        let funcChunk = chunks.first { $0.type == .functionBody }
        XCTAssertNotNil(funcChunk)
        XCTAssertEqual(funcChunk?.symbolName, "App")
    }

    func testChunkJavaScript_ExportFunction() {
        let content = """
        export function calculate(a, b) {
            return a + b;
        }
        """
        let chunks = chunker.chunkJavaScript(content)
        let funcChunk = chunks.first { $0.type == .functionBody }
        XCTAssertNotNil(funcChunk)
        XCTAssertEqual(funcChunk?.symbolName, "calculate")
    }

    func testChunkJavaScript_ArrowFunction() {
        let content = """
        const handler = (event) => {
            console.log(event);
        }
        """
        let chunks = chunker.chunkJavaScript(content)
        let funcChunk = chunks.first { $0.type == .functionBody }
        XCTAssertNotNil(funcChunk)
        XCTAssertEqual(funcChunk?.symbolName, "handler")
    }

    func testChunkJavaScript_Class() {
        let content = """
        class Component {
            constructor() {
                this.state = {};
            }
        }
        """
        let chunks = chunker.chunkJavaScript(content)
        let classChunk = chunks.first { $0.type == .classDefinition }
        XCTAssertNotNil(classChunk)
        XCTAssertEqual(classChunk?.symbolName, "Component")
    }

    // MARK: - Generic Chunking

    func testChunkGeneric_ShortContent() {
        let content = "Line 1\nLine 2\nLine 3"
        let chunks = chunker.chunkGeneric(content)
        // Content shorter than maxLines should be a single chunk
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].type, .genericBlock)
        XCTAssertEqual(chunks[0].startLine, 0)
    }

    func testChunkGeneric_LongContent() {
        let lines = (0..<120).map { "Line \($0)" }
        let content = lines.joined(separator: "\n")
        let chunks = chunker.chunkGeneric(content, maxLines: 60, overlap: 10)
        XCTAssertGreaterThan(chunks.count, 1)
        // Each chunk should respect maxLines
        for chunk in chunks {
            let chunkLines = chunk.content.components(separatedBy: "\n")
            XCTAssertLessThanOrEqual(chunkLines.count, 60)
        }
    }

    // MARK: - Dispatch by File Type

    func testChunk_DispatchesToSwift() {
        let content = "import Foundation\nfunc test() {\n    print(\"test\")\n}"
        let chunks = chunker.chunk(content: content, fileType: .swift)
        XCTAssertFalse(chunks.isEmpty)
    }

    func testChunk_DispatchesToPython() {
        let content = "import os\ndef main():\n    pass"
        let chunks = chunker.chunk(content: content, fileType: .python)
        XCTAssertFalse(chunks.isEmpty)
    }

    func testChunk_DispatchesToJavaScript() {
        let content = "import React from 'react';\nfunction App() {\n    return null;\n}"
        let chunks = chunker.chunk(content: content, fileType: .javascript)
        XCTAssertFalse(chunks.isEmpty)
    }

    func testChunk_DispatchesToGeneric_ForMarkdown() {
        let content = "# Hello\n\nSome text"
        let chunks = chunker.chunk(content: content, fileType: .markdown)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertEqual(chunks[0].type, .genericBlock)
    }

    func testChunk_DispatchesToGeneric_ForJSON() {
        let content = "{\n  \"key\": \"value\"\n}"
        let chunks = chunker.chunk(content: content, fileType: .json)
        XCTAssertFalse(chunks.isEmpty)
    }

    func testChunk_TypeScriptUsesJSChunker() {
        let content = "import { Component } from 'react';\nfunction App() {\n    return null;\n}"
        let chunks = chunker.chunk(content: content, fileType: .typescript)
        XCTAssertFalse(chunks.isEmpty)
    }
}
