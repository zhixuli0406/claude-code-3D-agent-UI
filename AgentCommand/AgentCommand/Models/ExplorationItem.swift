import Foundation
import SceneKit

// MARK: - Exploration Item Types

enum ExplorationItemType: String, Codable {
    case easterEgg
    case loreItem
}

struct ExplorationItem: Identifiable, Codable {
    let id: String          // Stable string ID for persistence (e.g. "cc-egg-terminal")
    let type: ExplorationItemType
    let themeId: String     // SceneTheme rawValue
    let position: ScenePosition
    let title: String
    let description: String
    let icon: String        // SF Symbol name
    let coinReward: Int
}

// MARK: - Fog of War

struct MiniMapRegion {
    let width: Float
    let depth: Float
    let cellSize: Float = 2.0

    var gridWidth: Int { max(1, Int(ceil(width / cellSize))) }
    var gridDepth: Int { max(1, Int(ceil(depth / cellSize))) }

    func gridCoords(for position: SCNVector3) -> (x: Int, z: Int) {
        let x = Int(floor((Float(position.x) + width / 2) / cellSize))
        let z = Int(floor((Float(position.z) + depth / 2) / cellSize))
        return (clamp(x, 0, gridWidth - 1), clamp(z, 0, gridDepth - 1))
    }

    func gridCoordsFromScene(x: Float, z: Float) -> (gx: Int, gz: Int) {
        let gx = Int(floor((x + width / 2) / cellSize))
        let gz = Int(floor((z + depth / 2) / cellSize))
        return (clamp(gx, 0, gridWidth - 1), clamp(gz, 0, gridDepth - 1))
    }

    /// Normalize a world position to 0..1 range for minimap rendering
    func normalized(x: Float, z: Float) -> (nx: CGFloat, nz: CGFloat) {
        let nx = CGFloat((x + width / 2) / width)
        let nz = CGFloat((z + depth / 2) / depth)
        return (min(max(nx, 0), 1), min(max(nz, 0), 1))
    }

    private func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        max(low, min(high, value))
    }
}

// MARK: - Exploration Catalog

struct ExplorationCatalog {
    static func items(for theme: String) -> [ExplorationItem] {
        switch theme {
        case "commandCenter":
            return commandCenterItems
        case "floatingIslands":
            return floatingIslandsItems
        case "dungeon":
            return dungeonItems
        case "spaceStation":
            return spaceStationItems
        default:
            return []
        }
    }

    private static let commandCenterItems: [ExplorationItem] = [
        ExplorationItem(
            id: "cc-egg-terminal",
            type: .easterEgg,
            themeId: "commandCenter",
            position: ScenePosition(x: -8, y: 0.5, z: -5, rotation: 0),
            title: "Hidden Terminal",
            description: "An ancient CLI terminal still running mysterious code from the first AI agents...",
            icon: "terminal.fill",
            coinReward: 50
        ),
        ExplorationItem(
            id: "cc-lore-blueprint",
            type: .loreItem,
            themeId: "commandCenter",
            position: ScenePosition(x: 7, y: 0.5, z: 6, rotation: 0),
            title: "Founding Blueprint",
            description: "The original design document for the Agent Command system, dated 2025. It reads: 'One day, agents will build software autonomously.'",
            icon: "doc.text.fill",
            coinReward: 30
        ),
        ExplorationItem(
            id: "cc-egg-coffee",
            type: .easterEgg,
            themeId: "commandCenter",
            position: ScenePosition(x: -6, y: 0.5, z: 5, rotation: 0),
            title: "Infinite Coffee Machine",
            description: "A coffee machine that never runs out. The secret fuel of all great engineers.",
            icon: "cup.and.saucer.fill",
            coinReward: 40
        ),
    ]

    private static let floatingIslandsItems: [ExplorationItem] = [
        ExplorationItem(
            id: "fi-egg-skywhale",
            type: .easterEgg,
            themeId: "floatingIslands",
            position: ScenePosition(x: -7, y: 0.5, z: -4, rotation: 0),
            title: "Sky Whale Statue",
            description: "A miniature statue of the legendary sky whale that guides lost agents through the clouds.",
            icon: "cloud.fill",
            coinReward: 50
        ),
        ExplorationItem(
            id: "fi-lore-journal",
            type: .loreItem,
            themeId: "floatingIslands",
            position: ScenePosition(x: 6, y: 0.5, z: 5, rotation: 0),
            title: "Cloud Journal",
            description: "A journal left by a previous agent: 'The islands remember every task completed upon them.'",
            icon: "book.closed.fill",
            coinReward: 30
        ),
        ExplorationItem(
            id: "fi-egg-rainbow",
            type: .easterEgg,
            themeId: "floatingIslands",
            position: ScenePosition(x: 5, y: 0.5, z: -6, rotation: 0),
            title: "Rainbow Bridge Fragment",
            description: "A crystallized piece of the mythical bridge that once connected all floating islands.",
            icon: "rainbow",
            coinReward: 40
        ),
    ]

    private static let dungeonItems: [ExplorationItem] = [
        ExplorationItem(
            id: "dg-egg-chest",
            type: .easterEgg,
            themeId: "dungeon",
            position: ScenePosition(x: -6, y: 0.5, z: -6, rotation: 0),
            title: "Ancient Treasure Chest",
            description: "A treasure chest containing legendary debugging tools from the old masters of code.",
            icon: "shippingbox.fill",
            coinReward: 75
        ),
        ExplorationItem(
            id: "dg-lore-tablet",
            type: .loreItem,
            themeId: "dungeon",
            position: ScenePosition(x: 6, y: 0.5, z: 5, rotation: 0),
            title: "Stone Tablet",
            description: "Ancient wisdom carved in stone: 'Always test your changes before deploying to production.'",
            icon: "text.below.photo.fill",
            coinReward: 30
        ),
        ExplorationItem(
            id: "dg-egg-skull",
            type: .easterEgg,
            themeId: "dungeon",
            position: ScenePosition(x: -5, y: 0.5, z: 4, rotation: 0),
            title: "Glowing Crystal Skull",
            description: "A skull made of pure crystal that glows with the wisdom of a thousand resolved merge conflicts.",
            icon: "sparkle",
            coinReward: 40
        ),
    ]

    private static let spaceStationItems: [ExplorationItem] = [
        ExplorationItem(
            id: "ss-egg-alien",
            type: .easterEgg,
            themeId: "spaceStation",
            position: ScenePosition(x: -7, y: 0.5, z: -5, rotation: 0),
            title: "Alien Artifact",
            description: "A mysterious device left by an advanced AI civilization. It hums with infinite computational power.",
            icon: "star.fill",
            coinReward: 100
        ),
        ExplorationItem(
            id: "ss-lore-captainlog",
            type: .loreItem,
            themeId: "spaceStation",
            position: ScenePosition(x: 7, y: 0.5, z: 6, rotation: 0),
            title: "Captain's Log",
            description: "The last entry: 'The agents are learning faster than we ever imagined. Soon they won't need us at all.'",
            icon: "text.book.closed.fill",
            coinReward: 40
        ),
        ExplorationItem(
            id: "ss-egg-blackhole",
            type: .easterEgg,
            themeId: "spaceStation",
            position: ScenePosition(x: -5, y: 0.5, z: 5, rotation: 0),
            title: "Miniature Black Hole",
            description: "A contained singularity that consumes bugs and outputs clean code.",
            icon: "circle.inset.filled",
            coinReward: 50
        ),
    ]
}
