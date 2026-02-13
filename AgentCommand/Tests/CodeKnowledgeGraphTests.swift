import XCTest
@testable import AgentCommand

// MARK: - J1: Code Knowledge Graph Models Unit Tests

final class FileNodeTypeTests: XCTestCase {

    func testAllCasesHaveDisplayName() {
        for nodeType in FileNodeType.allCases {
            XCTAssertFalse(nodeType.displayName.isEmpty)
        }
    }

    func testAllCasesHaveHexColor() {
        for nodeType in FileNodeType.allCases {
            XCTAssertTrue(nodeType.hexColor.hasPrefix("#"))
            XCTAssertEqual(nodeType.hexColor.count, 7)
        }
    }

    func testAllCasesHaveIconName() {
        for nodeType in FileNodeType.allCases {
            XCTAssertFalse(nodeType.iconName.isEmpty)
        }
    }

    func testRawValues() {
        XCTAssertEqual(FileNodeType.swiftFile.rawValue, "swift")
        XCTAssertEqual(FileNodeType.directory.rawValue, "directory")
        XCTAssertEqual(FileNodeType.resource.rawValue, "resource")
        XCTAssertEqual(FileNodeType.config.rawValue, "config")
        XCTAssertEqual(FileNodeType.test.rawValue, "test")
        XCTAssertEqual(FileNodeType.unknown.rawValue, "unknown")
    }

    func testIdentifiable() {
        XCTAssertEqual(FileNodeType.swiftFile.id, "swift")
    }
}

final class DependencyTypeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(DependencyType.importDependency.rawValue, "import")
        XCTAssertEqual(DependencyType.inheritance.rawValue, "inheritance")
        XCTAssertEqual(DependencyType.protocolConformance.rawValue, "protocol")
        XCTAssertEqual(DependencyType.functionCall.rawValue, "call")
    }

    func testAllCasesHaveHexColor() {
        for depType in DependencyType.allCases {
            XCTAssertTrue(depType.hexColor.hasPrefix("#"))
            XCTAssertEqual(depType.hexColor.count, 7)
        }
    }
}

// MARK: - Code Knowledge Graph Manager Tests

@MainActor
final class CodeKnowledgeGraphManagerTests: XCTestCase {

    private var manager: CodeKnowledgeGraphManager!

    override func setUp() {
        super.setUp()
        manager = CodeKnowledgeGraphManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Highlight Tests

    func testHighlightAffectedFiles() {
        // Set up sample data with known structure
        let nodeA = CodeFileNode(id: UUID(), name: "A", path: "/A.swift", type: .swiftFile,
                                 lineCount: 100, imports: [], dependencies: [])
        let nodeB = CodeFileNode(id: UUID(), name: "B", path: "/B.swift", type: .swiftFile,
                                 lineCount: 50, imports: [], dependencies: [])
        let nodeC = CodeFileNode(id: UUID(), name: "C", path: "/C.swift", type: .swiftFile,
                                 lineCount: 75, imports: [], dependencies: [])

        let edge = CodeDependencyEdge(id: UUID(), sourceId: nodeA.id, targetId: nodeB.id, edgeType: .importDependency)

        manager.fileNodes = [nodeA, nodeB, nodeC]
        manager.edges = [edge]

        manager.highlightAffectedFiles(fileId: nodeA.id)

        // nodeA and nodeB should be highlighted (connected by edge)
        XCTAssertTrue(manager.fileNodes.first(where: { $0.id == nodeA.id })?.isHighlighted ?? false)
        XCTAssertTrue(manager.fileNodes.first(where: { $0.id == nodeB.id })?.isHighlighted ?? false)
        // nodeC should NOT be highlighted (no connection)
        XCTAssertFalse(manager.fileNodes.first(where: { $0.id == nodeC.id })?.isHighlighted ?? true)
        // Edge should be active
        XCTAssertTrue(manager.edges[0].isActive)
    }

    func testHighlightAffectedFiles_ResetsOtherHighlights() {
        let nodeA = CodeFileNode(id: UUID(), name: "A", path: "/A.swift", type: .swiftFile,
                                 lineCount: 100, imports: [], dependencies: [], isHighlighted: true)
        let nodeB = CodeFileNode(id: UUID(), name: "B", path: "/B.swift", type: .swiftFile,
                                 lineCount: 50, imports: [], dependencies: [], isHighlighted: true)

        manager.fileNodes = [nodeA, nodeB]
        manager.edges = []

        manager.highlightAffectedFiles(fileId: nodeA.id)

        // Only nodeA should be highlighted (no edges to nodeB)
        XCTAssertTrue(manager.fileNodes[0].isHighlighted)
        XCTAssertFalse(manager.fileNodes[1].isHighlighted)
    }

    func testClearHighlights() {
        let nodeA = CodeFileNode(id: UUID(), name: "A", path: "/A.swift", type: .swiftFile,
                                 lineCount: 100, imports: [], dependencies: [], isHighlighted: true)
        let edge = CodeDependencyEdge(id: UUID(), sourceId: nodeA.id, targetId: UUID(), edgeType: .importDependency, isActive: true)

        manager.fileNodes = [nodeA]
        manager.edges = [edge]

        manager.clearHighlights()

        XCTAssertFalse(manager.fileNodes[0].isHighlighted)
        XCTAssertFalse(manager.edges[0].isActive)
    }

    // MARK: - Stats Tests

    func testAnalyzeProject_NonExistentDirectory() {
        // Non-existent directory should fall back to sample data
        manager.analyzeProject(directory: "/non/existent/path/\(UUID().uuidString)")
        // Should have sample data
        XCTAssertFalse(manager.fileNodes.isEmpty)
        XCTAssertFalse(manager.edges.isEmpty)
        XCTAssertNotNil(manager.lastAnalyzed)
        XCTAssertFalse(manager.isAnalyzing)
    }

    func testStats_WithSampleData() {
        manager.analyzeProject(directory: "/non/existent/\(UUID().uuidString)")
        XCTAssertGreaterThan(manager.stats.totalFiles, 0)
        XCTAssertGreaterThan(manager.stats.totalDependencies, 0)
        XCTAssertGreaterThan(manager.stats.avgComplexity, 0)
        XCTAssertFalse(manager.stats.mostConnectedFile.isEmpty)
    }
}

// MARK: - CodeFileNode Tests

final class CodeFileNodeTests: XCTestCase {

    func testInitialization() {
        let id = UUID()
        let node = CodeFileNode(
            id: id,
            name: "TestFile",
            path: "/TestFile.swift",
            type: .swiftFile,
            lineCount: 200,
            imports: ["Foundation", "SwiftUI"],
            dependencies: []
        )
        XCTAssertEqual(node.id, id)
        XCTAssertEqual(node.name, "TestFile")
        XCTAssertEqual(node.type, .swiftFile)
        XCTAssertEqual(node.lineCount, 200)
        XCTAssertEqual(node.imports.count, 2)
        XCTAssertFalse(node.isHighlighted)
        XCTAssertEqual(node.complexity, 0)
    }
}

// MARK: - FunctionCallChain Tests

final class FunctionCallChainTests: XCTestCase {

    func testInitialization() {
        let chain = FunctionCallChain(
            id: UUID(),
            callerFile: "A.swift",
            callerFunction: "doWork()",
            calleeFile: "B.swift",
            calleeFunction: "process()"
        )
        XCTAssertEqual(chain.callerFile, "A.swift")
        XCTAssertEqual(chain.calleeFunction, "process()")
        XCTAssertEqual(chain.callCount, 1)
    }
}
