import SwiftUI

/// Cosmetic shop view for browsing, purchasing, and equipping cosmetic items
struct CosmeticShopView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CosmeticCategory = .skin
    @State private var selectedItem: CosmeticItem?
    @State private var selectedAgentName: String?
    @State private var purchaseResult: CoinManager.PurchaseResult?
    @State private var showPurchaseAlert = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.white.opacity(0.1))
            HSplitView {
                categorySidebar
                    .frame(minWidth: 130, maxWidth: 150)
                itemGrid
                    .frame(minWidth: 300)
            }
        }
        .frame(width: 560, height: 520)
        .background(Color(hex: "#0D1117"))
        .alert("Purchase", isPresented: $showPurchaseAlert) {
            Button("OK") { showPurchaseAlert = false }
        } message: {
            Text(purchaseAlertMessage)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "bag.fill")
                .foregroundColor(.cyan)
                .font(.title2)
            Text("Cosmetic Shop")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Coin display
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.yellow)
                Text("\(appState.coinManager.coins)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )

            // Agent picker
            if !appState.agents.isEmpty {
                Menu {
                    ForEach(appState.agents, id: \.id) { agent in
                        Button(agent.name) {
                            selectedAgentName = agent.name
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                        Text(selectedAgentName ?? "Select Agent")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Category Sidebar

    private var categorySidebar: some View {
        VStack(spacing: 2) {
            ForEach(CosmeticCategory.allCases, id: \.self) { category in
                let items = CosmeticCatalog.items(for: category)
                let availableCount = items.filter { $0.isAvailable }.count

                Button(action: { selectedCategory = category }) {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .font(.system(size: 12))
                            .frame(width: 16)
                        Text(category.displayName)
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(availableCount)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedCategory == category ? Color.cyan.opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Total earned stats
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 9))
                    Text("Total Earned")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)

                Text("\(appState.coinManager.totalEarned)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))

                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 9))
                    Text("Owned")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)

                Text("\(appState.coinManager.purchasedItemIds.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.8))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.03))
            )
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Item Grid

    private var itemGrid: some View {
        ScrollView {
            // Seasonal banner
            if selectedCategory == .seasonal {
                seasonalBanner
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                let items = itemsForCategory
                ForEach(items, id: \.id) { item in
                    CosmeticItemCard(
                        item: item,
                        isOwned: appState.coinManager.isOwned(item.id),
                        isEquipped: isEquipped(item),
                        canAfford: appState.coinManager.coins >= item.price,
                        onPurchase: { purchaseItem(item) },
                        onEquip: { equipItem(item) },
                        onUnequip: { unequipItem(item) }
                    )
                }
            }
            .padding()
        }
    }

    private var seasonalBanner: some View {
        VStack(spacing: 6) {
            let activeEvents = SeasonalEvent.allCases.filter { $0.isActive }
            if activeEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("No seasonal events active. Check back during holidays!")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(activeEvents, id: \.self) { event in
                    HStack(spacing: 8) {
                        Image(systemName: event.icon)
                            .foregroundColor(.yellow)
                        Text("\(event.displayName) Event Active!")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var itemsForCategory: [CosmeticItem] {
        let items = CosmeticCatalog.items(for: selectedCategory)
        if selectedCategory == .seasonal {
            return items.filter { $0.isAvailable || appState.coinManager.isOwned($0.id) }
        }
        return items
    }

    private func isEquipped(_ item: CosmeticItem) -> Bool {
        guard let agentName = selectedAgentName else { return false }
        let loadout = appState.coinManager.loadout(forAgent: agentName)
        switch item.category {
        case .skin:
            return loadout.equippedSkinId == item.id
        case .hat:
            return loadout.equippedHatId == item.id
        case .particle:
            return loadout.equippedParticleId == item.id
        case .title:
            return loadout.equippedTitleId == item.id
        case .seasonal:
            if item.skinColors != nil { return loadout.equippedSkinId == item.id }
            if item.hatStyle != nil { return loadout.equippedHatId == item.id }
            if item.particleColorHex != nil { return loadout.equippedParticleId == item.id }
            return false
        }
    }

    private func purchaseItem(_ item: CosmeticItem) {
        purchaseResult = appState.coinManager.purchase(item)
        if purchaseResult == .success {
            appState.soundManager.play(.achievement)
        } else {
            showPurchaseAlert = true
        }
    }

    private func equipItem(_ item: CosmeticItem) {
        guard let agentName = selectedAgentName else { return }
        appState.coinManager.equip(item, forAgent: agentName)
        appState.applyCosmeticsToAgent(agentName: agentName)
    }

    private func unequipItem(_ item: CosmeticItem) {
        guard let agentName = selectedAgentName else { return }
        appState.coinManager.unequip(category: item.category, forAgent: agentName)
        appState.applyCosmeticsToAgent(agentName: agentName)
    }

    private var purchaseAlertMessage: String {
        switch purchaseResult {
        case .insufficientFunds: return "Not enough coins! Earn more by completing tasks."
        case .alreadyOwned: return "You already own this item."
        case .notAvailable: return "This item is not currently available."
        default: return ""
        }
    }
}

// MARK: - Cosmetic Item Card

struct CosmeticItemCard: View {
    let item: CosmeticItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let onPurchase: () -> Void
    let onEquip: () -> Void
    let onUnequip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            itemIcon
            itemInfo
            actionButton
        }
        .padding(10)
        .background(cardBackground)
    }

    private var itemIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: item.rarity.color).opacity(0.15))
                .frame(height: 60)

            Image(systemName: item.icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: item.rarity.color))
        }
    }

    private var itemInfo: some View {
        VStack(spacing: 2) {
            Text(item.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(item.description)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(item.rarity.displayName)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: item.rarity.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(Color(hex: item.rarity.color).opacity(0.15))
                )
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isOwned {
            if isEquipped {
                Button(action: onUnequip) {
                    Text("Unequip")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onEquip) {
                    Text("Equip")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        } else {
            Button(action: onPurchase) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 9))
                    Text("\(item.price)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(canAfford ? .yellow : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(purchaseBackground)
            }
            .buttonStyle(.plain)
            .disabled(!canAfford || !item.isAvailable)
        }
    }

    private var purchaseButtonFillColor: Color {
        canAfford ? Color.yellow.opacity(0.1) : Color.white.opacity(0.03)
    }

    private var purchaseButtonStrokeColor: Color {
        canAfford ? Color.yellow.opacity(0.4) : Color.white.opacity(0.1)
    }

    private var purchaseBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(purchaseButtonFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(purchaseButtonStrokeColor, lineWidth: 1)
            )
    }

    private var cardFillColor: Color {
        isEquipped ? Color.cyan.opacity(0.08) : Color.white.opacity(0.03)
    }

    private var cardBorderColor: Color {
        if isEquipped { return Color.cyan.opacity(0.4) }
        if isOwned { return Color.green.opacity(0.2) }
        return Color.white.opacity(0.06)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(cardFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
    }
}

// MARK: - Coin Reward Toast

struct CoinRewardToast: View {
    let reward: CoinManager.CoinReward
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("+\(reward.total) Coins")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)

                HStack(spacing: 8) {
                    if reward.base > 0 {
                        Text("Base: \(reward.base)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    if reward.streakBonus > 0 {
                        Text("Streak: +\(reward.streakBonus)")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    if reward.speedBonus > 0 {
                        Text("Speed: +\(reward.speedBonus)")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}
