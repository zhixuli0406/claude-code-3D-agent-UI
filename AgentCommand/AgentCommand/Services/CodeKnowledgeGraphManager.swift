import Foundation
import Combine

// MARK: - J1: Code Knowledge Graph Manager

@MainActor
class CodeKnowledgeGraphManager: ObservableObject {
    @Published var fileNodes: [CodeFileNode] = []
    @Published var edges: [CodeDependencyEdge] = []
    @Published var callChains: [FunctionCallChain] = []
    @Published var stats: CodeKnowledgeGraphStats = CodeKnowledgeGraphStats()
    @Published var isAnalyzing: Bool = false
    @Published var lastAnalyzed: Date?

    private var workingDirectory: String?

    func analyzeProject(directory: String) {
        workingDirectory = directory
        isAnalyzing = true

        // Scan Swift files
        let dirURL = URL(fileURLWithPath: directory)
        var nodes: [CodeFileNode] = []
        var edgeList: [CodeDependencyEdge] = []

        if let enumerator = FileManager.default.enumerator(at: dirURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension == "swift" else { continue }
                let relativePath = url.path.replacingOccurrences(of: directory, with: "")
                let node = parseSwiftFile(url: url, relativePath: relativePath)
                nodes.append(node)
            }
        }

        // Build dependency edges from imports
        let nameToId = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0.id) })
        for node in nodes {
            for importName in node.imports {
                // Match import to file name
                let cleanImport = importName.replacingOccurrences(of: "import ", with: "")
                if let targetId = nameToId[cleanImport] {
                    let edge = CodeDependencyEdge(
                        id: UUID(),
                        sourceId: node.id,
                        targetId: targetId,
                        edgeType: .importDependency
                    )
                    edgeList.append(edge)
                }
            }
        }

        // If no real files found, generate sample data
        if nodes.isEmpty {
            generateSampleData()
        } else {
            fileNodes = nodes
            edges = edgeList
            updateStats()
        }

        isAnalyzing = false
        lastAnalyzed = Date()
    }

    private func parseSwiftFile(url: URL, relativePath: String) -> CodeFileNode {
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let lines = content.components(separatedBy: .newlines)
        let imports = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
        let fileName = url.lastPathComponent.replacingOccurrences(of: ".swift", with: "")

        // Estimate complexity by counting control flow keywords
        let controlKeywords = ["if ", "guard ", "for ", "while ", "switch ", "catch "]
        let complexity = controlKeywords.reduce(0) { acc, kw in
            acc + lines.filter { $0.contains(kw) }.count
        }

        let nodeType: FileNodeType
        if relativePath.contains("Test") { nodeType = .test }
        else if relativePath.contains("Config") || relativePath.contains("Info.plist") { nodeType = .config }
        else if url.pathExtension == "swift" { nodeType = .swiftFile }
        else { nodeType = .unknown }

        return CodeFileNode(
            id: UUID(),
            name: fileName,
            path: relativePath,
            type: nodeType,
            lineCount: lines.count,
            imports: imports,
            dependencies: [],
            complexity: complexity
        )
    }

    func highlightAffectedFiles(fileId: UUID) {
        // Reset all highlights
        for i in fileNodes.indices {
            fileNodes[i].isHighlighted = false
        }

        // Highlight the selected file and all files it depends on
        if let idx = fileNodes.firstIndex(where: { $0.id == fileId }) {
            fileNodes[idx].isHighlighted = true
        }
        let affectedEdges = edges.filter { $0.sourceId == fileId || $0.targetId == fileId }
        for edge in affectedEdges {
            if let idx = fileNodes.firstIndex(where: { $0.id == edge.sourceId }) {
                fileNodes[idx].isHighlighted = true
            }
            if let idx = fileNodes.firstIndex(where: { $0.id == edge.targetId }) {
                fileNodes[idx].isHighlighted = true
            }
        }

        // Activate related edges
        for i in edges.indices {
            edges[i].isActive = edges[i].sourceId == fileId || edges[i].targetId == fileId
        }
    }

    func clearHighlights() {
        for i in fileNodes.indices {
            fileNodes[i].isHighlighted = false
        }
        for i in edges.indices {
            edges[i].isActive = false
        }
    }

    private func generateSampleData() {
        let names = ["AppState", "ContentView", "SceneManager", "Agent", "AgentTask", "ConfigLoader", "CLIProcess", "SoundManager"]
        var nodes: [CodeFileNode] = []
        for name in names {
            nodes.append(CodeFileNode(
                id: UUID(),
                name: name,
                path: "/\(name).swift",
                type: .swiftFile,
                lineCount: Int.random(in: 50...500),
                imports: [],
                dependencies: [],
                complexity: Int.random(in: 5...30)
            ))
        }

        var edgeList: [CodeDependencyEdge] = []
        // ContentView depends on AppState
        edgeList.append(CodeDependencyEdge(id: UUID(), sourceId: nodes[1].id, targetId: nodes[0].id, edgeType: .importDependency))
        // SceneManager depends on Agent
        edgeList.append(CodeDependencyEdge(id: UUID(), sourceId: nodes[2].id, targetId: nodes[3].id, edgeType: .functionCall))
        // AppState depends on ConfigLoader
        edgeList.append(CodeDependencyEdge(id: UUID(), sourceId: nodes[0].id, targetId: nodes[5].id, edgeType: .importDependency))
        // AppState depends on CLIProcess
        edgeList.append(CodeDependencyEdge(id: UUID(), sourceId: nodes[0].id, targetId: nodes[6].id, edgeType: .functionCall))
        // AppState depends on SoundManager
        edgeList.append(CodeDependencyEdge(id: UUID(), sourceId: nodes[0].id, targetId: nodes[7].id, edgeType: .importDependency))
        // Agent depends on AgentTask
        edgeList.append(CodeDependencyEdge(id: UUID(), sourceId: nodes[3].id, targetId: nodes[4].id, edgeType: .inheritance))

        fileNodes = nodes
        edges = edgeList
        updateStats()
    }

    private func updateStats() {
        stats.totalFiles = fileNodes.count
        stats.totalDependencies = edges.count
        stats.totalFunctions = fileNodes.reduce(0) { $0 + $1.complexity }
        let complexities = fileNodes.map { Double($0.complexity) }
        stats.avgComplexity = complexities.isEmpty ? 0 : complexities.reduce(0, +) / Double(complexities.count)

        // Find most connected file
        var connectionCount: [UUID: Int] = [:]
        for edge in edges {
            connectionCount[edge.sourceId, default: 0] += 1
            connectionCount[edge.targetId, default: 0] += 1
        }
        if let mostConnectedId = connectionCount.max(by: { $0.value < $1.value })?.key,
           let file = fileNodes.first(where: { $0.id == mostConnectedId }) {
            stats.mostConnectedFile = file.name
        }
    }
}
