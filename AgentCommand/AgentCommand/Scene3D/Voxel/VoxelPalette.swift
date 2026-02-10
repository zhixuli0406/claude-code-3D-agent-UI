import AppKit

/// Maps integer color keys to NSColor for voxel grid rendering
struct VoxelPalette {
    private let colors: [Int: NSColor]

    init(from appearance: VoxelAppearance) {
        colors = [
            1: NSColor(hex: appearance.skinColor),      // Skin
            2: NSColor(hex: appearance.shirtColor),      // Shirt
            3: NSColor(hex: appearance.pantsColor),       // Pants
            4: NSColor(hex: appearance.hairColor),        // Hair
            5: NSColor(hex: "#FFFFFF"),                   // Eyes (white)
            6: NSColor(hex: "#1A1A1A"),                   // Eyes (pupil)
            7: NSColor(hex: "#FF4081"),                   // Mouth
            8: NSColor(hex: "#795548"),                   // Shoes
            9: NSColor(hex: "#90A4AE"),                   // Glasses / accessory
        ]
    }

    func color(for key: Int) -> NSColor {
        colors[key] ?? NSColor.magenta
    }
}

/// Predefined color schemes for quick character creation
struct VoxelPalettePresets {
    static let commander = VoxelAppearance(
        skinColor: "#FFCC99", shirtColor: "#1A237E",
        pantsColor: "#37474F", hairColor: "#3E2723",
        hairStyle: .short, accessory: .headphones
    )

    static let developer = VoxelAppearance(
        skinColor: "#FFCC99", shirtColor: "#1B5E20",
        pantsColor: "#263238", hairColor: "#212121",
        hairStyle: .mohawk, accessory: .glasses
    )

    static let researcher = VoxelAppearance(
        skinColor: "#D2A679", shirtColor: "#4A148C",
        pantsColor: "#1A237E", hairColor: "#F5F5F5",
        hairStyle: .long, accessory: .glasses
    )
}
