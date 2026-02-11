import Foundation

enum SceneTheme: String, Codable, CaseIterable, Identifiable {
    case commandCenter
    case floatingIslands
    case dungeon
    case spaceStation
    case cyberpunkCity
    case medievalCastle
    case underwaterLab
    case japaneseGarden
    case minecraftOverworld

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commandCenter: return "Command Center"
        case .floatingIslands: return "Floating Islands"
        case .dungeon: return "Dungeon"
        case .spaceStation: return "Space Station"
        case .cyberpunkCity: return "Cyberpunk City"
        case .medievalCastle: return "Medieval Castle"
        case .underwaterLab: return "Underwater Lab"
        case .japaneseGarden: return "Japanese Garden"
        case .minecraftOverworld: return "Minecraft Overworld"
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
        case .cyberpunkCity:
            return "Neon-lit streets with holographic billboards and rain-soaked alleys."
        case .medievalCastle:
            return "A grand throne room with stone walls, banners, and knight agents."
        case .underwaterLab:
            return "A submarine research base with bubbles, fish, and bioluminescent glow."
        case .japaneseGarden:
            return "A serene zen garden with cherry blossoms, stone lanterns, and koi ponds."
        case .minecraftOverworld:
            return "A classic voxel terrain with grass blocks, trees, and pixelated skies."
        }
    }

    @MainActor func localizedName(_ l: LocalizationManager) -> String {
        switch self {
        case .commandCenter: return l.localized(.themeCommandCenter)
        case .floatingIslands: return l.localized(.themeFloatingIslands)
        case .dungeon: return l.localized(.themeDungeon)
        case .spaceStation: return l.localized(.themeSpaceStation)
        case .cyberpunkCity: return l.localized(.themeCyberpunkCity)
        case .medievalCastle: return l.localized(.themeMedievalCastle)
        case .underwaterLab: return l.localized(.themeUnderwaterLab)
        case .japaneseGarden: return l.localized(.themeJapaneseGarden)
        case .minecraftOverworld: return l.localized(.themeMinecraftOverworld)
        }
    }

    @MainActor func localizedDescription(_ l: LocalizationManager) -> String {
        switch self {
        case .commandCenter: return l.localized(.themeCommandCenterDesc)
        case .floatingIslands: return l.localized(.themeFloatingIslandsDesc)
        case .dungeon: return l.localized(.themeDungeonDesc)
        case .spaceStation: return l.localized(.themeSpaceStationDesc)
        case .cyberpunkCity: return l.localized(.themeCyberpunkCityDesc)
        case .medievalCastle: return l.localized(.themeMedievalCastleDesc)
        case .underwaterLab: return l.localized(.themeUnderwaterLabDesc)
        case .japaneseGarden: return l.localized(.themeJapaneseGardenDesc)
        case .minecraftOverworld: return l.localized(.themeMinecraftOverworldDesc)
        }
    }

    var iconSystemName: String {
        switch self {
        case .commandCenter: return "desktopcomputer"
        case .floatingIslands: return "cloud.fill"
        case .dungeon: return "flame.fill"
        case .spaceStation: return "sparkles"
        case .cyberpunkCity: return "building.2.fill"
        case .medievalCastle: return "building.columns.fill"
        case .underwaterLab: return "drop.fill"
        case .japaneseGarden: return "leaf.fill"
        case .minecraftOverworld: return "cube.fill"
        }
    }

    var previewGradientColors: (String, String) {
        switch self {
        case .commandCenter: return ("#1A1A2E", "#0F3460")
        case .floatingIslands: return ("#87CEEB", "#228B22")
        case .dungeon: return ("#2C1810", "#8B4513")
        case .spaceStation: return ("#0B0B2B", "#4A0E8F")
        case .cyberpunkCity: return ("#0D0221", "#FF2A6D")
        case .medievalCastle: return ("#2C1810", "#8B7355")
        case .underwaterLab: return ("#001B3A", "#0077B6")
        case .japaneseGarden: return ("#2D1B2E", "#FFB7C5")
        case .minecraftOverworld: return ("#5B8731", "#78B9E0")
        }
    }
}
