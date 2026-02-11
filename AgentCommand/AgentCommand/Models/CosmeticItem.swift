import Foundation

// MARK: - Cosmetic Categories

enum CosmeticCategory: String, Codable, CaseIterable {
    case skin       // Full body color themes
    case hat        // Head accessories
    case particle   // Particle trail effects
    case title      // Name tags / titles
    case seasonal   // Limited seasonal items

    var displayName: String {
        switch self {
        case .skin: return "Skins"
        case .hat: return "Hats"
        case .particle: return "Effects"
        case .title: return "Titles"
        case .seasonal: return "Seasonal"
        }
    }

    var icon: String {
        switch self {
        case .skin: return "paintbrush.fill"
        case .hat: return "crown.fill"
        case .particle: return "sparkles"
        case .title: return "tag.fill"
        case .seasonal: return "gift.fill"
        }
    }
}

// MARK: - Cosmetic Item

struct CosmeticItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: CosmeticCategory
    let price: Int
    let icon: String
    let rarity: CosmeticRarity
    let seasonalEvent: SeasonalEvent?

    /// For skins: color hex values
    let skinColors: SkinColorSet?
    /// For hats: references an Accessory-like build
    let hatStyle: CosmeticHatStyle?
    /// For particles: particle color
    let particleColorHex: String?
    /// For titles: the title text
    let titleText: String?

    var isAvailable: Bool {
        guard let event = seasonalEvent else { return true }
        return event.isActive
    }
}

enum CosmeticRarity: String, Codable, CaseIterable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var color: String {
        switch self {
        case .common: return "#B0BEC5"
        case .uncommon: return "#4CAF50"
        case .rare: return "#2196F3"
        case .epic: return "#9C27B0"
        case .legendary: return "#FFD700"
        }
    }

    var priceMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.5
        case .rare: return 2.5
        case .epic: return 4.0
        case .legendary: return 7.0
        }
    }
}

// MARK: - Skin Color Set

struct SkinColorSet: Codable, Hashable {
    let skinColor: String
    let shirtColor: String
    let pantsColor: String
    let hairColor: String
}

// MARK: - Hat Styles

enum CosmeticHatStyle: String, Codable, CaseIterable {
    case topHat
    case wizardHat
    case santaHat
    case bunnyEars
    case pirateHat
    case halo
    case devilHorns
    case samuraiHelmet
    case partyHat
    case pumpkinHead
}

// MARK: - Seasonal Events

enum SeasonalEvent: String, Codable, CaseIterable {
    case lunarNewYear      // Jan-Feb
    case valentines        // Feb
    case easter            // Mar-Apr
    case summer            // Jun-Aug
    case halloween         // Oct
    case christmas         // Dec

    var displayName: String {
        switch self {
        case .lunarNewYear: return "Lunar New Year"
        case .valentines: return "Valentine's Day"
        case .easter: return "Easter"
        case .summer: return "Summer Splash"
        case .halloween: return "Halloween"
        case .christmas: return "Winter Holiday"
        }
    }

    var icon: String {
        switch self {
        case .lunarNewYear: return "sparkles"
        case .valentines: return "heart.fill"
        case .easter: return "hare.fill"
        case .summer: return "sun.max.fill"
        case .halloween: return "theatermasks.fill"
        case .christmas: return "snowflake"
        }
    }

    var isActive: Bool {
        let month = Calendar.current.component(.month, from: Date())
        switch self {
        case .lunarNewYear: return month == 1 || month == 2
        case .valentines: return month == 2
        case .easter: return month == 3 || month == 4
        case .summer: return month >= 6 && month <= 8
        case .halloween: return month == 10
        case .christmas: return month == 12
        }
    }
}

// MARK: - Cosmetic Catalog

struct CosmeticCatalog {

    static let allItems: [CosmeticItem] = skins + hats + particles + titles + seasonalItems

    // MARK: - Skins

