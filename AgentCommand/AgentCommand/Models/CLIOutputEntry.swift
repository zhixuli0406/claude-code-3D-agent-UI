import Foundation

/// A single log entry from the CLI process
struct CLIOutputEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let kind: Kind
    let text: String

    enum Kind: String, Codable {
        case assistantThinking
        case toolInvocation
        case toolOutput
        case finalResult
        case error
        case systemInfo
        case dangerousWarning
        case askQuestion
        case planMode
    }

    init(id: UUID = UUID(), timestamp: Date, kind: Kind, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.text = text
    }
}
