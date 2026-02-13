import Foundation

// MARK: - L4: MCP (Model Context Protocol) Integration Models

enum MCPServerStatus: String, CaseIterable {
    case connected = "connected"
    case disconnected = "disconnected"
    case connecting = "connecting"
    case error = "error"

    var hexColor: String {
        switch self {
        case .connected: return "#4CAF50"
        case .disconnected: return "#9E9E9E"
        case .connecting: return "#FF9800"
        case .error: return "#F44336"
        }
    }

    var iconName: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "circle"
        case .connecting: return "arrow.clockwise"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

enum MCPToolCategory: String, CaseIterable, Identifiable {
    case fileSystem = "file_system"
    case webBrowser = "web_browser"
    case codeExecution = "code_execution"
    case database = "database"
    case apiIntegration = "api_integration"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fileSystem: return "File System"
        case .webBrowser: return "Web Browser"
        case .codeExecution: return "Code Execution"
        case .database: return "Database"
        case .apiIntegration: return "API Integration"
        case .custom: return "Custom"
        }
    }

    var iconName: String {
        switch self {
        case .fileSystem: return "folder"
        case .webBrowser: return "globe"
        case .codeExecution: return "terminal"
        case .database: return "cylinder"
        case .apiIntegration: return "network"
        case .custom: return "puzzlepiece"
        }
    }
}

struct MCPServer: Identifiable {
    let id: UUID
    var name: String
    var url: String
    var status: MCPServerStatus
    var tools: [MCPTool]
    var connectedAt: Date?
    var lastPingAt: Date?
    var version: String
    var description: String
    var isAutoConnect: Bool
}

struct MCPTool: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var category: MCPToolCategory
    var inputSchema: String?
    var callCount: Int
    var avgResponseTime: TimeInterval
    var lastCalledAt: Date?
    var isEnabled: Bool
    var serverId: UUID
}

struct MCPToolCall: Identifiable {
    let id: UUID
    var toolId: UUID
    var toolName: String
    var serverName: String
    var input: String
    var output: String?
    var status: MCPServerStatus
    var calledAt: Date
    var duration: TimeInterval?
    var tokenCost: Int
}

struct MCPStats {
    var totalServers: Int = 0
    var connectedServers: Int = 0
    var totalTools: Int = 0
    var enabledTools: Int = 0
    var totalCalls: Int = 0
    var avgResponseTime: TimeInterval = 0
    var topTools: [(name: String, count: Int)] = []
}
