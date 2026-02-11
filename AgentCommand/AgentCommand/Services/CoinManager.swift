import Foundation

/// Manages coin earning, spending, and persistence for the reward system
@MainActor
class CoinManager: ObservableObject {
    @Published var coins: Int = 0
    @Published var totalEarned: Int = 0
    @Published var purchasedItemIds: Set<String> = []
    @Published var equippedItems: [String: String] = [:] // category -> itemId
    @Published var agentTitles: [String: String] = [:] // agentName -> titleItemId
    @Published var agentCosmetics: [String: AgentCosmeticLoadout] = [:] // agentName -> loadout
    @Published var lastCoinReward: CoinReward?

    private let storageKey = "coinManager"

    init() {
        load()
    }

    // MARK: - Earning Coins

    struct CoinReward {
        let base: Int
        let streakBonus: Int
        let speedBonus: Int
        let total: Int
    }

    /// Calculate and award coins for task completion
    @discardableResult
    func earnCoins(agentName: String, duration: TimeInterval, streak: Int) -> CoinReward {
        let base = 20
        var streakBonus = 0
        var speedBonus = 0

        // Streak bonus: +2 per consecutive completion, capped at 40
        streakBonus = min(streak * 2, 40)

        // Speed bonus
        if duration < 30 { speedBonus = 15 }
        else if duration < 60 { speedBonus = 8 }
        else if duration < 120 { speedBonus = 3 }

        let total = base + streakBonus + speedBonus
        coins += total
        totalEarned += total

        let reward = CoinReward(base: base, streakBonus: streakBonus, speedBonus: speedBonus, total: total)
        lastCoinReward = reward
        save()
        return reward
    }

    /// Award bonus coins (e.g., for achievements)
    func awardBonus(_ amount: Int) {
        coins += amount
        totalEarned += amount
        save()
    }

    // MARK: - Purchasing

    enum PurchaseResult {
        case success
        case insufficientFunds
        case alreadyOwned
        case notAvailable
    }

    func purchase(_ item: CosmeticItem) -> PurchaseResult {
        guard item.isAvailable else { return .notAvailable }
        guard !purchasedItemIds.contains(item.id) else { return .alreadyOwned }
        guard coins >= item.price else { return .insufficientFunds }

        coins -= item.price
        purchasedItemIds.insert(item.id)
        save()
        return .success
    }

    func isOwned(_ itemId: String) -> Bool {
        purchasedItemIds.contains(itemId)
    }

    // MARK: - Equipping

    func equip(_ item: CosmeticItem, forAgent agentName: String) {
        guard purchasedItemIds.contains(item.id) else { return }

        var loadout = agentCosmetics[agentName] ?? AgentCosmeticLoadout()

        switch item.category {
        case .skin:
            loadout.equippedSkinId = item.id
        case .hat:
            loadout.equippedHatId = item.id
        case .particle:
            loadout.equippedParticleId = item.id
        case .title:
            loadout.equippedTitleId = item.id
            agentTitles[agentName] = item.id
        case .seasonal:
            // Seasonal items can be skin or hat
            if item.skinColors != nil {
                loadout.equippedSkinId = item.id
            } else if item.hatStyle != nil {
                loadout.equippedHatId = item.id
            } else if item.particleColorHex != nil {
                loadout.equippedParticleId = item.id
            }
        }

        agentCosmetics[agentName] = loadout
        save()
    }

    func unequip(category: CosmeticCategory, forAgent agentName: String) {
        var loadout = agentCosmetics[agentName] ?? AgentCosmeticLoadout()

        switch category {
        case .skin:
            loadout.equippedSkinId = nil
        case .hat:
            loadout.equippedHatId = nil
        case .particle:
            loadout.equippedParticleId = nil
        case .title:
            loadout.equippedTitleId = nil
            agentTitles.removeValue(forKey: agentName)
        case .seasonal:
            break // Handled via skin/hat/particle
        }

        agentCosmetics[agentName] = loadout
        save()
    }

    func loadout(forAgent agentName: String) -> AgentCosmeticLoadout {
        agentCosmetics[agentName] ?? AgentCosmeticLoadout()
    }

    func equippedTitle(forAgent agentName: String) -> String? {
        guard let titleId = agentCosmetics[agentName]?.equippedTitleId,
              let item = CosmeticCatalog.item(byId: titleId) else { return nil }
        return item.titleText
    }

    // MARK: - Persistence

    private func save() {
        let data = CoinManagerData(
            coins: coins,
            totalEarned: totalEarned,
            purchasedItemIds: Array(purchasedItemIds),
            agentCosmetics: agentCosmetics,
            agentTitles: agentTitles
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(CoinManagerData.self, from: data) else { return }
        coins = decoded.coins
        totalEarned = decoded.totalEarned
        purchasedItemIds = Set(decoded.purchasedItemIds)
        agentCosmetics = decoded.agentCosmetics
        agentTitles = decoded.agentTitles
    }
}

// MARK: - Supporting Types

struct AgentCosmeticLoadout: Codable {
    var equippedSkinId: String?
    var equippedHatId: String?
    var equippedParticleId: String?
    var equippedTitleId: String?
}

private struct CoinManagerData: Codable {
    let coins: Int
    let totalEarned: Int
    let purchasedItemIds: [String]
    let agentCosmetics: [String: AgentCosmeticLoadout]
    let agentTitles: [String: String]
}
