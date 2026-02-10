import Foundation

enum SceneTheme: String, Codable, CaseIterable, Identifiable {
    case commandCenter
    case floatingIslands
    case dungeon
    case spaceStation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commandCenter: return "Command Center"
        case .floatingIslands: return "Floating Islands"
        case .dungeon: return "Dungeon"
        case .spaceStation: return "Space Station"
        }
    }

    var description: String {
        switch self {
        case .commandCenter:
            return "A dark-themed hi-tech office with monitors, desks, and neon accents."
        case .floatingIslands:
            return "Voxel islands floating in the sky, connected by bridges among the clouds."
        case .dungeon:
            return "An underground stone dungeon with torch lighting and treasure chests."
        case .spaceStation:
            return "A metallic orbital station with holographic displays and starfield views."
        }
    }

    var iconSystemName: String {
        switch self {
        case .commandCenter: return "desktopcomputer"
        case .floatingIslands: return "cloud.fill"
        case .dungeon: return "flame.fill"
        case .spaceStation: return "sparkles"
        }
    }

    var previewGradientColors: (String, String) {
        switch self {
        case .commandCenter: return ("#1A1A2E", "#0F3460")
        case .floatingIslands: return ("#87CEEB", "#228B22")
        case .dungeon: return ("#2C1810", "#8B4513")
        case .spaceStation: return ("#0B0B2B", "#4A0E8F")
        }
    }
}
