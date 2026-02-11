import SwiftUI

/// Agent Skills store view - browse, install, and manage skills for agents.
/// Based on Claude Agent Skills architecture with three-tier loading.
struct SkillBookView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SkillCategory? = nil
    @State private var selectedAgentName: String?
    @State private var searchText: String = ""
    @State private var sourceFilter: SkillSource? = nil
    @State private var selectedSkill: AgentSkill? = nil
    @State private var showAddSkillSheet = false
    @State private var editingSkill: AgentSkill?
    @State private var showDeleteAlert = false
    @State private var skillToDelete: AgentSkill?
    @State private var feedbackMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.white.opacity(0.1))
            HSplitView {
                categorySidebar
                    .frame(minWidth: 150, maxWidth: 170)
                mainContent
                    .frame(minWidth: 480)
            }
        }
        .frame(width: 720, height: 620)
        .background(Color(hex: "#0D1117"))
        .sheet(isPresented: $showAddSkillSheet) {
            AddCustomSkillSheet(onSave: { skill in
                appState.skillManager.addCustomSkill(skill)
                showAddSkillSheet = false
                showFeedback(localization.localized(.skillInstalled))
            })
            .environmentObject(localization)
        }
        .sheet(item: $editingSkill) { skill in
            AddCustomSkillSheet(existingSkill: skill, onSave: { updated in
                appState.skillManager.updateCustomSkill(updated)
                editingSkill = nil
            })
            .environmentObject(localization)
        }
        .alert(localization.localized(.confirmDeleteSkill), isPresented: $showDeleteAlert) {
            Button(localization.localized(.removeSkill), role: .destructive) {
                if let skill = skillToDelete {
                    appState.skillManager.removeCustomSkill(id: skill.id)
                    skillToDelete = nil
                    if selectedSkill?.id == skill.id { selectedSkill = nil }
                }
            }
            Button("Cancel", role: .cancel) { skillToDelete = nil }
        }
        .overlay(alignment: .bottom) {
            if let message = feedbackMessage {
                feedbackToast(message)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension.fill")
                .foregroundColor(.cyan)
                .font(.title2)
            Text(localization.localized(.skillStore))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField(localization.localized(.searchSkills), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
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
                        Text(selectedAgentName ?? localization.localized(.selectAgent))
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

            Button(action: { showAddSkillSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(localization.localized(.addCustomSkill))

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
            // "All" category button
            Button(action: { selectedCategory = nil; selectedSkill = nil }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 16)
                    Text(localization.localized(.filterAll))
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(filteredSkillCount(for: nil))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(selectedCategory == nil ? .white : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedCategory == nil ? Color.white.opacity(0.1) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.vertical, 4)

            ForEach(SkillCategory.allCases, id: \.self) { category in
                let total = appState.skillManager.availableSkills(for: category).count
                let installed = selectedAgentName.map { appState.skillManager.installedCount(forAgent: $0, category: category) } ?? 0

                Button(action: { selectedCategory = category; selectedSkill = nil }) {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: category.themeColor))
                            .frame(width: 16)
                        Text(localizedCategoryName(category))
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        if selectedAgentName != nil {
                            Text("\(installed)/\(total)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(total)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedCategory == category ? Color(hex: category.themeColor).opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Stats summary
            if let agentName = selectedAgentName {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                        Text(localization.localized(.installedSkills))
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                    Text("\(appState.skillManager.totalInstalledCount(forAgent: agentName)) / \(appState.skillManager.allAvailableSkills().count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text(localization.localized(.activeSkills))
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                    Text("\(appState.skillManager.activeCount(forAgent: agentName))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                )
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Source filter tabs
            filterBar
            Divider().background(Color.white.opacity(0.1))

            if selectedSkill != nil {
                skillDetailPanel
            } else if selectedAgentName == nil {
                noAgentSelectedView
            } else {
                skillGrid
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(filterOptions, id: \.self) { option in
                Button(action: { sourceFilter = option }) {
                    Text(filterLabel(for: option))
                        .font(.system(size: 10, weight: sourceFilter == option ? .bold : .medium))
                        .foregroundColor(sourceFilter == option ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(sourceFilter == option ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }

    private var filterOptions: [SkillSource?] {
        [nil, .preBuilt, .custom]
    }

    private func filterLabel(for source: SkillSource?) -> String {
        switch source {
        case nil: return localization.localized(.filterAll)
        case .preBuilt: return localization.localized(.filterPreBuilt)
        case .custom: return localization.localized(.filterCustom)
        case .community: return localization.localized(.skillSourceCommunity)
        }
    }

    // MARK: - Skill Grid

    private var skillGrid: some View {
        ScrollView {
            let skills = filteredSkills
            if skills.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(localization.localized(.noSkillsFound))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(skills, id: \.id) { skill in
                        let inst = selectedAgentName.flatMap { appState.skillManager.installation(forAgent: $0, skillId: skill.id) }
                        let isCustom = appState.skillManager.isCustomSkill(id: skill.id)

                        SkillCardView(
                            skill: skill,
                            installation: inst,
                            isCustom: isCustom,
                            onInstall: { installSkill(skill) },
                            onToggleActive: { toggleActive(skill) },
                            onTap: { selectedSkill = skill }
                        )
                        .contextMenu {
                            if isCustom {
                                Button(action: { editingSkill = skill }) {
                                    Label(localization.localized(.editSkill), systemImage: "pencil")
                                }
                                Button(role: .destructive, action: { skillToDelete = skill; showDeleteAlert = true }) {
                                    Label(localization.localized(.removeSkill), systemImage: "trash")
                                }
                            }
                            if inst != nil {
                                Divider()
                                Button(role: .destructive, action: { uninstallSkill(skill) }) {
                                    Label(localization.localized(.uninstallSkill), systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var noAgentSelectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(localization.localized(.noAgentSelected))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Skill Detail Panel

    private var skillDetailPanel: some View {
        ScrollView {
            if let skill = selectedSkill {
                let inst = selectedAgentName.flatMap { appState.skillManager.installation(forAgent: $0, skillId: skill.id) }
                let isCustom = appState.skillManager.isCustomSkill(id: skill.id)

                VStack(alignment: .leading, spacing: 16) {
                    // Back button
                    Button(action: { selectedSkill = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10))
                            Text("Back")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)

                    // Skill header
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: skill.category.themeColor).opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: skill.icon)
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: skill.category.themeColor))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(skill.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)

                                if isCustom {
                                    Text(localization.localized(.filterCustom))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.green.opacity(0.8))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.green.opacity(0.1)))
                                }
                            }

                            HStack(spacing: 8) {
                                Label("v\(skill.version)", systemImage: "tag")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Label(skill.author, systemImage: "person")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                sourceBadge(skill.source)
                            }
                        }
                        Spacer()
                    }

                    // Description
                    Text(skill.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(3)

                    // Compatible platforms
                    if !skill.compatiblePlatforms.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localization.localized(.skillCompatiblePlatforms))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                ForEach(skill.compatiblePlatforms, id: \.self) { platform in
                                    Text(platform)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(Color.white.opacity(0.08))
                                        )
                                }
                            }
                        }
                    }

                    // Tags
                    if !skill.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localization.localized(.skillTags))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            FlowLayout(spacing: 4) {
                                ForEach(skill.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 9))
                                        .foregroundColor(.cyan.opacity(0.8))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(Color.cyan.opacity(0.1))
                                        )
                                }
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // Instructions preview (Layer 2)
                    if let instructions = skill.instructionsFull ?? skill.instructionsPreview {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text(localization.localized(.skillInstructions))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.secondary)

                            Text(instructions)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.03))
                                )
                        }
                    }

                    // Resources (Layer 3)
                    if !skill.resources.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                Text(localization.localized(.skillResources))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.secondary)

                            ForEach(skill.resources, id: \.fileName) { resource in
                                HStack(spacing: 8) {
                                    Image(systemName: resource.typeIcon)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: skill.category.themeColor))
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(resource.fileName)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                        Text(resource.description)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(resource.fileSizeFormatted)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.03))
                                )
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // Usage stats (if installed)
                    if let inst = inst {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 16) {
                                statItem(label: localization.localized(.skillInstalledAt), value: formatDate(inst.installedAt))
                                statItem(label: localization.localized(.skillUsageCount), value: "\(inst.usageCount)")
                                if let lastUsed = inst.lastUsedAt {
                                    statItem(label: localization.localized(.skillLastUsed), value: formatDate(lastUsed))
                                }
                            }
                        }
                        Divider().background(Color.white.opacity(0.1))
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        if let agentName = selectedAgentName {
                            if inst != nil {
                                // Toggle active
                                Button(action: { toggleActive(skill) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: inst?.isActive == true ? "bolt.fill" : "bolt.slash")
                                        Text(inst?.isActive == true ? localization.localized(.deactivateSkill) : localization.localized(.activateSkill))
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(inst?.isActive == true ? .orange : .green)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill((inst?.isActive == true ? Color.orange : Color.green).opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke((inst?.isActive == true ? Color.orange : Color.green).opacity(0.4), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)

                                // Uninstall
                                Button(action: { uninstallSkill(skill) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text(localization.localized(.uninstallSkill))
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.red.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Install
                                Button(action: { installSkill(skill) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text(localization.localized(.installSkill))
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.green.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text(localization.localized(.noAgentSelected))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Filtered Skills

    private var filteredSkills: [AgentSkill] {
        var skills = selectedCategory == nil
            ? appState.skillManager.allAvailableSkills()
            : appState.skillManager.availableSkills(for: selectedCategory!)

        if let source = sourceFilter {
            skills = skills.filter { $0.source == source }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            skills = skills.filter {
                $0.name.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.tags.contains(where: { $0.lowercased().contains(q) })
            }
        }

        return skills
    }

    private func filteredSkillCount(for category: SkillCategory?) -> Int {
        if let cat = category {
            return appState.skillManager.availableSkills(for: cat).count
        }
        return appState.skillManager.allAvailableSkills().count
    }

    // MARK: - Actions

    private func installSkill(_ skill: AgentSkill) {
        guard let agentName = selectedAgentName else { return }
        let success = appState.skillManager.installSkill(skillId: skill.id, forAgent: agentName)
        if success {
            showFeedback(localization.localized(.skillInstalled))
            appState.soundManager.play(.achievement)
        }
    }

    private func uninstallSkill(_ skill: AgentSkill) {
        guard let agentName = selectedAgentName else { return }
        appState.skillManager.uninstallSkill(skillId: skill.id, forAgent: agentName)
        showFeedback(localization.localized(.skillUninstalled))
    }

    private func toggleActive(_ skill: AgentSkill) {
        guard let agentName = selectedAgentName else { return }
        appState.skillManager.toggleActive(skillId: skill.id, forAgent: agentName)
        let isNowActive = appState.skillManager.isActive(skillId: skill.id, forAgent: agentName)
        showFeedback(isNowActive ? localization.localized(.skillActivated) : localization.localized(.skillDeactivated))
    }

    // MARK: - Helpers

    private func showFeedback(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            feedbackMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                feedbackMessage = nil
            }
        }
    }

    private func feedbackToast(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func sourceBadge(_ source: SkillSource) -> some View {
        Text(source == .preBuilt ? "Anthropic" : source.displayName)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(source == .preBuilt ? .cyan.opacity(0.9) : .green.opacity(0.9))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill((source == .preBuilt ? Color.cyan : Color.green).opacity(0.12))
            )
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func localizedCategoryName(_ category: SkillCategory) -> String {
        switch category {
        case .fileProcessing: return localization.localized(.skillCategoryFileProcessing)
        case .codeExecution: return localization.localized(.skillCategoryCodeExecution)
        case .dataAnalysis: return localization.localized(.skillCategoryDataAnalysis)
        case .webInteraction: return localization.localized(.skillCategoryWebInteraction)
        case .contentCreation: return localization.localized(.skillCategoryContentCreation)
        case .systemIntegration: return localization.localized(.skillCategorySystemIntegration)
        case .custom: return localization.localized(.skillCategoryCustom)
        }
    }
}

// MARK: - Skill Card View

struct SkillCardView: View {
    let skill: AgentSkill
    let installation: SkillInstallation?
    let isCustom: Bool
    let onInstall: () -> Void
    let onToggleActive: () -> Void
    let onTap: () -> Void

    private var isInstalled: Bool { installation != nil }
    private var isActive: Bool { installation?.isActive ?? false }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: icon + name + version
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: skill.category.themeColor).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: skill.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: skill.category.themeColor))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(skill.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if isCustom {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text("v\(skill.version)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Status indicator
                    if isInstalled {
                        Circle()
                            .fill(isActive ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                    }
                }

                // Description
                Text(skill.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Tags
                HStack(spacing: 4) {
                    sourceBadge(skill.source)
                    ForEach(skill.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.white.opacity(0.06))
                            )
                    }
                    if skill.tags.count > 2 {
                        Text("+\(skill.tags.count - 2)")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                }

                // Action row
                HStack {
                    if isInstalled {
                        Button(action: onToggleActive) {
                            HStack(spacing: 4) {
                                Image(systemName: isActive ? "bolt.fill" : "bolt.slash")
                                    .font(.system(size: 9))
                                Text(isActive ? "Active" : "Inactive")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(isActive ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill((isActive ? Color.green : Color.orange).opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onInstall) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 9))
                                Text("Install")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.cyan.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Resource count badge
                    if !skill.resources.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.system(size: 8))
                            Text("\(skill.resources.count)")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isInstalled ? Color(hex: skill.category.themeColor).opacity(0.05) : Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isActive ? Color.green.opacity(0.3) :
                        isInstalled ? Color(hex: skill.category.themeColor).opacity(0.2) :
                        Color.white.opacity(0.06),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
    }

    private func sourceBadge(_ source: SkillSource) -> some View {
        Text(source == .preBuilt ? "Anthropic" : source.displayName)
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(source == .preBuilt ? .cyan.opacity(0.8) : .green.opacity(0.8))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill((source == .preBuilt ? Color.cyan : Color.green).opacity(0.1))
            )
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Add / Edit Custom Skill Sheet

struct AddCustomSkillSheet: View {
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let existingSkill: AgentSkill?
    let onSave: (AgentSkill) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var category: SkillCategory = .custom
    @State private var version: String = "1.0.0"
    @State private var tagsText: String = ""
    @State private var instructions: String = ""
    @State private var selectedIcon: String = "puzzlepiece.extension.fill"

    private let iconOptions = [
        "puzzlepiece.extension.fill", "bolt.fill", "flame.fill", "brain.fill", "cpu.fill",
        "terminal.fill", "hammer.fill", "wrench.fill", "paintbrush.fill", "eye.fill",
        "shield.fill", "leaf.fill", "globe", "wand.and.stars", "sparkles",
        "chart.bar.fill", "doc.text.fill", "ant.fill", "lock.shield.fill", "network",
    ]

    init(existingSkill: AgentSkill? = nil, onSave: @escaping (AgentSkill) -> Void) {
        self.existingSkill = existingSkill
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: existingSkill != nil ? "pencil.circle.fill" : "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text(existingSkill != nil ? localization.localized(.editSkill) : localization.localized(.addCustomSkill))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            Form {
                Section(localization.localized(.skillName)) {
                    TextField(localization.localized(.skillName), text: $name)
                }

                Section(localization.localized(.skillDescription)) {
                    TextField(localization.localized(.skillDescription), text: $description)
                }

                Section(localization.localized(.selectSkillCategory)) {
                    Picker(localization.localized(.selectSkillCategory), selection: $category) {
                        ForEach(SkillCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section(localization.localized(.skillVersion)) {
                    TextField("1.0.0", text: $version)
                }

                Section(localization.localized(.skillTags)) {
                    TextField("pdf, document, forms", text: $tagsText)
                }

                Section(localization.localized(.skillInstructions)) {
                    TextEditor(text: $instructions)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(minHeight: 80)
                }

                Section(localization.localized(.selectSkillIcon)) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(selectedIcon == icon ? .white : .secondary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == icon ? Color(hex: category.themeColor).opacity(0.3) : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedIcon == icon ? Color(hex: category.themeColor) : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // Save button
            HStack {
                Spacer()
                Button(action: saveSkill) {
                    Text(existingSkill != nil ? localization.localized(.editSkill) : localization.localized(.addCustomSkill))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(name.isEmpty ? Color.gray : Color.green)
                        )
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                Spacer()
            }
            .padding(.bottom)
        }
        .frame(width: 440, height: 580)
        .background(Color(hex: "#0D1117"))
        .onAppear {
            if let skill = existingSkill {
                name = skill.name
                description = skill.description
                category = skill.category
                version = skill.version
                tagsText = skill.tags.joined(separator: ", ")
                instructions = skill.instructionsFull ?? skill.instructionsPreview ?? ""
                selectedIcon = skill.icon
            }
        }
    }

    private func saveSkill() {
        let id = existingSkill?.id ?? "custom_\(UUID().uuidString)"
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let now = Date()

        let skill = AgentSkill(
            id: id,
            name: name,
            description: description,
            category: category,
            icon: selectedIcon,
            version: version.isEmpty ? "1.0.0" : version,
            author: "User",
            source: .custom,
            instructionsPreview: instructions.isEmpty ? nil : String(instructions.prefix(200)),
            instructionsFull: instructions.isEmpty ? nil : instructions,
            resources: existingSkill?.resources ?? [],
            createdAt: existingSkill?.createdAt ?? now,
            updatedAt: now,
            tags: tags,
            compatiblePlatforms: ["claude-code"]
        )
        onSave(skill)
    }
}
