import Foundation

/// Maps CLI tool names to SF Symbol icon identifiers
enum ToolIcon: String {
    case fileRead = "doc.text"
    case codeWrite = "chevron.left.forwardslash.chevron.right"
    case terminal = "terminal"
    case webSearch = "globe"
    case search = "magnifyingglass"
    case unknown = "wrench"

    /// Infer the appropriate icon from a tool name string
    static func from(toolName: String) -> ToolIcon {
        let lower = toolName.lowercased()
        switch lower {
        case let t where t.contains("read"):
            return .fileRead
        case let t where t.contains("write") || t.contains("edit") || t.contains("notebookedit"):
            return .codeWrite
        case let t where t.contains("bash"):
            return .terminal
        case let t where t.contains("webfetch") || t.contains("websearch"):
            return .webSearch
        case let t where t.contains("glob") || t.contains("grep"):
            return .search
        default:
            return .unknown
        }
    }
}