    static let skins: [CosmeticItem] = [
        CosmeticItem(
            id: "skin_midnight", name: "Midnight", description: "Dark stealth outfit",
            category: .skin, price: 100, icon: "moon.fill", rarity: .common, seasonalEvent: nil,
            skinColors: SkinColorSet(skinColor: "#2C3E50", shirtColor: "#1A1A2E", pantsColor: "#16213E", hairColor: "#0F3460"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "skin_forest", name: "Forest Ranger", description: "Natural woodland colors",
            category: .skin, price: 100, icon: "leaf.fill", rarity: .common, seasonalEvent: nil,
            skinColors: SkinColorSet(skinColor: "#D7CCC8", shirtColor: "#2E7D32", pantsColor: "#4E342E", hairColor: "#33691E"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "skin_ocean", name: "Deep Ocean", description: "Aquatic blue theme",
            category: .skin, price: 150, icon: "drop.fill", rarity: .uncommon, seasonalEvent: nil,
            skinColors: SkinColorSet(skinColor: "#B3E5FC", shirtColor: "#0277BD", pantsColor: "#01579B", hairColor: "#006064"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "skin_cyber", name: "Cyberpunk", description: "Neon-infused futuristic look",
            category: .skin, price: 250, icon: "bolt.fill", rarity: .rare, seasonalEvent: nil,
            skinColors: SkinColorSet(skinColor: "#E0E0E0", shirtColor: "#E91E63", pantsColor: "#212121", hairColor: "#00E5FF"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "skin_golden", name: "Golden Agent", description: "Prestigious golden outfit",
            category: .skin, price: 500, icon: "star.fill", rarity: .epic, seasonalEvent: nil,
            skinColors: SkinColorSet(skinColor: "#FFF8E1", shirtColor: "#FFD700", pantsColor: "#F9A825", hairColor: "#FF8F00"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "skin_phantom", name: "Phantom", description: "Ethereal ghostly appearance",
            category: .skin, price: 800, icon: "wand.and.stars", rarity: .legendary, seasonalEvent: nil,
            skinColors: SkinColorSet(skinColor: "#E8EAF6", shirtColor: "#7C4DFF", pantsColor: "#311B92", hairColor: "#B388FF"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
    ]

    // MARK: - Hats

    static let hats: [CosmeticItem] = [
        CosmeticItem(
            id: "hat_tophat", name: "Top Hat", description: "A classy gentleman's hat",
            category: .hat, price: 120, icon: "crown.fill", rarity: .common, seasonalEvent: nil,
            skinColors: nil, hatStyle: .topHat, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "hat_wizard", name: "Wizard Hat", description: "Channel your inner sorcerer",
            category: .hat, price: 200, icon: "wand.and.stars", rarity: .uncommon, seasonalEvent: nil,
            skinColors: nil, hatStyle: .wizardHat, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "hat_pirate", name: "Pirate Hat", description: "Arr, matey! A fearsome captain's hat",
            category: .hat, price: 200, icon: "flag.fill", rarity: .uncommon, seasonalEvent: nil,
            skinColors: nil, hatStyle: .pirateHat, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "hat_halo", name: "Halo", description: "A radiant ring of light",
            category: .hat, price: 350, icon: "sun.max.fill", rarity: .rare, seasonalEvent: nil,
            skinColors: nil, hatStyle: .halo, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "hat_devil", name: "Devil Horns", description: "Devilishly stylish horns",
            category: .hat, price: 350, icon: "flame.fill", rarity: .rare, seasonalEvent: nil,
            skinColors: nil, hatStyle: .devilHorns, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "hat_samurai", name: "Samurai Helmet", description: "An honorable warrior's kabuto",
            category: .hat, price: 600, icon: "shield.fill", rarity: .epic, seasonalEvent: nil,
            skinColors: nil, hatStyle: .samuraiHelmet, particleColorHex: nil, titleText: nil
        ),
    ]

    // MARK: - Particle Effects

    static let particles: [CosmeticItem] = [
        CosmeticItem(
            id: "particle_fire", name: "Fire Trail", description: "Leave a trail of flames",
            category: .particle, price: 180, icon: "flame.fill", rarity: .uncommon, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: "#FF5722", titleText: nil
        ),
        CosmeticItem(
            id: "particle_ice", name: "Ice Crystals", description: "Shimmering frost particles",
            category: .particle, price: 180, icon: "snowflake", rarity: .uncommon, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: "#00BCD4", titleText: nil
        ),
        CosmeticItem(
            id: "particle_hearts", name: "Heart Aura", description: "Floating hearts around you",
            category: .particle, price: 250, icon: "heart.fill", rarity: .rare, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: "#E91E63", titleText: nil
        ),
        CosmeticItem(
            id: "particle_lightning", name: "Lightning Storm", description: "Crackling electric energy",
            category: .particle, price: 400, icon: "bolt.fill", rarity: .epic, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: "#FFEB3B", titleText: nil
        ),
        CosmeticItem(
            id: "particle_rainbow", name: "Rainbow Trail", description: "A dazzling spectrum of colors",
            category: .particle, price: 700, icon: "rainbow", rarity: .legendary, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: "#FF6F00", titleText: nil
        ),
    ]

    // MARK: - Titles

    static let titles: [CosmeticItem] = [
        CosmeticItem(
            id: "title_rookie", name: "Rookie", description: "Fresh out of training",
            category: .title, price: 50, icon: "person.fill", rarity: .common, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: nil, titleText: "Rookie"
        ),
        CosmeticItem(
            id: "title_veteran", name: "Veteran", description: "Battle-tested and proven",
            category: .title, price: 150, icon: "medal.fill", rarity: .uncommon, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: nil, titleText: "Veteran"
        ),
        CosmeticItem(
            id: "title_elite", name: "Elite", description: "Top-tier agent status",
            category: .title, price: 300, icon: "star.circle.fill", rarity: .rare, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: nil, titleText: "Elite"
        ),
        CosmeticItem(
            id: "title_legendary", name: "Legend", description: "A living legend among agents",
            category: .title, price: 500, icon: "crown.fill", rarity: .epic, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: nil, titleText: "Legend"
        ),
        CosmeticItem(
            id: "title_supreme", name: "Supreme Commander", description: "The ultimate authority",
            category: .title, price: 1000, icon: "bolt.shield.fill", rarity: .legendary, seasonalEvent: nil,
            skinColors: nil, hatStyle: nil, particleColorHex: nil, titleText: "Supreme Commander"
        ),
    ]

    // MARK: - Seasonal Items

    static let seasonalItems: [CosmeticItem] = [
        // Lunar New Year
        CosmeticItem(
            id: "seasonal_dragon", name: "Dragon Dance", description: "Celebrate with fiery dragon particles",
            category: .seasonal, price: 300, icon: "flame.fill", rarity: .rare, seasonalEvent: .lunarNewYear,
            skinColors: nil, hatStyle: nil, particleColorHex: "#F44336", titleText: nil
        ),
        CosmeticItem(
            id: "seasonal_lantern_skin", name: "Lantern Festival", description: "Red and gold festive outfit",
            category: .seasonal, price: 250, icon: "sparkles", rarity: .rare, seasonalEvent: .lunarNewYear,
            skinColors: SkinColorSet(skinColor: "#FFECB3", shirtColor: "#D32F2F", pantsColor: "#B71C1C", hairColor: "#212121"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        // Valentine's
        CosmeticItem(
            id: "seasonal_valentine_hat", name: "Cupid's Crown", description: "A heart-shaped crown of love",
            category: .seasonal, price: 200, icon: "heart.fill", rarity: .uncommon, seasonalEvent: .valentines,
            skinColors: nil, hatStyle: .partyHat, particleColorHex: nil, titleText: nil
        ),
        // Easter
        CosmeticItem(
            id: "seasonal_bunny", name: "Bunny Ears", description: "Hop into Easter with style",
            category: .seasonal, price: 200, icon: "hare.fill", rarity: .uncommon, seasonalEvent: .easter,
            skinColors: nil, hatStyle: .bunnyEars, particleColorHex: nil, titleText: nil
        ),
        // Summer
        CosmeticItem(
            id: "seasonal_beach_skin", name: "Beach Vibes", description: "Cool summer outfit",
            category: .seasonal, price: 200, icon: "sun.max.fill", rarity: .uncommon, seasonalEvent: .summer,
            skinColors: SkinColorSet(skinColor: "#FFCC80", shirtColor: "#00BCD4", pantsColor: "#FFF176", hairColor: "#FF8A65"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        // Halloween
        CosmeticItem(
            id: "seasonal_pumpkin", name: "Pumpkin Head", description: "Spooky jack-o-lantern headgear",
            category: .seasonal, price: 300, icon: "theatermasks.fill", rarity: .rare, seasonalEvent: .halloween,
            skinColors: nil, hatStyle: .pumpkinHead, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "seasonal_ghost_skin", name: "Ghost Agent", description: "Spooky translucent appearance",
            category: .seasonal, price: 400, icon: "theatermasks.fill", rarity: .epic, seasonalEvent: .halloween,
            skinColors: SkinColorSet(skinColor: "#ECEFF1", shirtColor: "#CFD8DC", pantsColor: "#B0BEC5", hairColor: "#90A4AE"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
        // Christmas
        CosmeticItem(
            id: "seasonal_santa", name: "Santa Hat", description: "Ho ho ho! Festive Santa hat",
            category: .seasonal, price: 250, icon: "snowflake", rarity: .rare, seasonalEvent: .christmas,
            skinColors: nil, hatStyle: .santaHat, particleColorHex: nil, titleText: nil
        ),
        CosmeticItem(
            id: "seasonal_xmas_skin", name: "Elf Outfit", description: "Santa's little helper",
            category: .seasonal, price: 350, icon: "gift.fill", rarity: .epic, seasonalEvent: .christmas,
            skinColors: SkinColorSet(skinColor: "#FFECB3", shirtColor: "#2E7D32", pantsColor: "#D32F2F", hairColor: "#4E342E"),
            hatStyle: nil, particleColorHex: nil, titleText: nil
        ),
    ]

    static func item(byId id: String) -> CosmeticItem? {
        allItems.first { $0.id == id }
    }

    static func items(for category: CosmeticCategory) -> [CosmeticItem] {
        allItems.filter { $0.category == category }
    }

    static func availableItems() -> [CosmeticItem] {
        allItems.filter { $0.isAvailable }
    }

    static func availableSeasonalItems() -> [CosmeticItem] {
        seasonalItems.filter { $0.isAvailable }
    }
}
