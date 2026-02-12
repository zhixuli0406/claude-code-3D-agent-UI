import Foundation

enum ClaudeModel: String, Codable, CaseIterable, Identifiable, Hashable {
    case opus = "claude-opus-4-6"
    case sonnet = "claude-sonnet-4-5-20250929"
    case haiku = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        }
    }

    @MainActor func localizedName(_ l: LocalizationManager) -> String {
        switch self {
        case .opus: return l.localized(.modelOpus)
        case .sonnet: return l.localized(.modelSonnet)
        case .haiku: return l.localized(.modelHaiku)
        }
    }

    var hexColor: String {
        switch self {
        case .opus: return "#D4A017"
        case .sonnet: return "#7C4DFF"
        case .haiku: return "#00BCD4"
        }
    }

    /// The CLI flag value passed to `claude --model`
    var cliModelId: String { rawValue }

    /// Sort order for display (most capable first)
    var sortOrder: Int {
        switch self {
        case .opus: return 3
        case .sonnet: return 2
        case .haiku: return 1
        }
    }

    @MainActor func localizedDescription(_ l: LocalizationManager) -> String {
        switch self {
        case .opus: return l.localized(.modelOpusDesc)
        case .sonnet: return l.localized(.modelSonnetDesc)
        case .haiku: return l.localized(.modelHaikuDesc)
        }
    }
}
