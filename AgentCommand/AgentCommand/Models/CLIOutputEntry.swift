import Foundation

/// A single log entry from the CLI process
struct CLIOutputEntry: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let kind: Kind
    let text: String

    enum Kind {
        case assistantThinking
        case toolInvocation
        case toolOutput
        case finalResult
        case error
        case systemInfo
    }
}
