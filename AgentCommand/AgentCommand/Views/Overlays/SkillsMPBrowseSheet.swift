import SwiftUI
import AppKit

/// Sheet for browsing and importing skills from the SkillsMP marketplace.
struct SkillsMPBrowseSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let onImport: (AgentSkill) -> Void
    let onAddCustom: () -> Void

    @State private var searchText = ""
    @State private var useAISearch = false
    @State private var sortBy = "stars"
    @State private var apiKeyInput = ""
    @State private var feedbackMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var service: SkillsMPService { appState.skillsMPService }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.white.opacity(0.1))

            if !service.hasAPIKey {
                apiKeySetupView
            } else {
                searchBar
                Divider().background(Color.white.opacity(0.1))
                resultContent
            }

            Divider().background(Color.white.opacity(0.1))
            footerBar
        }
        .frame(width: 600, height: 520)
        .background(Color(hex: "#0D1117"))
        .overlay(alignment: .bottom) {
            if let message = feedbackMessage {
                feedbackToast(message)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.badge.chevron.backward")
                .foregroundColor(.purple)
                .font(.title2)
            Text(localization.localized(.skillsMPMarketplace))
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
        .padding()
        .background(Color.white.opacity(0.05))
    }

    // MARK: - API Key Setup

    private var apiKeySetupView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundColor(.purple.opacity(0.6))

            Text(localization.localized(.skillsMPNoAPIKey))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Text(localization.localized(.skillsMPNoAPIKeyDesc))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                SecureField(localization.localized(.skillsMPEnterAPIKey), text: $apiKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                    )
                    .frame(width: 260)

                Button(action: saveAPIKey) {
                    Text(localization.localized(.skillsMPSaveKey))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(apiKeyInput.isEmpty ? Color.gray : Color.purple)
                        )
                }
                .buttonStyle(.plain)
                .disabled(apiKeyInput.isEmpty)
            }

            Button(action: openSkillsMPWebsite) {
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                        .font(.system(size: 11))
                    Text(localization.localized(.skillsMPGetKey))
                        .font(.system(size: 11))
                }
                .foregroundColor(.purple.opacity(0.8))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField(localization.localized(.skillsMPSearchPlaceholder), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .onSubmit { performSearch() }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        service.clearResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )

            // AI Search toggle
            Button(action: { useAISearch.toggle() }) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text(localization.localized(.skillsMPAISearch))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(useAISearch ? .white : .white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(useAISearch ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            // Sort menu
            Menu {
                Button(action: { sortBy = "stars" }) {
                    Label(localization.localized(.skillsMPSortByStars), systemImage: "star.fill")
                }
                Button(action: { sortBy = "recent" }) {
                    Label(localization.localized(.skillsMPSortByDate), systemImage: "clock")
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
            }

            // Search button
            Button(action: performSearch) {
                Text(localization.localized(.skillsMPSearch))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple)
                    )
            }
            .buttonStyle(.plain)
            .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Result Content

    private var resultContent: some View {
        Group {
            if service.isLoading {
                loadingView
            } else if let error = service.errorMessage {
                errorView(error)
            } else if service.searchResults.isEmpty && !searchText.isEmpty {
                emptyResultsView
            } else if service.searchResults.isEmpty {
                promptView
            } else {
                resultGrid
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text(localization.localized(.skillsMPLoading))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text(localization.localized(.skillsMPError))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Button(action: performSearch) {
                Text("Retry")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.purple)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(localization.localized(.skillsMPNoResults))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Button(action: openSkillsMPSearch) {
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                        .font(.system(size: 11))
                    Text(localization.localized(.skillsMPOpenInBrowser))
                        .font(.system(size: 11))
                }
                .foregroundColor(.purple.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var promptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            Text(localization.localized(.skillsMPSearchPlaceholder))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result Grid

    private var resultGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(service.searchResults) { skill in
                    skillCard(skill)
                }
            }
            .padding()
        }
    }

    private func skillCard(_ skill: SkillsMPSkill) -> some View {
        let alreadyImported = appState.skillManager.customSkills.contains { $0.id == "skillsmp_\(skill.id)" }

        return VStack(alignment: .leading, spacing: 8) {
            // Name + author
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(skill.author)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()

                if alreadyImported {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }

            // Description
            Text(skill.description)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Stars + date + actions
            HStack(spacing: 6) {
                // Stars badge
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow.opacity(0.8))
                    Text("\(skill.stars)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Community badge
                Text("Community")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.purple.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.purple.opacity(0.1)))

                Spacer()

                // Open in browser
                if let urlStr = skill.githubUrl, let url = URL(string: urlStr) {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(localization.localized(.skillsMPOpenInBrowser))
                }

                // Import button
                if alreadyImported {
                    Text(localization.localized(.skillsMPAlreadyImported))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                } else {
                    Button(action: { importSkill(skill) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 9))
                            Text(localization.localized(.skillsMPImport))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.purple.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(alreadyImported ? Color.green.opacity(0.03) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(alreadyImported ? Color.green.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button(action: onAddCustom) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                    Text(localization.localized(.addManualSkill))
                        .font(.system(size: 11))
                }
                .foregroundColor(.green.opacity(0.8))
            }
            .buttonStyle(.plain)

            Spacer()

            if service.totalResults > 0 {
                Text("\(service.searchResults.count) / \(service.totalResults)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // API Key settings
            Button(action: { resetAPIKey() }) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(localization.localized(.skillsMPAPIKey))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Actions

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        searchTask?.cancel()
        searchTask = Task {
            if useAISearch {
                await service.aiSearch(query: query)
            } else {
                await service.search(query: query, sortBy: sortBy)
            }
        }
    }

    private func importSkill(_ skill: SkillsMPSkill) {
        let agentSkill = skill.toAgentSkill()

        // Check for duplicate
        if appState.skillManager.customSkills.contains(where: { $0.id == agentSkill.id }) {
            showFeedback(localization.localized(.skillsMPAlreadyImported))
            return
        }

        onImport(agentSkill)
        showFeedback(localization.localized(.skillsMPImported))
        appState.soundManager.play(.achievement)
    }

    private func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        service.apiKey = trimmed
        apiKeyInput = ""
    }

    private func resetAPIKey() {
        service.apiKey = nil
        service.clearResults()
    }

    private func openSkillsMPWebsite() {
        if let url = URL(string: "https://skillsmp.com/docs/api") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openSkillsMPSearch() {
        let encoded = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
        if let url = URL(string: "https://skillsmp.com/search?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Feedback

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
}
