import AppKit

struct ThemeColorPalette {
    let floorColor: String
    let wallColor: String
    let gridColor: String
    let accentColor: String
    let accentColorSecondary: String
    let backgroundColor: String
    let surfaceColor: String
    let structuralColor: String
    let emissionColor: String
    let connectionLineColor: String

    var accentNSColor: NSColor { NSColor(hex: accentColor) }
    var backgroundNSColor: NSColor { NSColor(hex: backgroundColor) }
}

extension ThemeColorPalette {
    static let commandCenter = ThemeColorPalette(
        floorColor: "#1A1A2E", wallColor: "#16213E",
        gridColor: "#0F3460", accentColor: "#00BCD4",
        accentColorSecondary: "#E91E63", backgroundColor: "#0A0A1A",
        surfaceColor: "#37474F", structuralColor: "#263238",
        emissionColor: "#00BCD4", connectionLineColor: "#00BCD4"
    )

    static let floatingIslands = ThemeColorPalette(
        floorColor: "#4CAF50", wallColor: "#87CEEB",
        gridColor: "#388E3C", accentColor: "#FFD700",
        accentColorSecondary: "#FF6B35", backgroundColor: "#87CEEB",
        surfaceColor: "#8B4513", structuralColor: "#6D4C41",
        emissionColor: "#FFD700", connectionLineColor: "#FFD700"
    )

    static let dungeon = ThemeColorPalette(
        floorColor: "#4A4A4A", wallColor: "#3E3E3E",
        gridColor: "#555555", accentColor: "#FF6600",
        accentColorSecondary: "#FFD700", backgroundColor: "#1A0F0A",
        surfaceColor: "#5D4E37", structuralColor: "#3E2723",
        emissionColor: "#FF6600", connectionLineColor: "#FF6600"
    )

    static let spaceStation = ThemeColorPalette(
        floorColor: "#1A1A3E", wallColor: "#252545",
        gridColor: "#2A2A5A", accentColor: "#7C4DFF",
        accentColorSecondary: "#00E5FF", backgroundColor: "#050510",
        surfaceColor: "#37374F", structuralColor: "#2A2A3E",
        emissionColor: "#7C4DFF", connectionLineColor: "#00E5FF"
    )

    static let cyberpunkCity = ThemeColorPalette(
        floorColor: "#1A0A2E", wallColor: "#0D0221",
        gridColor: "#2B1055", accentColor: "#FF2A6D",
        accentColorSecondary: "#05D9E8", backgroundColor: "#0D0221",
        surfaceColor: "#2B1055", structuralColor: "#1A0A2E",
        emissionColor: "#FF2A6D", connectionLineColor: "#05D9E8"
    )

    static let medievalCastle = ThemeColorPalette(
        floorColor: "#4A3728", wallColor: "#6B5B4F",
        gridColor: "#5C4A3A", accentColor: "#DAA520",
        accentColorSecondary: "#8B0000", backgroundColor: "#1C1008",
        surfaceColor: "#6B5B4F", structuralColor: "#4A3728",
        emissionColor: "#DAA520", connectionLineColor: "#DAA520"
    )

    static let underwaterLab = ThemeColorPalette(
        floorColor: "#0A2A3C", wallColor: "#0D3B54",
        gridColor: "#134E6F", accentColor: "#00E5FF",
        accentColorSecondary: "#76FF03", backgroundColor: "#001B2E",
        surfaceColor: "#1A4A5E", structuralColor: "#0D3B54",
        emissionColor: "#00E5FF", connectionLineColor: "#00E5FF"
    )

    static let japaneseGarden = ThemeColorPalette(
        floorColor: "#8B7355", wallColor: "#C4A882",
        gridColor: "#9E8B6E", accentColor: "#FFB7C5",
        accentColorSecondary: "#4CAF50", backgroundColor: "#2D1B2E",
        surfaceColor: "#A0522D", structuralColor: "#6B4226",
        emissionColor: "#FFB7C5", connectionLineColor: "#FFB7C5"
    )

    static let minecraftOverworld = ThemeColorPalette(
        floorColor: "#5B8731", wallColor: "#78B9E0",
        gridColor: "#4A7A2B", accentColor: "#5B8731",
        accentColorSecondary: "#78B9E0", backgroundColor: "#78B9E0",
        surfaceColor: "#8B6914", structuralColor: "#6B5B4F",
        emissionColor: "#FFD700", connectionLineColor: "#5B8731"
    )

    static func palette(for theme: SceneTheme) -> ThemeColorPalette {
        switch theme {
        case .commandCenter: return .commandCenter
        case .floatingIslands: return .floatingIslands
        case .dungeon: return .dungeon
        case .spaceStation: return .spaceStation
        case .cyberpunkCity: return .cyberpunkCity
        case .medievalCastle: return .medievalCastle
        case .underwaterLab: return .underwaterLab
        case .japaneseGarden: return .japaneseGarden
        case .minecraftOverworld: return .minecraftOverworld
        }
    }
}
