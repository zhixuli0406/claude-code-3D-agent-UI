import Foundation
import Combine
import SceneKit
import AppKit
import UniformTypeIdentifiers

/// Info about a streak that was just broken, used to trigger overlay animation
struct StreakBreakInfo {
    let lostStreak: Int
    let agentName: String
}

@MainActor
class AppState: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var tasks: [AgentTask] = []
    @Published var sceneConfig: SceneConfiguration?
    @Published var selectedAgentId: UUID?
    @Published var selectedTaskId: UUID?
    @Published var currentTheme: SceneTheme = .commandCenter
    @Published var showSceneSelection = true
    @Published var dangerousCommandAlert: DangerousCommandAlertData?
    @Published var askUserQuestionData: AskUserQuestionData?
    @Published var planReviewData: PlanReviewData?

    // Hover tooltip state
    @Published var hoveredAgentId: UUID?
    @Published var hoveredAgentScreenPos: CGPoint?

    // Right-click context menu state
    @Published var rightClickedAgentId: UUID?
    @Published var rightClickScreenPos: CGPoint?

    // Drag & Drop state
    @Published var dragHoveredAgentId: UUID?

    // Streak break state
    @Published var streakBreakInfo: StreakBreakInfo?

    // Camera state
    @Published var isPiPEnabled: Bool = false
    @Published var isFirstPersonMode: Bool = false
    @Published var firstPersonAgentId: UUID?

    // Mini-map & Exploration state (B6)
    @Published var isMiniMapVisible: Bool = false
    @Published var discoveryPopupItem: ExplorationItem?

    // Task Queue Visualization state (D1)
    @Published var isTaskQueueVisible: Bool = true
    @Published var taskQueueOrder: [UUID] = []

    // Performance Metrics state (D5)
    @Published var isMetricsVisible: Bool = false

    // Session History & Replay state (D4)
    @Published var isInReplayMode: Bool = false

    // Git Integration state (G3)
    @Published var isGitDiffVisible: Bool = false
    @Published var isGitBranchTreeVisible: Bool = false
    @Published var isGitCommitTimelineVisible: Bool = false

    // Prompt Templates state (G2)
    @Published var isTemplateGalleryVisible: Bool = false

    // Multi-Model Support state (G1)
    @Published var selectedModelForNewTeam: ClaudeModel = .sonnet
    @Published var isModelComparisonVisible: Bool = false

    // Help Overlay state (F1 keyboard shortcut)
    @Published var isHelpOverlayVisible: Bool = false

    // Multi-Window Support (D2)
    let windowManager = WindowManager()

    var localizationManager: LocalizationManager?
    let configLoader = ConfigurationLoader()
    let sceneManager = ThemeableScene()
    let cliProcessManager = CLIProcessManager()
    let workspaceManager = WorkspaceManager()
    let soundManager = SoundManager()
    let notificationManager = NotificationManager()
    let statsManager = AgentStatsManager()
    let achievementManager = AchievementManager()
    let timelineManager = TimelineManager()
    let coinManager = CoinManager()
    let skillManager = SkillManager()
    let skillsMPService = SkillsMPService()
    let explorationManager = ExplorationManager()
    let metricsManager = PerformanceMetricsManager()
    let sessionHistoryManager = SessionHistoryManager()
    let gitManager = GitIntegrationManager()
    let promptTemplateManager = PromptTemplateManager()
    let relationshipManager = AgentRelationshipManager()
    let backgroundMusicManager = BackgroundMusicManager()
    private let dayNightController = DayNightCycleController()
    /// Timer for personality idle behaviors (E1)
    private var idleBehaviorTimer: DispatchWorkItem?

    /// Tracks teams that are currently being disbanded (animation in progress)
    @Published var disbandingTeamIds: Set<UUID> = []

    /// How long (in seconds) a completed team stays before disbanding
    private let disbandDelay: TimeInterval = 8.0
    /// Pending disband work items, keyed by commander agent ID
    private var disbandTimers: [UUID: DispatchWorkItem] = [:]

    /// Cancellable for observing workspace changes
    private var workspaceCancellable: AnyCancellable?
    /// Forward gitManager changes so views observing AppState re-render
    private var gitManagerCancellable: AnyCancellable?

    /// Snapshot of state before replay, restored when replay stops
    private var preReplayAgents: [Agent]?
    private var preReplayTasks: [AgentTask]?
    private var preReplayTimelineEvents: [TimelineEvent]?
    private var preReplaySceneConfig: SceneConfiguration?
    private var preReplayTheme: SceneTheme?

    private static let themeKey = "selectedTheme"

    private static let miniMapKey = "miniMapVisible"
    private static let taskQueueKey = "taskQueueVisible"
    private static let metricsKey = "metricsVisible"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.themeKey),
           let theme = SceneTheme(rawValue: saved) {
            currentTheme = theme
            showSceneSelection = false
            // Start ambient environment sound for the restored theme
            soundManager.playAmbientSound(for: theme)
            // Start background music for the restored theme
            backgroundMusicManager.soundManager = soundManager
            backgroundMusicManager.playThemeMusic(theme)
        }
        if backgroundMusicManager.soundManager == nil {
            backgroundMusicManager.soundManager = soundManager
        }
        isMiniMapVisible = UserDefaults.standard.bool(forKey: Self.miniMapKey)
        // Default to true if key hasn't been set
        if UserDefaults.standard.object(forKey: Self.taskQueueKey) == nil {
            isTaskQueueVisible = true
        } else {
            isTaskQueueVisible = UserDefaults.standard.bool(forKey: Self.taskQueueKey)
        }
        isMetricsVisible = UserDefaults.standard.bool(forKey: Self.metricsKey)

        // Observe workspace changes and restart Git monitoring automatically
        workspaceCancellable = workspaceManager.$activeWorkspace
            .dropFirst() // skip initial value to avoid double-init
            .sink { [weak self] _ in
                guard let self else { return }
                if self.gitManager.isGitRepository || self.gitManager.repositoryState != nil {
                    // Git was previously monitoring — restart with new workspace
                    self.gitManager.startMonitoring(directory: self.workspaceManager.activeDirectory)
                }
            }

        // Forward gitManager's @Published changes so views observing AppState re-render.
        // Without this, nested ObservableObject changes are invisible to SwiftUI.
        gitManagerCancellable = gitManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func setTheme(_ theme: SceneTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        showSceneSelection = false
        achievementManager.onThemeUsed(theme.rawValue)

        // Switch ambient environment sound to match the new theme
        soundManager.playAmbientSound(for: theme)

        // Switch background music to match the new theme
        backgroundMusicManager.playThemeMusic(theme)

        // Play transition animation (agents teleport out, fade, rebuild, agents teleport in)
        sceneManager.playSceneTransition { [weak self] in
            Task { @MainActor in
                self?.rebuildScene()
                // Agents teleport back in after scene rebuild
                self?.sceneManager.teleportAllAgentsIn()
            }
        }
    }

    func showThemeSelection() {
        showSceneSelection = true
    }

    var selectedAgent: Agent? {
        guard let id = selectedAgentId else { return nil }
        return agents.first { $0.id == id }
    }

    var hoveredAgent: Agent? {
        guard let id = hoveredAgentId else { return nil }
        return agents.first { $0.id == id }
    }

    var hoveredAgentTask: AgentTask? {
        guard let agent = hoveredAgent else { return nil }
        // Prefer in-progress task, fallback to latest assigned task
        return tasks.first { $0.assignedAgentId == agent.id && $0.status == .inProgress }
            ?? tasks.last { agent.assignedTaskIds.contains($0.id) }
    }

    var tasksForSelectedAgent: [AgentTask] {
        guard let agent = selectedAgent else { return [] }
        return tasks.filter { agent.assignedTaskIds.contains($0.id) }
    }

    var selectedTask: AgentTask? {
        guard let id = selectedTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    var teamForSelectedTask: [Agent] {
        guard let task = selectedTask else { return [] }
        return agents.filter { task.teamAgentIds.contains($0.id) }
    }

    func selectTask(_ taskId: UUID) {
        selectedTaskId = taskId
        if let task = tasks.first(where: { $0.id == taskId }),
           let agentId = task.assignedAgentId {
            selectedAgentId = agentId
        }
    }

    func mainAgents() -> [Agent] {
        agents.filter { $0.isMainAgent }
    }

    func subAgents(of agentId: UUID) -> [Agent] {
        agents.filter { $0.parentAgentId == agentId }
    }

    // MARK: - Configuration Loading

    func loadSampleConfig() {
        let bundleAgents = configLoader.loadAgentsFromBundle()
        let bundleTasks = configLoader.loadTasksFromBundle()
        let bundleScene = configLoader.loadSceneConfigFromBundle()

        if !bundleAgents.isEmpty {
            // Preserve running CLI tasks
            let runningTasks = tasks.filter { $0.status == .inProgress && $0.isRealExecution }
            agents = bundleAgents
            tasks = bundleTasks + runningTasks
            sceneConfig = bundleScene

            // Re-link running tasks to agents
            for task in runningTasks {
                if let agentId = task.assignedAgentId,
                   let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    if !agents[idx].assignedTaskIds.contains(task.id) {
                        agents[idx].assignedTaskIds.append(task.id)
                    }
                    agents[idx].status = .working
                }
            }
        } else {
            loadFromSampleDirectory()
        }

        rebuildScene()
    }

    func loadFromDirectory(_ url: URL) {
        do {
            let result = try configLoader.loadAll(from: url)
            // Preserve running CLI tasks
            let runningTasks = tasks.filter { $0.status == .inProgress && $0.isRealExecution }
            agents = result.agents
            tasks = result.tasks + runningTasks
            sceneConfig = result.sceneConfig

            for task in runningTasks {
                if let agentId = task.assignedAgentId,
                   let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    if !agents[idx].assignedTaskIds.contains(task.id) {
                        agents[idx].assignedTaskIds.append(task.id)
                    }
                    agents[idx].status = .working
                }
            }

            rebuildScene()
        } catch {
            print("[AppState] Failed to load config: \(error)")
        }
    }

    // MARK: - Scene

    func rebuildScene() {
        let themeBuilder = SceneThemeBuilderFactory.builder(for: currentTheme)

        if agents.isEmpty {
            // No agents: build empty scene (environment only, no workstations)
            let config = sceneConfig ?? defaultSceneConfig()
            sceneManager.buildEmptyScene(config: config, themeBuilder: themeBuilder)
        } else {
            // Always use layout calculator to compute positions for all agents
            let layoutResult = MultiTeamLayoutCalculator.calculateLayout(agents: agents)

            // Apply computed positions to agents
            for (agentId, position) in layoutResult.agentPositions {
                if let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    agents[idx].position = position
                }
            }

            let config = SceneConfiguration.fromMultiTeam(
                layoutResult,
                intensity: sceneConfig?.ambientLightIntensity ?? 500,
                accent: sceneConfig?.accentColor ?? "#00BCD4"
            )
            sceneConfig = config
            sceneManager.buildScene(config: config, agents: agents, themeBuilder: themeBuilder)
        }

        // Start day/night cycle
        dayNightController.start(in: sceneManager.scene)

        // Apply level badges for existing agents
        for agent in agents {
            let stats = statsManager.statsFor(agentName: agent.name)
            if stats.level > 1 {
                sceneManager.updateLevelBadge(agentId: agent.id, level: stats.level)
            }
        }

        // Apply weather based on success rate
        applyWeatherEffect()

        // Apply cosmetics from shop
        applyAllCosmetics()

        // Place exploration items and initialize fog (B6)
        let themeId = currentTheme.rawValue
        let roomSize = (sceneConfig ?? defaultSceneConfig()).roomSize
        explorationManager.initializeDefaultFog(theme: themeId, roomSize: roomSize)
        let explorationItems = explorationManager.items(for: themeId)
        sceneManager.placeExplorationItems(explorationItems, discoveredIds: explorationManager.discoveredItemIds)
    }

    private func applyWeatherEffect() {
        // Remove existing weather
        sceneManager.scene.rootNode.childNode(withName: "weatherEffect", recursively: false)?.removeFromParentNode()

        // Calculate success rate from recent tasks
        let recentTasks = tasks.suffix(10)
        let completed = recentTasks.filter { $0.status == .completed }.count
        let failed = recentTasks.filter { $0.status == .failed }.count
        let total = completed + failed
        let rate = total > 0 ? Double(completed) / Double(total) : 0.8

        let weather = WeatherEffectBuilder.weatherForSuccessRate(rate)
        let config = sceneConfig ?? defaultSceneConfig()
        let weatherNode = WeatherEffectBuilder.buildWeather(weather, dimensions: config.roomSize)
        sceneManager.scene.rootNode.addChildNode(weatherNode)
    }

    func selectAgent(_ id: UUID) {
        // Clear previous highlight
        if let prevId = selectedAgentId, prevId != id {
            sceneManager.unhighlightAgent(prevId)
        }
        selectedAgentId = id
        sceneManager.highlightAgent(id)
    }

    func doubleClickAgent(_ id: UUID) {
        selectAgent(id)
        sceneManager.zoomToAgent(id)
    }

    func rightClickAgent(_ id: UUID, at screenPos: CGPoint) {
        rightClickedAgentId = id
        rightClickScreenPos = screenPos
    }

    // MARK: - Prompt Task Submission

    func submitPromptWithNewTeam(title: String) {
        // 1. Create a new team with selected model
        let newTeamAgents = AgentFactory.createTeam(subAgentCount: 2, model: selectedModelForNewTeam)
        guard let commander = newTeamAgents.first else { return }

        // 2. Add new agents
        agents.append(contentsOf: newTeamAgents)

        // 3. Rebuild 3D scene with new layout
        rebuildScene()

        // 4. Walk agents to their desks, then wave
        let agentIds = newTeamAgents.map(\.id)
        let walkGroup = DispatchGroup()

        for agent in newTeamAgents {
            walkGroup.enter()
            sceneManager.walkAgentToDesk(agent.id) {
                walkGroup.leave()
            }
        }

        walkGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Play waving animation after walking to desk
            for agentId in agentIds {
                self.sceneManager.playWaveForAgent(agentId)
            }

            // Submit the task after wave animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.submitPromptTask(title: title, assignTo: commander.id)
            }
        }
    }

    func submitPromptTask(title: String, assignTo agentId: UUID) {
        let taskId = UUID()
        let descendants = AgentCoordinator.allDescendants(of: agentId, in: agents)
        let teamIds = [agentId] + descendants.map(\.id)

        let newTask = AgentTask(
            id: taskId,
            title: title,
            description: "CLI task: \(title)",
            status: .inProgress,
            priority: .medium,
            assignedAgentId: agentId,
            subtasks: [],
            progress: 0,
            createdAt: Date(),
            estimatedDuration: 0,
            teamAgentIds: teamIds,
            isRealExecution: true
        )
        tasks.append(newTask)

        // Update lead agent (sub-agents will be propagated automatically)
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].assignedTaskIds.append(taskId)
        }
        handleAgentStatusChange(agentId, to: .working)

        // Auto-select the new task
        selectedTaskId = taskId

        // Record timeline event
        timelineManager.recordEvent(kind: .taskCreated, taskId: taskId, agentId: agentId, title: "Task created: \(title)")

        // D4: Start session recording if not already recording
        if !sessionHistoryManager.isRecording && !isInReplayMode {
            sessionHistoryManager.startSession(
                theme: currentTheme.rawValue,
                agents: agents,
                sceneConfig: sceneConfig
            )
        }

        startCLIProcess(taskId: taskId, agentId: agentId, prompt: title)
    }

    // MARK: - Drag & Drop Task Assignment

    func assignPendingTaskToAgent(taskId: UUID, agentId: UUID) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == taskId }),
              tasks[taskIdx].status == .pending else { return }
        guard let agent = agents.first(where: { $0.id == agentId }),
              agent.status == .idle else { return }

        let descendants = AgentCoordinator.allDescendants(of: agentId, in: agents)
        let teamIds = [agentId] + descendants.map(\.id)

        tasks[taskIdx].status = .inProgress
        tasks[taskIdx].assignedAgentId = agentId
        tasks[taskIdx].teamAgentIds = teamIds
        tasks[taskIdx].isRealExecution = true

        if let agentIdx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[agentIdx].assignedTaskIds.append(taskId)
        }
        handleAgentStatusChange(agentId, to: .working)
        selectedTaskId = taskId

        startCLIProcess(taskId: taskId, agentId: agentId, prompt: tasks[taskIdx].title)
    }

    func reassignAgentToTeam(agentId: UUID, newCommanderId: UUID) {
        guard let agentIdx = agents.firstIndex(where: { $0.id == agentId }),
              agents[agentIdx].status == .idle,
              !agents[agentIdx].isMainAgent,
              agentId != newCommanderId else { return }

        let oldParentId = agents[agentIdx].parentAgentId

        // Don't reassign to the same team
        guard oldParentId != newCommanderId else { return }

        // Remove from old parent
        if let oldParent = oldParentId,
           let oldParentIdx = agents.firstIndex(where: { $0.id == oldParent }) {
            agents[oldParentIdx].subAgentIds.removeAll { $0 == agentId }
        }

        // Add to new parent
        agents[agentIdx].parentAgentId = newCommanderId
        if let newParentIdx = agents.firstIndex(where: { $0.id == newCommanderId }) {
            agents[newParentIdx].subAgentIds.append(agentId)
        }

        rebuildScene()
    }

    func cancelTask(_ taskId: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        if tasks[idx].isRealExecution {
            cliProcessManager.cancelProcess(taskId: taskId)
        }
        tasks[idx].status = .failed

        timelineManager.recordEvent(kind: .taskCancelled, taskId: taskId, agentId: tasks[idx].assignedAgentId, title: "Task cancelled: \(tasks[idx].title)")

        // Reset commander to idle (sub-agents will be propagated automatically)
        if let leadId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(leadId, to: .idle)
            // Trigger team disband since cancelled teams should be dismissed
            scheduleDisbandIfNeeded(commanderId: leadId)
        }
    }

    private func startCLIProcess(taskId: UUID, agentId: UUID, prompt: String, resumeSessionId: String? = nil) {
        let workDir = workspaceManager.activeDirectory

        // G1: Look up the agent's selected model
        let model = agents.first(where: { $0.id == agentId })?.selectedModel ?? .sonnet

        // D5: Track task start
        metricsManager.taskStarted(taskId: taskId, agentId: agentId, prompt: prompt)

        let cliProcess = cliProcessManager.startProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: prompt,
            workingDirectory: workDir,
            model: model,
            resumeSessionId: resumeSessionId,
            onStatusChange: { [weak self] agentId, status in
                Task { @MainActor in
                    self?.handleAgentStatusChange(agentId, to: status)
                }
            },
            onProgress: { [weak self] taskId, progress in
                Task { @MainActor in
                    self?.handleTaskProgress(taskId, progress: progress)
                }
            },
            onCompleted: { [weak self] taskId, result in
                Task { @MainActor in
                    self?.handleCLICompleted(taskId, result: result)
                }
            },
            onFailed: { [weak self] taskId, error in
                Task { @MainActor in
                    self?.handleCLIFailed(taskId, error: error)
                }
            },
            onDangerousCommand: { [weak self] taskId, agentId, tool, input, reason in
                Task { @MainActor in
                    self?.handleDangerousCommand(taskId: taskId, agentId: agentId, tool: tool, input: input, reason: reason)
                }
            },
            onAskUserQuestion: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.handleAskUserQuestion(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onPlanReview: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.handlePlanReview(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onOutput: { [weak self] agentId, entry in
                Task { @MainActor in
                    self?.handleCLIOutput(agentId: agentId, entry: entry)
                }
            }
        )

        // D5: Register process PID for resource monitoring
        if cliProcess.processIdentifier > 0 {
            metricsManager.registerProcess(taskId: taskId, pid: cliProcess.processIdentifier)
        }
    }

    private func handleCLICompleted(_ taskId: UUID, result: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].status = .completed
        tasks[idx].progress = 1.0
        tasks[idx].completedAt = Date()
        tasks[idx].cliResult = result

        // D5: Extract cost/duration from CLI process output and record metrics
        let cliEntries = cliProcessManager.outputEntries(for: taskId)
        var costUSD: Double?
        var durationMs: Int?
        for entry in cliEntries {
            if entry.kind == .systemInfo {
                if entry.text.hasPrefix("Cost: $"), let cost = Double(entry.text.dropFirst(7)) {
                    costUSD = cost
                }
                if entry.text.hasPrefix("Duration: "), entry.text.hasSuffix("ms"),
                   let dur = Int(entry.text.dropFirst(10).dropLast(2)) {
                    durationMs = dur
                }
            }
        }
        metricsManager.taskCompleted(taskId: taskId, costUSD: costUSD, durationMs: durationMs)
        metricsManager.unregisterProcess(taskId: taskId)

        timelineManager.recordEvent(kind: .taskCompleted, taskId: taskId, agentId: tasks[idx].assignedAgentId, title: "Task completed: \(tasks[idx].title)")

        // D4: Update session recording
        if sessionHistoryManager.isRecording {
            sessionHistoryManager.updateSession(
                agents: agents, tasks: tasks,
                timelineEvents: timelineManager.events,
                cliOutputs: gatherCLIOutputs()
            )
        }

        // E1: Update mood and relationships for team agents
        updateMoodForTeam(teamAgentIds: tasks[idx].teamAgentIds, success: true)
        recordTeamRelationships(teamAgentIds: tasks[idx].teamAgentIds)

        // Update all team agents to completed
        for agentId in tasks[idx].teamAgentIds {
            handleAgentStatusChange(agentId, to: .completed)
        }

        // Track stats and achievements
        let duration = tasks[idx].completedAt.map { $0.timeIntervalSince(tasks[idx].createdAt) } ?? 0
        let teamSize = tasks[idx].teamAgentIds.count
        if let leadId = tasks[idx].assignedAgentId,
           let agent = agents.first(where: { $0.id == leadId }) {
            let result = statsManager.recordCompletion(agentName: agent.name, duration: duration)
            if result.leveledUp {
                soundManager.play(.levelUp)
                // Show level up particle effect
                let levelUp = ParticleEffectBuilder.buildLevelUpEffect()
                levelUp.position = SCNVector3(0, 1.0, 0)
                if let charPos = sceneManager.agentWorldPosition(leadId) {
                    levelUp.position = SCNVector3(charPos.x, charPos.y + 1.0, charPos.z)
                    sceneManager.scene.rootNode.addChildNode(levelUp)
                }

                // Update level badge
                let newLevel = statsManager.statsFor(agentName: agent.name).level
                sceneManager.updateLevelBadge(agentId: leadId, level: newLevel)

                // Apply newly unlocked accessory
                if let newAccessory = result.unlockedAccessory {
                    if let agentIdx = agents.firstIndex(where: { $0.id == leadId }) {
                        agents[agentIdx].appearance.accessory = newAccessory
                        sceneManager.replaceAccessory(agentId: leadId, accessory: newAccessory, appearance: agents[agentIdx].appearance)
                    }
                }
            }
            notificationManager.notifyTaskCompleted(taskTitle: tasks[idx].title, agentName: agent.name)

            // Award coins
            let streak = statsManager.statsFor(agentName: agent.name).currentStreak
            let coinReward = coinManager.earnCoins(agentName: agent.name, duration: duration, streak: streak)
            if coinReward.total > 0 {
                soundManager.play(.coinEarned)
            }
        }
        let beforeCount = achievementManager.unlockedAchievements.count
        achievementManager.onTaskCompleted(teamSize: teamSize, duration: duration)
        if achievementManager.unlockedAchievements.count > beforeCount {
            soundManager.play(.achievement)
        }

        // B6: Reveal fog and check for discoveries
        if let leadId = tasks[idx].assignedAgentId,
           let worldPos = sceneManager.agentWorldPosition(leadId) {
            let roomSize = (sceneConfig ?? defaultSceneConfig()).roomSize
            let themeId = currentTheme.rawValue
            explorationManager.revealFog(around: worldPos, radius: 3.0, theme: themeId, roomSize: roomSize)

            if let discovery = explorationManager.checkAndDiscover(near: worldPos, theme: themeId) {
                soundManager.play(.discovery)
                coinManager.awardBonus(discovery.coinReward)
                sceneManager.removeExplorationItem(itemId: discovery.id)
                discoveryPopupItem = discovery

                // Check exploration achievements
                let beforeAch = achievementManager.unlockedAchievements.count
                achievementManager.onItemDiscovered(
                    totalDiscovered: explorationManager.totalDiscovered,
                    fogPercentage: explorationManager.fogRevealPercentage(theme: themeId, roomSize: roomSize)
                )
                if achievementManager.unlockedAchievements.count > beforeAch {
                    soundManager.play(.achievement)
                }
            }
        }
    }

    private func handleCLIFailed(_ taskId: UUID, error: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].status = .failed
        tasks[idx].cliResult = "Error: \(error)"

        // D5: Record failure metrics
        metricsManager.taskFailed(taskId: taskId)
        metricsManager.unregisterProcess(taskId: taskId)

        timelineManager.recordEvent(kind: .taskFailed, taskId: taskId, agentId: tasks[idx].assignedAgentId, title: "Task failed: \(tasks[idx].title)", detail: String(error.prefix(100)))

        // D4: Update session recording
        if sessionHistoryManager.isRecording {
            sessionHistoryManager.updateSession(
                agents: agents, tasks: tasks,
                timelineEvents: timelineManager.events,
                cliOutputs: gatherCLIOutputs()
            )
        }

        // E1: Update mood for team agents on failure
        updateMoodForTeam(teamAgentIds: tasks[idx].teamAgentIds, success: false)

        // Update lead to error (sub-agents will be propagated to idle automatically)
        if let leadId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(leadId, to: .error)

            // Track failure and check for streak break
            if let agent = agents.first(where: { $0.id == leadId }) {
                let lostStreak = statsManager.recordFailure(agentName: agent.name)
                notificationManager.notifyTaskFailed(taskTitle: tasks[idx].title, agentName: agent.name)

                // Trigger streak-break effects if a streak was lost
                if lostStreak >= 2 {
                    soundManager.play(.streakBreak)
                    sceneManager.playStreakBreakEffect(agentId: leadId, lostStreak: lostStreak)
                    streakBreakInfo = StreakBreakInfo(lostStreak: lostStreak, agentName: agent.name)
                    // Auto-dismiss after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.streakBreakInfo = nil
                    }
                }
            }

            // Schedule team disband after a delay (same as completion flow)
            scheduleDisbandIfNeeded(commanderId: leadId)
        }
        achievementManager.onTaskFailed()
    }

    // MARK: - Dangerous Command Handling

    private func handleDangerousCommand(taskId: UUID, agentId: UUID, tool: String, input: String, reason: String) {
        // Set agent to requesting permission animation
        handleAgentStatusChange(agentId, to: .requestingPermission)

        timelineManager.recordEvent(kind: .permissionRequest, taskId: taskId, agentId: agentId, title: "Permission request: \(tool)", detail: reason)

        // Send native notification
        if let agent = agents.first(where: { $0.id == agentId }) {
            notificationManager.notifyPermissionRequest(agentName: agent.name, tool: tool)
        }

        // Show alert
        dangerousCommandAlert = DangerousCommandAlertData(
            taskId: taskId,
            agentId: agentId,
            tool: tool,
            input: input,
            reason: reason
        )
    }

    func dismissDangerousAlert() {
        if let alert = dangerousCommandAlert {
            // Resume agent to working
            handleAgentStatusChange(alert.agentId, to: .working)
        }
        dangerousCommandAlert = nil
    }

    func cancelDangerousTask() {
        if let alert = dangerousCommandAlert {
            cancelTask(alert.taskId)
        }
        dangerousCommandAlert = nil
    }

    // MARK: - AskUserQuestion Handling

    private func handleAskUserQuestion(taskId: UUID, agentId: UUID, sessionId: String, inputJSON: String) {
        guard let parsed = AskUserQuestionParser.parse(
            inputJSON: inputJSON,
            taskId: taskId,
            agentId: agentId,
            sessionId: sessionId
        ) else {
            print("[AppState] Failed to parse AskUserQuestion input")
            return
        }

        // Store sessionId on the task
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].sessionId = sessionId
        }

        // Set agent to waiting animation
        handleAgentStatusChange(agentId, to: .waitingForAnswer)

        timelineManager.recordEvent(kind: .userQuestion, taskId: taskId, agentId: agentId, title: "User question requested")

        // Show the question sheet
        askUserQuestionData = parsed
    }

    func submitAskUserAnswer(_ answers: [UserQuestionAnswer]) {
        guard let data = askUserQuestionData else { return }

        // Format answers into a natural language prompt for resume
        let answerText = formatAnswersAsPrompt(answers, questions: data.questions)

        // Dismiss the sheet
        askUserQuestionData = nil

        // Resume agent to working
        handleAgentStatusChange(data.agentId, to: .working)

        // Start a new CLI process with --resume
        startCLIProcess(
            taskId: data.taskId,
            agentId: data.agentId,
            prompt: answerText,
            resumeSessionId: data.sessionId
        )
    }

    func cancelAskUserQuestion() {
        if let data = askUserQuestionData {
            handleAgentStatusChange(data.agentId, to: .idle)
        }
        askUserQuestionData = nil
    }

    // MARK: - Plan Review Handling

    private func handlePlanReview(taskId: UUID, agentId: UUID, sessionId: String, inputJSON: String) {
        // Read the latest plan file
        let planContent = PlanReviewParser.readLatestPlanFile() ?? ""

        guard let parsed = PlanReviewParser.parse(
            inputJSON: inputJSON,
            planContent: planContent,
            taskId: taskId,
            agentId: agentId,
            sessionId: sessionId
        ) else {
            print("[AppState] Failed to parse plan review data")
            return
        }

        // Store sessionId on the task
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].sessionId = sessionId
        }

        // Set agent to reviewing plan animation
        handleAgentStatusChange(agentId, to: .reviewingPlan)

        timelineManager.recordEvent(kind: .planReview, taskId: taskId, agentId: agentId, title: "Plan review requested")

        // Show the plan review sheet
        planReviewData = parsed
    }

    func approvePlan() {
        guard let data = planReviewData else { return }

        // Dismiss the sheet
        planReviewData = nil

        // Resume agent to working
        handleAgentStatusChange(data.agentId, to: .working)

        // Track achievement
        achievementManager.onPlanApproved()

        // Start a new CLI process with --resume, approving the plan
        startCLIProcess(
            taskId: data.taskId,
            agentId: data.agentId,
            prompt: "yes",
            resumeSessionId: data.sessionId
        )
    }

    func rejectPlan(feedback: String?) {
        guard let data = planReviewData else { return }

        // Dismiss the sheet
        planReviewData = nil

        // Resume agent to working
        handleAgentStatusChange(data.agentId, to: .working)

        // Start a new CLI process with --resume, rejecting with feedback
        let rejectPrompt: String
        if let feedback = feedback, !feedback.isEmpty {
            rejectPrompt = "no, \(feedback)"
        } else {
            rejectPrompt = "no"
        }

        startCLIProcess(
            taskId: data.taskId,
            agentId: data.agentId,
            prompt: rejectPrompt,
            resumeSessionId: data.sessionId
        )
    }

    func cancelPlanReview() {
        if let data = planReviewData {
            handleAgentStatusChange(data.agentId, to: .idle)
        }
        planReviewData = nil
    }

    private func formatAnswersAsPrompt(_ answers: [UserQuestionAnswer], questions: [UserQuestion]) -> String {
        var parts: [String] = []
        for answer in answers {
            if let q = questions.first(where: { $0.id == answer.questionId }) {
                let header = q.header.isEmpty ? q.question : q.header
                if let custom = answer.customText, !custom.isEmpty {
                    parts.append("For \(header): \(custom)")
                } else if !answer.selectedOptions.isEmpty {
                    let selections = answer.selectedOptions.joined(separator: ", ")
                    parts.append("For \(header): I choose \(selections)")
                }
            }
        }
        return parts.isEmpty ? "Continue" : parts.joined(separator: ". ") + "."
    }

    // MARK: - Team Disband

    /// Schedule a completed or failed team to disband after a delay.
    private func scheduleDisbandIfNeeded(commanderId: UUID) {
        // Only schedule if the entire team is finished (completed or failed/error+idle)
        let teamAgents = [commanderId] + subAgents(of: commanderId).map(\.id)
        let allFinished = teamAgents.allSatisfy { agentId in
            guard let status = agents.first(where: { $0.id == agentId })?.status else { return false }
            return status == .completed || status == .error || status == .idle
        }
        guard allFinished else { return }

        // Don't schedule if already scheduled or disbanding
        guard disbandTimers[commanderId] == nil,
              !disbandingTeamIds.contains(commanderId) else { return }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.disbandTeam(commanderId: commanderId)
            }
        }
        disbandTimers[commanderId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + disbandDelay, execute: workItem)
    }

    /// Cancel a pending disband (e.g. if the team gets a new task).
    private func cancelDisbandTimer(commanderId: UUID) {
        disbandTimers[commanderId]?.cancel()
        disbandTimers.removeValue(forKey: commanderId)
    }

    /// Start the disband animation and then remove the team from data.
    private func disbandTeam(commanderId: UUID) {
        disbandTimers.removeValue(forKey: commanderId)

        let teamAgentIds = [commanderId] + subAgents(of: commanderId).map(\.id)

        // Verify team is still finished (might have been reactivated)
        let allFinished = teamAgentIds.allSatisfy { agentId in
            guard let status = agents.first(where: { $0.id == agentId })?.status else { return false }
            return status == .completed || status == .error || status == .idle
        }
        guard allFinished else { return }

        disbandingTeamIds.insert(commanderId)

        // Play disband animation in the 3D scene
        sceneManager.disbandTeam(agentIds: teamAgentIds) { [weak self] in
            Task { @MainActor in
                self?.removeTeamData(commanderId: commanderId, teamAgentIds: teamAgentIds)
            }
        }
    }

    /// Remove team agents and their tasks from data, then rebuild the scene.
    private func removeTeamData(commanderId: UUID, teamAgentIds: [UUID]) {
        let teamIdSet = Set(teamAgentIds)

        // Clear selection if it points to a disbanded agent/task
        if let selectedId = selectedAgentId, teamIdSet.contains(selectedId) {
            selectedAgentId = nil
        }
        if let selectedTId = selectedTaskId,
           let task = tasks.first(where: { $0.id == selectedTId }),
           let assignee = task.assignedAgentId,
           teamIdSet.contains(assignee) {
            selectedTaskId = nil
        }

        // Remove agents
        agents.removeAll { teamIdSet.contains($0.id) }

        // Remove associated completed/failed tasks
        tasks.removeAll { task in
            (task.status == .completed || task.status == .failed) && task.teamAgentIds.contains(where: { teamIdSet.contains($0) })
        }

        disbandingTeamIds.remove(commanderId)

        // D4: End session if no more active agents
        if agents.isEmpty && sessionHistoryManager.isRecording {
            sessionHistoryManager.endSession(
                agents: [],
                tasks: tasks,
                timelineEvents: timelineManager.events,
                cliOutputs: gatherCLIOutputs()
            )
        }

        // Rebuild scene layout (empty scene if no agents remain)
        rebuildScene()
    }

    // MARK: - Chat Bubble Output

    private func handleCLIOutput(agentId: UUID, entry: CLIOutputEntry) {
        // D5: Track metrics per output entry
        let taskId = tasks.first(where: { $0.assignedAgentId == agentId && $0.status == .inProgress })?.id

        switch entry.kind {
        case .assistantThinking:
            sceneManager.updateChatBubble(
                agentId: agentId,
                text: String(entry.text.prefix(60)),
                style: .thought,
                toolIcon: nil
            )
            if let taskId = taskId {
                metricsManager.recordAssistantText(taskId: taskId, textLength: entry.text.count)
            }
        case .toolInvocation:
            // Extract tool name from "Using tool: ToolName"
            let toolName = entry.text.replacingOccurrences(of: "Using tool: ", with: "")
            sceneManager.updateChatBubble(
                agentId: agentId,
                text: String(entry.text.prefix(50)),
                style: .speech,
                toolIcon: ToolIcon.from(toolName: toolName)
            )
            timelineManager.recordEvent(kind: .toolInvocation, taskId: taskId, agentId: agentId, title: "Tool: \(toolName)", cliEntryId: entry.id)
            if let taskId = taskId {
                metricsManager.recordToolCall(taskId: taskId, tool: toolName)
            }
        case .toolOutput:
            sceneManager.updateChatBubble(
                agentId: agentId,
                text: String(entry.text.prefix(50)),
                style: .speech,
                toolIcon: nil
            )
        case .error:
            sceneManager.updateChatBubble(
                agentId: agentId,
                text: "Error: " + String(entry.text.prefix(40)),
                style: .speech,
                toolIcon: nil
            )
        case .finalResult:
            sceneManager.hideChatBubble(agentId: agentId)
        default:
            break
        }
    }

    // MARK: - Private

    private func handleAgentStatusChange(_ agentId: UUID, to status: AgentStatus) {
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].status = status
        }
        sceneManager.updateAgentStatus(agentId, to: status)

        // Record significant status changes to timeline
        switch status {
        case .working, .completed, .error, .requestingPermission:
            let taskId = tasks.first(where: { $0.assignedAgentId == agentId && $0.status == .inProgress })?.id
            timelineManager.recordEvent(kind: .agentStatusChange, taskId: taskId, agentId: agentId, title: "Agent → \(status.rawValue)")
        default:
            break
        }

        // Sound effects
        switch status {
        case .completed:
            soundManager.play(.taskComplete)
            soundManager.stopTypingSounds()
            sceneManager.hideChatBubble(agentId: agentId)
        case .error:
            soundManager.play(.error)
            soundManager.stopTypingSounds()
        case .requestingPermission:
            soundManager.play(.permissionRequest)
            soundManager.stopTypingSounds()
        case .working:
            soundManager.startTypingSounds()
        case .idle:
            soundManager.stopTypingSounds()
            sceneManager.hideChatBubble(agentId: agentId)
        default:
            soundManager.stopTypingSounds()
        }

        // Dynamic background music intensity (F1)
        let hasWorkingAgents = agents.contains { $0.status == .working }
        backgroundMusicManager.setIntensity(hasWorkingAgents ? .active : .calm)

        // If this is a commander (main agent), propagate status to sub-agents
        if let agent = agents.first(where: { $0.id == agentId }), agent.isMainAgent {
            let subAgentStatus = subAgentStatusFor(commanderStatus: status)
            for sub in subAgents(of: agentId) {
                if let subIdx = agents.firstIndex(where: { $0.id == sub.id }) {
                    agents[subIdx].status = subAgentStatus
                }
                sceneManager.updateAgentStatus(sub.id, to: subAgentStatus)
            }

            // Trigger collaboration visit: a sub-agent walks to the commander occasionally
            if status == .working {
                triggerCollaborationVisit(commanderId: agentId)
            }
        }

        // If agent completed or errored, check if the whole team is done
        if status == .completed || status == .error {
            if let agent = agents.first(where: { $0.id == agentId }) {
                let commanderId = agent.isMainAgent ? agent.id : agent.parentAgentId
                if let commanderId = commanderId {
                    cancelCollaborationTimer(commanderId: commanderId)
                    scheduleDisbandIfNeeded(commanderId: commanderId)
                }
            }
        }

        // If team resumes work, cancel any pending disband
        if status == .working || status == .thinking {
            if let agent = agents.first(where: { $0.id == agentId }) {
                let commanderId = agent.isMainAgent ? agent.id : agent.parentAgentId
                if let commanderId = commanderId {
                    cancelDisbandTimer(commanderId: commanderId)
                }
            }
        }

        // Cancel collaboration timer on error/idle
        if status == .error || status == .idle {
            if let agent = agents.first(where: { $0.id == agentId }), agent.isMainAgent {
                cancelCollaborationTimer(commanderId: agentId)
            }
        }

        // E1: Start/stop idle behavior timer based on status
        if status == .idle {
            startIdleBehaviorTimer()
        }
    }

    /// Determine what status sub-agents should have based on their commander's status.
    private func subAgentStatusFor(commanderStatus: AgentStatus) -> AgentStatus {
        switch commanderStatus {
        case .thinking:
            return .thinking
        case .working:
            return .working
        case .completed:
            return .completed
        case .error:
            return .idle
        case .idle:
            return .idle
        case .requestingPermission:
            return .idle
        case .waitingForAnswer:
            return .idle
        case .reviewingPlan:
            return .thinking
        }
    }

    private func handleTaskProgress(_ taskId: UUID, progress: Double) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].progress = progress

        if progress >= 1.0 {
            tasks[idx].status = .completed
            tasks[idx].completedAt = Date()

            for si in tasks[idx].subtasks.indices {
                tasks[idx].subtasks[si].isCompleted = true
            }

            if let agentId = tasks[idx].assignedAgentId,
               let agentIdx = agents.firstIndex(where: { $0.id == agentId }) {
                let agentTasks = tasks.filter { agents[agentIdx].assignedTaskIds.contains($0.id) }
                if agentTasks.allSatisfy({ $0.status == .completed }) {
                    agents[agentIdx].status = .completed
                    sceneManager.updateAgentStatus(agentId, to: .completed)
                }
            }
        } else {
            let totalSubtasks = tasks[idx].subtasks.count
            let completedCount = Int(progress * Double(totalSubtasks))
            for si in tasks[idx].subtasks.indices {
                tasks[idx].subtasks[si].isCompleted = si < completedCount
            }
        }
    }

    private func loadFromSampleDirectory() {
        let execURL = Bundle.main.bundleURL
        let configDir = execURL.appendingPathComponent("Contents/Resources/SampleConfigs")
        if FileManager.default.fileExists(atPath: configDir.path) {
            loadFromDirectory(configDir)
        }
    }

    // MARK: - Mini-map (B6)

    func toggleMiniMap() {
        isMiniMapVisible.toggle()
        UserDefaults.standard.set(isMiniMapVisible, forKey: Self.miniMapKey)
    }

    func dismissDiscoveryPopup() {
        discoveryPopupItem = nil
    }

    // MARK: - Performance Metrics (D5)

    func toggleMetrics() {
        isMetricsVisible.toggle()
        UserDefaults.standard.set(isMetricsVisible, forKey: Self.metricsKey)
    }

    // MARK: - Prompt Templates (G2)

    func toggleTemplateGallery() {
        isTemplateGalleryVisible.toggle()
    }

    // MARK: - Help Overlay (F1)

    func toggleHelpOverlay() {
        isHelpOverlayVisible.toggle()
    }

    // MARK: - Multi-Model Support (G1)

    func toggleModelComparison() {
        isModelComparisonVisible.toggle()
    }

    // MARK: - Task Queue (D1)

    func toggleTaskQueue() {
        isTaskQueueVisible.toggle()
        UserDefaults.standard.set(isTaskQueueVisible, forKey: Self.taskQueueKey)
    }

    /// Pending tasks ordered by custom queue order, falling back to priority descending
    var pendingTasksOrdered: [AgentTask] {
        let pending = tasks.filter { $0.status == .pending }
        if taskQueueOrder.isEmpty {
            return pending.sorted { $0.priority.sortOrder > $1.priority.sortOrder }
        }
        return pending.sorted { a, b in
            let ai = taskQueueOrder.firstIndex(of: a.id) ?? Int.max
            let bi = taskQueueOrder.firstIndex(of: b.id) ?? Int.max
            return ai < bi
        }
    }

    func reorderTaskQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = pendingTasksOrdered.map(\.id)
        ordered.move(fromOffsets: source, toOffset: destination)
        taskQueueOrder = ordered
    }

    // MARK: - Camera Controls

    func togglePiP() {
        isPiPEnabled.toggle()
        if !isPiPEnabled {
            sceneManager.removePiPCamera()
        }
    }

    func toggleFirstPerson() {
        guard let agentId = selectedAgentId else { return }
        if isFirstPersonMode {
            exitFirstPerson()
        } else {
            isFirstPersonMode = true
            firstPersonAgentId = agentId
            sceneManager.enterFirstPerson(agentId: agentId)
        }
    }

    func exitFirstPerson() {
        guard isFirstPersonMode else { return }
        isFirstPersonMode = false
        firstPersonAgentId = nil
        sceneManager.exitFirstPerson()
    }

    // MARK: - Timeline Export

    func exportTimeline() {
        let markdown = timelineManager.exportMarkdown(agents: agents, tasks: tasks)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "timeline-report.md"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Cosmetic System

    /// Apply all equipped cosmetics to an agent's 3D character
    func applyCosmeticsToAgent(agentName: String) {
        guard let agent = agents.first(where: { $0.name == agentName }) else { return }
        let loadout = coinManager.loadout(forAgent: agentName)

        // Apply cosmetic hat
        if let hatId = loadout.equippedHatId,
           let item = CosmeticCatalog.item(byId: hatId),
           let hatStyle = item.hatStyle {
            sceneManager.applyCosmeticHat(agentId: agent.id, hatStyle: hatStyle, appearance: agent.appearance)
        } else {
            sceneManager.removeCosmeticHat(agentId: agent.id)
            // Restore level-based accessory if any
            if let accessory = agent.appearance.accessory {
                sceneManager.replaceAccessory(agentId: agent.id, accessory: accessory, appearance: agent.appearance)
            }
        }

        // Apply cosmetic particle
        if let particleId = loadout.equippedParticleId,
           let item = CosmeticCatalog.item(byId: particleId),
           let colorHex = item.particleColorHex {
            sceneManager.applyCosmeticParticle(agentId: agent.id, colorHex: colorHex, itemId: item.id)
        } else {
            sceneManager.removeCosmeticParticle(agentId: agent.id)
        }

        // Apply name tag with title
        let title = coinManager.equippedTitle(forAgent: agentName)
        if title != nil {
            sceneManager.applyNameTag(agentId: agent.id, agentName: agentName, title: title)
        } else {
            sceneManager.removeNameTag(agentId: agent.id)
        }

        // Apply cosmetic skin
        if let skinId = loadout.equippedSkinId,
           let item = CosmeticCatalog.item(byId: skinId),
           let skinColors = item.skinColors {
            sceneManager.applyCosmeticSkin(agentId: agent.id, skinColors: skinColors, role: agent.role, hairStyle: agent.appearance.hairStyle)
        }
    }

    /// Apply cosmetics for all agents after scene rebuild
    func applyAllCosmetics() {
        for agent in agents {
            applyCosmeticsToAgent(agentName: agent.name)
        }
    }

    // MARK: - Collaboration Visit

    /// Periodically trigger a sub-agent to walk over and visit the commander
    private var collaborationTimers: [UUID: DispatchWorkItem] = [:]

    private func triggerCollaborationVisit(commanderId: UUID) {
        // Don't schedule if already scheduled
        guard collaborationTimers[commanderId] == nil else { return }

        let subs = subAgents(of: commanderId)
        guard !subs.isEmpty else { return }

        // Schedule a visit after a random delay (10-25 seconds)
        let delay = Double.random(in: 10...25)
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.collaborationTimers.removeValue(forKey: commanderId)

                // Check commander is still working
                guard let commander = self.agents.first(where: { $0.id == commanderId }),
                      commander.status == .working else { return }

                // Pick a random sub-agent that isn't already walking
                let availableSubs = self.subAgents(of: commanderId).filter { !self.sceneManager.isAgentWalking($0.id) }
                guard let visitor = availableSubs.randomElement() else { return }

                self.sceneManager.visitAgent(visitorId: visitor.id, targetId: commanderId) { [weak self] in
                    // After visit completes, schedule another if still working
                    guard let self = self else { return }
                    if let cmd = self.agents.first(where: { $0.id == commanderId }), cmd.status == .working {
                        self.triggerCollaborationVisit(commanderId: commanderId)
                    }
                }
            }
        }
        collaborationTimers[commanderId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelCollaborationTimer(commanderId: UUID) {
        collaborationTimers[commanderId]?.cancel()
        collaborationTimers.removeValue(forKey: commanderId)
    }

    // MARK: - Session History & Replay (D4)

    /// Gather CLI output entries from all active processes
    private func gatherCLIOutputs() -> [UUID: [CLIOutputEntry]] {
        var outputs: [UUID: [CLIOutputEntry]] = [:]
        for task in tasks {
            let entries = cliProcessManager.outputEntries(for: task.id)
            if !entries.isEmpty {
                outputs[task.id] = entries
            }
        }
        return outputs
    }

    func startSessionReplay(_ session: SessionRecord) {
        isInReplayMode = true

        // Save current state so we can restore it when replay stops
        preReplayAgents = agents
        preReplayTasks = tasks
        preReplayTimelineEvents = timelineManager.events
        preReplaySceneConfig = sceneConfig
        preReplayTheme = currentTheme

        // Restore agents and tasks from session snapshot
        agents = session.agents
        tasks = session.tasks

        if let config = session.sceneConfig {
            sceneConfig = config
        }
        if let theme = SceneTheme(rawValue: session.theme) {
            currentTheme = theme
        }

        // Clear timeline for replay
        timelineManager.events = []

        // Rebuild 3D scene with session data
        rebuildScene()

        // Reset all agents to idle initially (replay will drive status changes)
        for i in agents.indices {
            agents[i].status = .idle
            sceneManager.updateAgentStatus(agents[i].id, to: .idle)
        }

        // Start replay
        sessionHistoryManager.startReplay(session: session) { [weak self] event in
            Task { @MainActor in
                self?.applyReplayEvent(event)
            }
        }
    }

    func stopSessionReplay() {
        isInReplayMode = false
        sessionHistoryManager.stopReplay()

        // Restore pre-replay state
        agents = preReplayAgents ?? []
        tasks = preReplayTasks ?? []
        timelineManager.events = preReplayTimelineEvents ?? []
        if let config = preReplaySceneConfig {
            sceneConfig = config
        }
        if let theme = preReplayTheme {
            currentTheme = theme
        }

        // Clear saved snapshots
        preReplayAgents = nil
        preReplayTasks = nil
        preReplayTimelineEvents = nil
        preReplaySceneConfig = nil
        preReplayTheme = nil

        rebuildScene()
    }

    private func applyReplayEvent(_ event: TimelineEvent) {
        // Add event to timeline for display
        timelineManager.events.append(event)

        // Drive 3D scene changes based on event kind
        switch event.kind {
        case .agentStatusChange:
            if let agentId = event.agentId {
                let status = parseStatusFromTitle(event.title)
                if let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    agents[idx].status = status
                }
                sceneManager.updateAgentStatus(agentId, to: status)
            }
        case .taskCompleted:
            if let agentId = event.agentId {
                if let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    agents[idx].status = .completed
                }
                sceneManager.updateAgentStatus(agentId, to: .completed)
            }
        case .taskFailed:
            if let agentId = event.agentId {
                if let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    agents[idx].status = .error
                }
                sceneManager.updateAgentStatus(agentId, to: .error)
            }
        case .toolInvocation:
            if let agentId = event.agentId {
                let toolName = event.title.replacingOccurrences(of: "Tool: ", with: "")
                sceneManager.updateChatBubble(
                    agentId: agentId,
                    text: event.title,
                    style: .speech,
                    toolIcon: ToolIcon.from(toolName: toolName)
                )
            }
        case .taskCreated:
            if let taskId = event.taskId,
               let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[idx].status = .inProgress
            }
            if let agentId = event.agentId {
                if let idx = agents.firstIndex(where: { $0.id == agentId }) {
                    agents[idx].status = .working
                }
                sceneManager.updateAgentStatus(agentId, to: .working)
            }
        default:
            break
        }
    }

    private func parseStatusFromTitle(_ title: String) -> AgentStatus {
        // title format: "Agent → working"
        let parts = title.components(separatedBy: "→")
        guard parts.count >= 2 else { return .idle }
        let statusRaw = parts.last!.trimmingCharacters(in: .whitespaces)
        return AgentStatus(rawValue: statusRaw) ?? .idle
    }

    // MARK: - Git Integration (G3)

    func startGitMonitoring() {
        gitManager.startMonitoring(directory: workspaceManager.activeDirectory)
    }

    func toggleGitDiff() {
        isGitDiffVisible.toggle()
        if isGitDiffVisible {
            guard let state = gitManager.repositoryState else { return }
            let allDiffs = state.stagedFiles + state.unstagedFiles
            sceneManager.showGitDiffPanels(allDiffs)
        } else {
            sceneManager.removeGitDiffPanels()
        }
    }

    func toggleGitBranchTree() {
        isGitBranchTreeVisible.toggle()
        if isGitBranchTreeVisible {
            guard let state = gitManager.repositoryState else { return }
            sceneManager.showGitBranchTree(state.branches, currentBranch: state.currentBranch)
        } else {
            sceneManager.removeGitBranchTree()
        }
    }

    func toggleGitCommitTimeline() {
        isGitCommitTimelineVisible.toggle()
        if isGitCommitTimelineVisible {
            guard let state = gitManager.repositoryState else { return }
            sceneManager.showGitCommitTimeline(state.recentCommits, agents: agents)
        } else {
            sceneManager.removeGitCommitTimeline()
        }
    }

    func showGitPRPreviewInScene() {
        guard let pr = gitManager.prPreview else { return }
        sceneManager.showGitPRPreview(pr)
    }

    func hideGitPRPreviewFromScene() {
        sceneManager.removeGitPRPreview()
    }

    // MARK: - Agent Personality System (E1)

    /// Update mood for all agents in a team based on task outcome
    private func updateMoodForTeam(teamAgentIds: [UUID], success: Bool) {
        for agentId in teamAgentIds {
            guard let idx = agents.firstIndex(where: { $0.id == agentId }) else { continue }

            if success {
                let stats = statsManager.statsFor(agentName: agents[idx].name)
                if stats.currentStreak >= 3 {
                    agents[idx].personality.mood = .excited
                } else {
                    agents[idx].personality.mood = .happy
                }
            } else {
                agents[idx].personality.mood = .stressed
            }

            // Show mood indicator in 3D scene
            sceneManager.showMoodIndicator(agentId: agentId, mood: agents[idx].personality.mood)

            // Mood decays back to neutral after some time
            let capturedMood = agents[idx].personality.mood
            if capturedMood != .neutral {
                DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                    guard let self = self,
                          let idx = self.agents.firstIndex(where: { $0.id == agentId }),
                          self.agents[idx].personality.mood == capturedMood else { return }
                    self.agents[idx].personality.mood = .neutral
                }
            }
        }
    }

    /// Record collaboration relationships between team members
    private func recordTeamRelationships(teamAgentIds: [UUID]) {
        let names = teamAgentIds.compactMap { id in
            agents.first { $0.id == id }?.name
        }
        // Record pairwise relationships
        for i in 0..<names.count {
            for j in (i+1)..<names.count {
                relationshipManager.recordCollaboration(agentA: names[i], agentB: names[j])
            }
        }
    }

    /// Start a repeating timer that triggers idle behaviors on idle agents
    private func startIdleBehaviorTimer() {
        // Don't start if already running
        guard idleBehaviorTimer == nil else { return }

        scheduleNextIdleBehavior()
    }

    private func scheduleNextIdleBehavior() {
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.tickIdleBehaviors()
                self?.scheduleNextIdleBehavior()
            }
        }
        idleBehaviorTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    /// Stop the idle behavior timer
    func stopIdleBehaviorTimer() {
        idleBehaviorTimer?.cancel()
        idleBehaviorTimer = nil
    }

    /// Check all idle agents and potentially trigger idle behaviors
    private func tickIdleBehaviors() {
        let now = Date()
        let idleAgents = agents.filter { $0.status == .idle }

        guard !idleAgents.isEmpty else {
            // No idle agents, stop the timer
            stopIdleBehaviorTimer()
            return
        }

        for agent in idleAgents {
            guard let idx = agents.firstIndex(where: { $0.id == agent.id }) else { continue }
            let personality = agents[idx].personality
            let lastTime = personality.lastIdleBehaviorTime ?? Date.distantPast
            let elapsed = now.timeIntervalSince(lastTime)

            if elapsed >= personality.idleBehaviorInterval {
                // Trigger a random idle behavior
                let behavior = personality.randomIdleBehavior()
                sceneManager.triggerIdleBehavior(agentId: agent.id, behavior: behavior)
                agents[idx].personality.lastIdleBehaviorTime = now
            }
        }
    }

    private func defaultSceneConfig() -> SceneConfiguration {
        SceneConfiguration(
            roomSize: RoomDimensions(width: 20, height: 5, depth: 15),
            commandDeskPosition: ScenePosition(x: 0, y: 0, z: -2, rotation: 0),
            workstationPositions: [
                WorkstationConfig(id: "ws-1", position: ScenePosition(x: -4, y: 0, z: 2, rotation: 0.3), size: .medium),
                WorkstationConfig(id: "ws-2", position: ScenePosition(x: 4, y: 0, z: 2, rotation: -0.3), size: .medium),
                WorkstationConfig(id: "ws-3", position: ScenePosition(x: -4, y: 0, z: 5, rotation: 0.3), size: .small),
                WorkstationConfig(id: "ws-4", position: ScenePosition(x: 4, y: 0, z: 5, rotation: -0.3), size: .small)
            ],
            teamLayouts: nil,
            cameraDefaults: CameraConfig(
                position: ScenePosition(x: 0, y: 8, z: 12, rotation: 0),
                lookAtTarget: ScenePosition(x: 0, y: 1, z: 0, rotation: 0),
                fieldOfView: 60
            ),
            ambientLightIntensity: 500,
            accentColor: "#00BCD4"
        )
    }
}
