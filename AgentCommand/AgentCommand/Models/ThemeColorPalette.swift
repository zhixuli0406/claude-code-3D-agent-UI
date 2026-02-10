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

    static func palette(for theme: SceneTheme) -> ThemeColorPalette {
        switch theme {
        case .commandCenter: return .commandCenter
        case .floatingIslands: return .floatingIslands
        case .dungeon: return .dungeon
        case .spaceStation: return .spaceStation
        }
    }
}
