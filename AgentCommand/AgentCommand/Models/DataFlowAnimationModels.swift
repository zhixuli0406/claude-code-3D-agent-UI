import Foundation

// MARK: - J4: Data Flow Animation Models

enum DataFlowType: String, CaseIterable, Identifiable {
    case tokenStream = "token_stream"
    case promptSend = "prompt_send"
    case responseReceive = "response_receive"
    case toolCall = "tool_call"
    case fileRead = "file_read"
    case fileWrite = "file_write"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tokenStream: return "Token Stream"
        case .promptSend: return "Prompt Send"
        case .responseReceive: return "Response Receive"
        case .toolCall: return "Tool Call"
        case .fileRead: return "File Read"
        case .fileWrite: return "File Write"
        }
    }

    var hexColor: String {
        switch self {
        case .tokenStream: return "#00BCD4"
        case .promptSend: return "#4CAF50"
        case .responseReceive: return "#FF9800"
        case .toolCall: return "#E91E63"
        case .fileRead: return "#64B5F6"
        case .fileWrite: return "#FF7043"
        }
    }

    var iconName: String {
        switch self {
        case .tokenStream: return "waveform.path"
        case .promptSend: return "arrow.up.circle.fill"
        case .responseReceive: return "arrow.down.circle.fill"
        case .toolCall: return "wrench.and.screwdriver.fill"
        case .fileRead: return "doc.text.fill"
        case .fileWrite: return "doc.text.fill"
        }
    }
}

struct TokenFlowEvent: Identifiable {
    let id: UUID
    var agentId: UUID
    var flowType: DataFlowType
    var tokenCount: Int
    var timestamp: Date
    var isActive: Bool = true
    var duration: TimeInterval = 0
}

struct IOPipelineStage: Identifiable {
    let id: UUID
    var name: String
    var flowType: DataFlowType
    var status: PipelineStageStatus
    var dataSize: Int
    var startedAt: Date?
    var completedAt: Date?
}

enum PipelineStageStatus: String, CaseIterable {
    case pending = "pending"
    case active = "active"
    case completed = "completed"
    case error = "error"

    var hexColor: String {
        switch self {
        case .pending: return "#9E9E9E"
        case .active: return "#2196F3"
        case .completed: return "#4CAF50"
        case .error: return "#F44336"
        }
    }
}

struct ToolCallChainEntry: Identifiable {
    let id: UUID
    var agentId: UUID
    var toolName: String
    var input: String
    var output: String?
    var duration: TimeInterval?
    var timestamp: Date
    var sequenceIndex: Int
}

struct DataFlowStats {
    var totalTokensIn: Int = 0
    var totalTokensOut: Int = 0
    var totalToolCalls: Int = 0
    var avgResponseTime: TimeInterval = 0
    var activeFlows: Int = 0
}
