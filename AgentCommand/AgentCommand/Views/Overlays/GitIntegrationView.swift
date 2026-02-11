import SwiftUI
import AppKit

/// Main sheet for Git Integration visualization (G3)
struct GitIntegrationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: GitTab = .diff
    @State private var prTitle: String = ""
    @State private var prBody: String = ""
    @State private var prSourceBranch: String = ""
    @State private var prTargetBranch: String = "main"
    @State private var prCreating: Bool = false
    @State private var prResult: String?

    // Commit & Push state
    @State private var commitMessage: String = ""
    @State private var isGeneratingMessage: Bool = false
    @State private var isCommitting: Bool = false
    @State private var isPushing: Bool = false
    @State private var commitPushResult: String?
    @State private var commitPushResultIsError: Bool = false

    enum GitTab: String, CaseIterable {
        case diff, commitPush, branches, commits, pullRequest

        var icon: String {
            switch self {
            case .diff: return "doc.text.magnifyingglass"
            case .commitPush: return "arrow.up.circle"
            case .branches: return "arrow.triangle.branch"
            case .commits: return "clock.arrow.circlepath"
            case .pullRequest: return "arrow.triangle.pull"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            tabBar
            Divider().background(Color.white.opacity(0.1))

            if !appState.gitManager.isGitRepository {
                noRepositoryView
            } else {
                switch selectedTab {
                case .diff: diffTab
                case .commitPush: commitPushTab
                case .branches: branchesTab
                case .commits: commitsTab
                case .pullRequest: pullRequestTab
                }
            }
        }
        .frame(width: 560, height: 620)
        .background(Color(hex: "#0D1117"))
        .onAppear {
            appState.startGitMonitoring()
        }
        .onChange(of: appState.workspaceManager.activeWorkspace?.id) { _, _ in
            appState.startGitMonitoring()
        }
        .onChange(of: appState.gitManager.repositoryState?.currentBranch) { _, newBranch in
            if let branch = newBranch, prSourceBranch.isEmpty {
                prSourceBranch = branch
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(Color(hex: "#58A6FF"))
                .font(.title2)

            Text(localization.localized(.gitIntegration))
                .font(.headline)
                .foregroundColor(.white)

            if let state = appState.gitManager.repositoryState {
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.isClean ? Color(hex: "#4CAF50") : Color(hex: "#FF9800"))
                        .frame(width: 6, height: 6)
                    Text(state.currentBranch)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#58A6FF"))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "#58A6FF").opacity(0.1))
                .cornerRadius(4)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(GitTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tabTitle(tab))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? Color(hex: "#58A6FF") : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color(hex: "#58A6FF").opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
    }

    private func tabTitle(_ tab: GitTab) -> String {
        switch tab {
        case .diff: return localization.localized(.gitDiff)
        case .commitPush: return localization.localized(.gitCommitAndPush)
        case .branches: return localization.localized(.gitBranches)
        case .commits: return localization.localized(.gitCommits)
        case .pullRequest: return localization.localized(.gitPullRequest)
        }
    }

    // MARK: - No Repository

    private var noRepositoryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(localization.localized(.gitNoRepository))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let error = appState.gitManager.lastError {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Text(appState.workspaceManager.activeDirectory)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.horizontal, 20)

            Button("Open Folder...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.message = "Select a Git repository folder"
                if panel.runModal() == .OK, let url = panel.url {
                    appState.gitManager.startMonitoring(directory: url.path)
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Diff Tab

    private var diffTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 3D Toggle
                sceneToggleButton(
                    isActive: appState.isGitDiffVisible,
                    action: { appState.toggleGitDiff() }
                )

                if let state = appState.gitManager.repositoryState {
                    if state.isClean {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "#4CAF50"))
                                Text(localization.localized(.gitRepositoryClean))
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else {
                        if !state.stagedFiles.isEmpty {
                            sectionHeader(localization.localized(.gitStagedChanges), count: state.stagedFiles.count, color: "#4CAF50")
                            ForEach(state.stagedFiles) { file in
                                diffFileRow(file)
                            }
                        }

                        if !state.unstagedFiles.isEmpty {
                            sectionHeader(localization.localized(.gitUnstagedChanges), count: state.unstagedFiles.count, color: "#FF9800")
                            ForEach(state.unstagedFiles) { file in
                                diffFileRow(file)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func diffFileRow(_ file: GitDiffFile) -> some View {
        HStack(spacing: 8) {
            Image(systemName: file.status.icon)
                .foregroundColor(Color(hex: file.status.hexColor))
                .font(.system(size: 12))

            Text(file.filePath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 4) {
                Text("+\(file.additions)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
                Text("-\(file.deletions)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#F44336"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.03))
        .cornerRadius(4)
    }

    // MARK: - Commit & Push Tab

    private var commitPushTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let state = appState.gitManager.repositoryState {
                    // Changed files summary
                    let totalChanges = state.stagedFiles.count + state.unstagedFiles.count
                    if totalChanges == 0 && state.isClean {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "#4CAF50"))
                                Text(localization.localized(.gitNothingToCommit))
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else {
                        // Staged / Unstaged summary
                        if !state.stagedFiles.isEmpty {
                            sectionHeader(localization.localized(.gitStagedChanges), count: state.stagedFiles.count, color: "#4CAF50")
                            ForEach(state.stagedFiles.prefix(5)) { file in
                                diffFileRow(file)
                            }
                            if state.stagedFiles.count > 5 {
                                Text("... +\(state.stagedFiles.count - 5) more")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 10)
                            }
                        }

                        if !state.unstagedFiles.isEmpty {
                            sectionHeader(localization.localized(.gitUnstagedChanges), count: state.unstagedFiles.count, color: "#FF9800")
                            ForEach(state.unstagedFiles.prefix(5)) { file in
                                diffFileRow(file)
                            }
                            if state.unstagedFiles.count > 5 {
                                Text("... +\(state.unstagedFiles.count - 5) more")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 10)
                            }
                        }

                        // Stage All button
                        if !state.unstagedFiles.isEmpty {
                            Button(action: {
                                Task {
                                    _ = await appState.gitManager.stageAll()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 11))
                                    Text(localization.localized(.gitStageAll))
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(Color(hex: "#FF9800"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#FF9800").opacity(0.15))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().background(Color.white.opacity(0.1))

                        // Commit message
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(localization.localized(.gitCommitMessage))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                // AI Generate button
                                Button(action: {
                                    isGeneratingMessage = true
                                    Task {
                                        let msg = await appState.gitManager.generateCommitMessage()
                                        commitMessage = msg
                                        isGeneratingMessage = false
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        if isGeneratingMessage {
                                            ProgressView()
                                                .controlSize(.mini)
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 10))
                                        }
                                        Text(isGeneratingMessage ? localization.localized(.gitGeneratingMessage) : localization.localized(.gitGenerateMessage))
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "#A855F7"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "#A855F7").opacity(0.12))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .disabled(isGeneratingMessage)
                            }

                            TextEditor(text: $commitMessage)
                                .frame(height: 70)
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }

                        Divider().background(Color.white.opacity(0.1))

                        // Action buttons
                        HStack(spacing: 12) {
                            // Commit button
                            Button(action: {
                                performCommit()
                            }) {
                                HStack(spacing: 4) {
                                    if isCommitting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "checkmark.circle")
                                    }
                                    Text(isCommitting ? localization.localized(.gitCommitting) : localization.localized(.gitCommit))
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color(hex: "#238636"))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCommitting)

                            // Commit & Push button
                            Button(action: {
                                performCommitAndPush()
                            }) {
                                HStack(spacing: 4) {
                                    if isCommitting || isPushing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                    }
                                    Text(commitAndPushLabel)
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color(hex: "#1F6FEB"))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCommitting || isPushing)

                            Spacer()

                            // Push only button (for already committed changes)
                            if state.isClean || state.stagedFiles.isEmpty {
                                Button(action: {
                                    performPush()
                                }) {
                                    HStack(spacing: 4) {
                                        if isPushing {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.up")
                                        }
                                        Text(isPushing ? localization.localized(.gitPushing) : localization.localized(.gitPush))
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "#58A6FF"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color(hex: "#58A6FF").opacity(0.15))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(isPushing)
                            }
                        }

                        // Result message
                        if let result = commitPushResult {
                            HStack(spacing: 6) {
                                Image(systemName: commitPushResultIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(result)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(commitPushResultIsError ? Color(hex: "#F44336") : Color(hex: "#4CAF50"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var commitAndPushLabel: String {
        if isCommitting {
            return localization.localized(.gitCommitting)
        }
        if isPushing {
            return localization.localized(.gitPushing)
        }
        return "\(localization.localized(.gitCommit)) & \(localization.localized(.gitPush))"
    }

    private func performCommit() {
        isCommitting = true
        commitPushResult = nil
        Task {
            // Stage all if there are unstaged changes
            if let state = appState.gitManager.repositoryState, !state.unstagedFiles.isEmpty {
                _ = await appState.gitManager.stageAll()
            }
            let (success, error) = await appState.gitManager.commit(message: commitMessage)
            isCommitting = false
            if success {
                commitPushResult = localization.localized(.gitCommitSuccess)
                commitPushResultIsError = false
                commitMessage = ""
            } else {
                commitPushResult = "\(localization.localized(.gitCommitFailed)): \(error ?? "")"
                commitPushResultIsError = true
            }
        }
    }

    private func performCommitAndPush() {
        isCommitting = true
        commitPushResult = nil
        Task {
            // Stage all if there are unstaged changes
            if let state = appState.gitManager.repositoryState, !state.unstagedFiles.isEmpty {
                _ = await appState.gitManager.stageAll()
            }
            let (commitSuccess, commitError) = await appState.gitManager.commit(message: commitMessage)
            isCommitting = false
            if !commitSuccess {
                commitPushResult = "\(localization.localized(.gitCommitFailed)): \(commitError ?? "")"
                commitPushResultIsError = true
                return
            }
            // Push
            isPushing = true
            let (pushSuccess, pushError) = await appState.gitManager.push()
            isPushing = false
            if pushSuccess {
                commitPushResult = "\(localization.localized(.gitCommitSuccess)) \(localization.localized(.gitPushSuccess))"
                commitPushResultIsError = false
                commitMessage = ""
            } else {
                commitPushResult = "\(localization.localized(.gitPushFailed)): \(pushError ?? "")"
                commitPushResultIsError = true
            }
        }
    }

    private func performPush() {
        isPushing = true
        commitPushResult = nil
        Task {
            let (success, error) = await appState.gitManager.push()
            isPushing = false
            if success {
                commitPushResult = localization.localized(.gitPushSuccess)
                commitPushResultIsError = false
            } else {
                commitPushResult = "\(localization.localized(.gitPushFailed)): \(error ?? "")"
                commitPushResultIsError = true
            }
        }
    }

    // MARK: - Branches Tab

    private var branchesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 3D Toggle
                sceneToggleButton(
                    isActive: appState.isGitBranchTreeVisible,
                    action: { appState.toggleGitBranchTree() }
                )

                if let state = appState.gitManager.repositoryState {
                    if state.branches.isEmpty {
                        emptyMessage(localization.localized(.gitNoBranches))
                    } else {
                        // Current branch
                        sectionHeader(localization.localized(.gitCurrentBranch), count: nil, color: "#58A6FF")
                        branchRow(name: state.currentBranch, isCurrent: true, isRemote: false)

                        // Local branches
                        let localBranches = state.branches.filter { !$0.isRemote && !$0.isCurrent }
                        if !localBranches.isEmpty {
                            sectionHeader(localization.localized(.gitBranches), count: localBranches.count, color: "#8B949E")
                            ForEach(localBranches) { branch in
                                branchRow(name: branch.name, isCurrent: false, isRemote: false)
                            }
                        }

                        // Remote branches
                        let remoteBranches = state.branches.filter { $0.isRemote }
                        if !remoteBranches.isEmpty {
                            sectionHeader(localization.localized(.gitRemoteBranch), count: remoteBranches.count, color: "#8B949E")
                            ForEach(remoteBranches) { branch in
                                branchRow(name: branch.name, isCurrent: false, isRemote: true)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func branchRow(name: String, isCurrent: Bool, isRemote: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isRemote ? "cloud" : "arrow.triangle.branch")
                .foregroundColor(isCurrent ? Color(hex: "#58A6FF") : .secondary)
                .font(.system(size: 12))

            Text(name)
                .font(.system(size: 11, weight: isCurrent ? .bold : .regular, design: .monospaced))
                .foregroundColor(isCurrent ? Color(hex: "#58A6FF") : .white)

            Spacer()

            if isCurrent {
                Text("HEAD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#58A6FF"))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#58A6FF").opacity(0.15))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isCurrent ? 0.05 : 0.03))
        .cornerRadius(4)
    }

    // MARK: - Commits Tab

    private var commitsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 3D Toggle
                sceneToggleButton(
                    isActive: appState.isGitCommitTimelineVisible,
                    action: { appState.toggleGitCommitTimeline() }
                )

                if let state = appState.gitManager.repositoryState {
                    if state.recentCommits.isEmpty {
                        emptyMessage(localization.localized(.gitNoCommits))
                    } else {
                        ForEach(state.recentCommits.prefix(30)) { commit in
                            commitRow(commit)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func commitRow(_ commit: GitCommit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Commit hash
                Text(commit.hash)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#58A6FF"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(hex: "#58A6FF").opacity(0.1))
                    .cornerRadius(3)

                // Branch tag if present
                if let branch = commit.branchName {
                    Text(branch)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#4CAF50"))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: "#4CAF50").opacity(0.1))
                        .cornerRadius(3)
                }

                Spacer()

                // Date
                Text(formatDate(commit.date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Commit message
            Text(commit.message)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 8) {
                // Author
                HStack(spacing: 3) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 8))
                    Text(commit.author)
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)

                // Stats
                if commit.filesChanged > 0 {
                    HStack(spacing: 3) {
                        Text("\(commit.filesChanged) files")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("+\(commit.additions)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#4CAF50"))
                        Text("-\(commit.deletions)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#F44336"))
                    }
                }

                // Agent link
                if let agentId = commit.agentId,
                   let agent = appState.agents.first(where: { $0.id == agentId }) {
                    HStack(spacing: 3) {
                        Image(systemName: "cpu")
                            .font(.system(size: 8))
                        Text(agent.name)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(Color(hex: "#00BCD4"))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(4)
    }

    // MARK: - Pull Request Tab

    private var pullRequestTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let state = appState.gitManager.repositoryState {
                    // Source branch
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.localized(.gitSourceBranch))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $prSourceBranch) {
                            ForEach(state.branches.filter { !$0.isRemote }, id: \.name) { branch in
                                Text(branch.name).tag(branch.name)
                            }
                        }
                        .labelsHidden()
                    }

                    // Target branch
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.localized(.gitTargetBranch))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $prTargetBranch) {
                            ForEach(state.branches.filter { !$0.isRemote }, id: \.name) { branch in
                                Text(branch.name).tag(branch.name)
                            }
                        }
                        .labelsHidden()
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // PR Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.localized(.gitPRTitle))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("", text: $prTitle)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    // PR Body
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.localized(.gitPRBody))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextEditor(text: $prBody)
                            .frame(height: 80)
                            .font(.system(size: 11))
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // Preview button
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await appState.gitManager.preparePRPreview(source: prSourceBranch, target: prTargetBranch)
                                if let pr = appState.gitManager.prPreview {
                                    prTitle = pr.title
                                }
                                appState.showGitPRPreviewInScene()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                Text(localization.localized(.gitPRPreview))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#58A6FF"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#58A6FF").opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            prCreating = true
                            Task {
                                let success = await appState.gitManager.createPR(
                                    title: prTitle,
                                    body: prBody,
                                    source: prSourceBranch,
                                    target: prTargetBranch
                                )
                                prCreating = false
                                prResult = success ? "PR created successfully!" : (appState.gitManager.lastError ?? "Failed to create PR")
                            }
                        }) {
                            HStack(spacing: 4) {
                                if prCreating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.pull")
                                }
                                Text(localization.localized(.gitCreatePR))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#238636"))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(prTitle.isEmpty || prCreating)
                    }

                    // Result message
                    if let result = prResult {
                        Text(result)
                            .font(.system(size: 11))
                            .foregroundColor(result.contains("success") ? Color(hex: "#4CAF50") : Color(hex: "#F44336"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                    }

                    // PR Preview summary
                    if let pr = appState.gitManager.prPreview {
                        Divider().background(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(pr.commits.count) commits  ·  \(pr.diffFiles.count) files")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                Text("+\(pr.totalAdditions)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#4CAF50"))
                                Text("-\(pr.totalDeletions)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#F44336"))
                            }

                            ForEach(pr.diffFiles.prefix(8)) { file in
                                diffFileRow(file)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Shared Components

    private func sceneToggleButton(isActive: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: isActive ? "cube.fill" : "cube")
                        .font(.system(size: 10))
                    Text(isActive ? localization.localized(.gitHideFromScene) : localization.localized(.gitShowInScene))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(isActive ? Color(hex: "#00BCD4") : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color(hex: "#00BCD4").opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String, count: Int?, color: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color(hex: color))
                .frame(width: 3, height: 14)
                .cornerRadius(1.5)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: color))
            if let count = count {
                Text("(\(count))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func emptyMessage(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
                .padding(.top, 40)
            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
