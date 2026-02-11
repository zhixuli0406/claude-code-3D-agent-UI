import Foundation

struct SceneThemeBuilderFactory {
    static func builder(for theme: SceneTheme) -> SceneThemeBuilder {
        switch theme {
        case .commandCenter: return CommandCenterThemeBuilder()
        case .floatingIslands: return FloatingIslandsThemeBuilder()
        case .dungeon: return DungeonThemeBuilder()
        case .spaceStation: return SpaceStationThemeBuilder()
        case .cyberpunkCity: return CyberpunkCityThemeBuilder()
        case .medievalCastle: return MedievalCastleThemeBuilder()
        case .underwaterLab: return UnderwaterLabThemeBuilder()
        case .japaneseGarden: return JapaneseGardenThemeBuilder()
        case .minecraftOverworld: return MinecraftOverworldThemeBuilder()
        }
    }
}
