import SwiftUI

// MARK: - H2: Memory Timeline View (Agent Memory Visualization)

struct MemoryTimelineView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var searchText: String = ""
    @State private var selectedCategory: MemoryCategory?
    @State private var selectedAgent: String?
    @State private var showClearConfirm: Bool = false

    private var filteredMemories: [AgentMemory] {
        var result = appState.agentMemoryManager.memories
        if let agent = selectedAgent {
            result = result.filter { $0.agentName == agent }
        }
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.taskTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.summary.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            // Stats summary
            statsBar

            Divider()

            // Filter bar
            filterBar

            // Memory list
            if filteredMemories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredMemories) { memory in
                            MemoryBubbleView(memory: memory, onDelete: {
                                appState.agentMemoryManager.deleteMemory(id: memory.id)
                            }, onShare: {
                                shareMemoryToTeam(memory)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 650, minHeight: 400, idealHeight: 600)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .alert(localization.localized(.memoryConfirmClear), isPresented: $showClearConfirm) {
            Button(localization.localized(.cancel), role: .cancel) {}
            Button(localization.localized(.memoryConfirmClear), role: .destructive) {
                appState.agentMemoryManager.clearAllMemories()
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.memoryTimeline))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { showClearConfirm = true }) {
                Label(localization.localized(.memoryClearAll), systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(appState.agentMemoryManager.memories.isEmpty)

            Button(action: { appState.isAgentMemoryVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statsBar: some View {
        let stats = appState.agentMemoryManager.memoryStats
        return HStack(spacing: 20) {
            statItem(
                icon: "brain",
                label: localization.localized(.memoryTotalMemories),
                value: "\(stats.totalMemories)"
            )
            statItem(
                icon: "person.2",
                label: localization.localized(.memoryTotalAgents),
                value: "\(stats.totalAgents)"
            )
            statItem(
                icon: "internaldrive",
                label: localization.localized(.memoryDatabaseSize),
                value: stats.formattedSize
            )
            if let newest = stats.newestMemoryDate {
                statItem(
                    icon: "clock",
                    label: localization.localized(.memoryLastUpdated),
                    value: RelativeDateTimeFormatter().localizedString(for: newest, relativeTo: Date())
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00BCD4"))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                TextField(localization.localized(.memorySearch), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            .padding(6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)

            // Agent filter
            Menu {
                Button(localization.localized(.filterAll)) { selectedAgent = nil }
                Divider()
                ForEach(appState.agentMemoryManager.agentNames(), id: \.self) { name in
                    Button(name) { selectedAgent = name }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                    Text(selectedAgent ?? localization.localized(.filterAll))
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Category filter
            Menu {
                Button(localization.localized(.filterAll)) { selectedCategory = nil }
                Divider()
                ForEach(MemoryCategory.allCases, id: \.self) { cat in
                    Button(cat.displayName) { selectedCategory = cat }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedCategory?.iconName ?? "square.grid.2x2")
                    Text(selectedCategory?.displayName ?? localization.localized(.memoryCategory))
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.2))
            Text(localization.localized(.memoryNoMemories))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
            Text(localization.localized(.memoryNoMemoriesDesc))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func shareMemoryToTeam(_ memory: AgentMemory) {
        let agents = appState.agents.map(\.name).filter { $0 != memory.agentName }
        for agentName in agents {
            appState.agentMemoryManager.shareMemory(memoryId: memory.id, fromAgent: memory.agentName, toAgent: agentName)
        }
    }
}

// MARK: - Memory Bubble View (Timeline item)

struct MemoryBubbleView: View {
    let memory: AgentMemory
    let onDelete: () -> Void
    let onShare: () -> Void
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                // Category icon
                Image(systemName: memory.category.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: memory.category.colorHex))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: memory.category.colorHex).opacity(0.15))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(memory.taskTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(memory.agentName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "#00BCD4"))

                        Text(memory.category.displayName)
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: memory.category.colorHex))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(hex: memory.category.colorHex).opacity(0.15))
                            .cornerRadius(3)

                        Spacer()

                        // Relevance indicator
                        HStack(spacing: 2) {
                            Image(systemName: "flame")
                                .font(.system(size: 8))
                            Text(String(format: "%.0f%%", memory.decayedScore * 100))
                                .font(.system(size: 9))
                        }
                        .foregroundColor(relevanceColor)
                    }
                }

                Spacer()

                // Timestamp
                Text(formatDate(memory.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Summary
            Text(memory.summary)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(isExpanded ? nil : 2)

            // Tags
            if !memory.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(memory.tags.prefix(6), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Expanded details
            if isExpanded && !memory.relatedFilesPaths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related Files:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    ForEach(memory.relatedFilesPaths.prefix(5), id: \.self) { path in
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#00BCD4").opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            // Action row
            HStack(spacing: 12) {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text(isExpanded ? "Less" : "More")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onShare) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrowshape.turn.up.right")
                        Text("Share")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#00BCD4").opacity(0.7))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: memory.category.colorHex).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var relevanceColor: Color {
        if memory.decayedScore > 0.7 { return Color(hex: "#4CAF50") }
        if memory.decayedScore > 0.4 { return Color(hex: "#FF9800") }
        return Color(hex: "#FF5722")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
