import Foundation

// MARK: - J1: Code Knowledge Graph Models

enum FileNodeType: String, CaseIterable, Identifiable {
    case swiftFile = "swift"
    case directory = "directory"
    case resource = "resource"
    case config = "config"
    case test = "test"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swiftFile: return "Swift"
        case .directory: return "Directory"
        case .resource: return "Resource"
        case .config: return "Config"
        case .test: return "Test"
        case .unknown: return "Unknown"
        }
    }

    var hexColor: String {
        switch self {
        case .swiftFile: return "#FF6F00"
        case .directory: return "#42A5F5"
        case .resource: return "#66BB6A"
        case .config: return "#AB47BC"
        case .test: return "#26C6DA"
        case .unknown: return "#9E9E9E"
        }
    }

    var iconName: String {
        switch self {
        case .swiftFile: return "swift"
        case .directory: return "folder.fill"
        case .resource: return "photo"
        case .config: return "gearshape.fill"
        case .test: return "checkmark.shield.fill"
        case .unknown: return "doc"
        }
    }
}

struct CodeFileNode: Identifiable {
    let id: UUID
    var name: String
    var path: String
    var type: FileNodeType
    var lineCount: Int
    var imports: [String]
    var dependencies: [UUID]
    var isHighlighted: Bool = false
    var complexity: Int = 0
}

struct CodeDependencyEdge: Identifiable {
    let id: UUID
    var sourceId: UUID
    var targetId: UUID
    var edgeType: DependencyType
    var isActive: Bool = false
}

enum DependencyType: String, CaseIterable {
    case importDependency = "import"
    case inheritance = "inheritance"
    case protocolConformance = "protocol"
    case functionCall = "call"

    var hexColor: String {
        switch self {
        case .importDependency: return "#64B5F6"
        case .inheritance: return "#FFB74D"
        case .protocolConformance: return "#81C784"
        case .functionCall: return "#E57373"
        }
    }
}

struct FunctionCallChain: Identifiable {
    let id: UUID
    var callerFile: String
    var callerFunction: String
    var calleeFile: String
    var calleeFunction: String
    var callCount: Int = 1
}

struct CodeKnowledgeGraphStats {
    var totalFiles: Int = 0
    var totalDependencies: Int = 0
    var totalFunctions: Int = 0
    var avgComplexity: Double = 0
    var mostConnectedFile: String = ""
}
