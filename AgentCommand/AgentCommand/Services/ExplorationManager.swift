import Foundation
import SceneKit

/// Manages fog of war, easter egg discovery, and lore item collection
@MainActor
class ExplorationManager: ObservableObject {
    // MARK: - Published State

    /// Per-theme fog grid: themeId -> "x,z" -> true (revealed)
    @Published var fogState: [String: [String: Bool]] = [:]

    /// Set of discovered item IDs (stable string IDs)
    @Published var discoveredItemIds: Set<String> = []

    /// Most recent discovery, triggers popup
    @Published var recentDiscovery: ExplorationItem?

    // MARK: - Storage Keys

    private let fogStorageKey = "explorationFog"
    private let discoveredStorageKey = "explorationDiscovered"

    // MARK: - Init

    init() {
        loadState()
    }

    // MARK: - Item Catalog

    func items(for theme: String) -> [ExplorationItem] {
        ExplorationCatalog.items(for: theme)
    }

    func undiscoveredItems(for theme: String) -> [ExplorationItem] {
        items(for: theme).filter { !discoveredItemIds.contains($0.id) }
    }

    func discoveredItems(for theme: String) -> [ExplorationItem] {
        items(for: theme).filter { discoveredItemIds.contains($0.id) }
    }

    // MARK: - Fog of War

    /// Reveal fog cells in a radius around a world position
    func revealFog(around position: SCNVector3, radius: Float, theme: String, roomSize: RoomDimensions) {
        let region = MiniMapRegion(width: roomSize.width, depth: roomSize.depth)
        let (centerX, centerZ) = region.gridCoords(for: position)
        let cellRadius = Int(ceil(radius / region.cellSize))

        var themeGrid = fogState[theme] ?? [:]
        for dx in -cellRadius...cellRadius {
            for dz in -cellRadius...cellRadius {
                let x = centerX + dx
                let z = centerZ + dz
                guard x >= 0, x < region.gridWidth, z >= 0, z < region.gridDepth else { continue }

                // Check actual distance (circular, not square)
                let worldDX = Float(dx) * region.cellSize
                let worldDZ = Float(dz) * region.cellSize
                if sqrt(worldDX * worldDX + worldDZ * worldDZ) <= radius {
                    themeGrid[fogKey(x: x, z: z)] = true
                }
            }
        }
        fogState[theme] = themeGrid
        saveFogState()
    }

    /// Check if a fog cell is revealed
    func isFogRevealed(gridX: Int, gridZ: Int, theme: String) -> Bool {
        fogState[theme]?[fogKey(x: gridX, z: gridZ)] ?? false
    }

    /// Calculate reveal percentage for a theme
    func fogRevealPercentage(theme: String, roomSize: RoomDimensions) -> Double {
        let region = MiniMapRegion(width: roomSize.width, depth: roomSize.depth)
        let totalCells = region.gridWidth * region.gridDepth
        guard totalCells > 0 else { return 0 }

        let revealed = fogState[theme]?.values.filter { $0 }.count ?? 0
        return Double(revealed) / Double(totalCells)
    }

    /// Initialize default fog for a theme (reveal center 3×3 area)
    func initializeDefaultFog(theme: String, roomSize: RoomDimensions) {
        // Only initialize if no fog data exists for this theme
        guard fogState[theme] == nil || fogState[theme]?.isEmpty == true else { return }

        let region = MiniMapRegion(width: roomSize.width, depth: roomSize.depth)
        let centerX = region.gridWidth / 2
        let centerZ = region.gridDepth / 2

        var themeGrid: [String: Bool] = [:]
        for dx in -1...1 {
            for dz in -1...1 {
                let x = centerX + dx
                let z = centerZ + dz
                if x >= 0, x < region.gridWidth, z >= 0, z < region.gridDepth {
                    themeGrid[fogKey(x: x, z: z)] = true
                }
            }
        }
        fogState[theme] = themeGrid
        saveFogState()
    }

    // MARK: - Discovery

    /// Check if any undiscovered item is near the given position; discover and return it
    func checkAndDiscover(near position: SCNVector3, theme: String) -> ExplorationItem? {
        let themeItems = undiscoveredItems(for: theme)
        for item in themeItems {
            let dx = item.position.x - Float(position.x)
            let dz = item.position.z - Float(position.z)
            let distance = sqrt(dx * dx + dz * dz)
            if distance < 2.0 {
                return discoverItem(item)
            }
        }
        return nil
    }

    /// Mark an item as discovered
    @discardableResult
    func discoverItem(_ item: ExplorationItem) -> ExplorationItem {
        discoveredItemIds.insert(item.id)
        recentDiscovery = item
        saveDiscoveredState()
        return item
    }

    /// Dismiss the discovery popup
    func dismissDiscovery() {
        recentDiscovery = nil
    }

    /// Total discovered items across all themes
    var totalDiscovered: Int {
        discoveredItemIds.count
    }

    /// Total items across all themes
    var totalItems: Int {
        ["commandCenter", "floatingIslands", "dungeon", "spaceStation"]
            .reduce(0) { $0 + ExplorationCatalog.items(for: $1).count }
    }

    // MARK: - Private Helpers

    private func fogKey(x: Int, z: Int) -> String {
        "\(x),\(z)"
    }

    // MARK: - Persistence

    private func saveFogState() {
        if let data = try? JSONEncoder().encode(fogState) {
            UserDefaults.standard.set(data, forKey: fogStorageKey)
        }
    }

    private func saveDiscoveredState() {
        if let data = try? JSONEncoder().encode(Array(discoveredItemIds)) {
            UserDefaults.standard.set(data, forKey: discoveredStorageKey)
        }
    }

    private func loadState() {
        // Load fog
        if let data = UserDefaults.standard.data(forKey: fogStorageKey),
           let decoded = try? JSONDecoder().decode([String: [String: Bool]].self, from: data) {
            fogState = decoded
        }
        // Load discovered
        if let data = UserDefaults.standard.data(forKey: discoveredStorageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            discoveredItemIds = Set(decoded)
        }
    }
}
