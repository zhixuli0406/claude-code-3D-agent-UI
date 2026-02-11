import Foundation
import Combine

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

    var localizationManager: LocalizationManager?
    let configLoader = ConfigurationLoader()
    let sceneManager = ThemeableScene()
    let cliProcessManager = CLIProcessManager()
    let workspaceManager = WorkspaceManager()

    /// Tracks teams that are currently being disbanded (animation in progress)
    @Published var disbandingTeamIds: Set<UUID> = []

    /// How long (in seconds) a completed team stays before disbanding
    private let disbandDelay: TimeInterval = 8.0
    /// Pending disband work items, keyed by commander agent ID
    private var disbandTimers: [UUID: DispatchWorkItem] = [:]

    private static let themeKey = "selectedTheme"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.themeKey),
           let theme = SceneTheme(rawValue: saved) {
            currentTheme = theme
            showSceneSelection = false
        }
    }

    func setTheme(_ theme: SceneTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        showSceneSelection = false
        rebuildScene()
    }

    func showThemeSelection() {
        showSceneSelection = true
    }

    var selectedAgent: Agent? {
        guard let id = selectedAgentId else { return nil }
        return agents.first { $0.id == id }
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
    }

    func selectAgent(_ id: UUID) {
        selectedAgentId = id
    }

    // MARK: - Prompt Task Submission

    func submitPromptWithNewTeam(title: String) {
        // 1. Create a new team
        let newTeamAgents = AgentFactory.createTeam(subAgentCount: 2)
        guard let commander = newTeamAgents.first else { return }

        // 2. Add new agents
        agents.append(contentsOf: newTeamAgents)

        // 3. Rebuild 3D scene with new layout
        rebuildScene()

        // 4. Submit the task to the new commander
        submitPromptTask(title: title, assignTo: commander.id)
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

        startCLIProcess(taskId: taskId, agentId: agentId, prompt: title)
    }

    func cancelTask(_ taskId: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        if tasks[idx].isRealExecution {
            cliProcessManager.cancelProcess(taskId: taskId)
        }
        tasks[idx].status = .failed
        // Reset commander to idle (sub-agents will be propagated automatically)
        if let leadId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(leadId, to: .idle)
        }
    }

    private func startCLIProcess(taskId: UUID, agentId: UUID, prompt: String, resumeSessionId: String? = nil) {
        let workDir = workspaceManager.activeDirectory

        let _ = cliProcessManager.startProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: prompt,
            workingDirectory: workDir,
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
            }
        )
    }

    private func handleCLICompleted(_ taskId: UUID, result: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].status = .completed
        tasks[idx].progress = 1.0
        tasks[idx].completedAt = Date()
        tasks[idx].cliResult = result

        // Update all team agents to completed
        for agentId in tasks[idx].teamAgentIds {
            handleAgentStatusChange(agentId, to: .completed)
        }
    }

    private func handleCLIFailed(_ taskId: UUID, error: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].status = .failed
        tasks[idx].cliResult = "Error: \(error)"

        // Update lead to error (sub-agents will be propagated to idle automatically)
        if let leadId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(leadId, to: .error)
        }
    }

    // MARK: - Dangerous Command Handling

    private func handleDangerousCommand(taskId: UUID, agentId: UUID, tool: String, input: String, reason: String) {
        // Set agent to requesting permission animation
        handleAgentStatusChange(agentId, to: .requestingPermission)

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

        // Show the plan review sheet
        planReviewData = parsed
    }

    func approvePlan() {
        guard let data = planReviewData else { return }

        // Dismiss the sheet
        planReviewData = nil

        // Resume agent to working
        handleAgentStatusChange(data.agentId, to: .working)

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

    /// Schedule a completed team to disband after a delay.
    private func scheduleDisbandIfNeeded(commanderId: UUID) {
        // Only schedule if the entire team is completed
        let teamAgents = [commanderId] + subAgents(of: commanderId).map(\.id)
        let allCompleted = teamAgents.allSatisfy { agentId in
            agents.first(where: { $0.id == agentId })?.status == .completed
        }
        guard allCompleted else { return }

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

        // Verify team is still completed (might have been reactivated)
        let allCompleted = teamAgentIds.allSatisfy { agentId in
            agents.first(where: { $0.id == agentId })?.status == .completed
        }
        guard allCompleted else { return }

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

        // Remove associated completed tasks
        tasks.removeAll { task in
            task.status == .completed && task.teamAgentIds.contains(where: { teamIdSet.contains($0) })
        }

        disbandingTeamIds.remove(commanderId)

        // Rebuild scene layout (empty scene if no agents remain)
        rebuildScene()
    }

    // MARK: - Private

    private func handleAgentStatusChange(_ agentId: UUID, to status: AgentStatus) {
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].status = status
        }
        sceneManager.updateAgentStatus(agentId, to: status)

        // If this is a commander (main agent), propagate status to sub-agents
        if let agent = agents.first(where: { $0.id == agentId }), agent.isMainAgent {
            let subAgentStatus = subAgentStatusFor(commanderStatus: status)
            for sub in subAgents(of: agentId) {
                if let subIdx = agents.firstIndex(where: { $0.id == sub.id }) {
                    agents[subIdx].status = subAgentStatus
                }
                sceneManager.updateAgentStatus(sub.id, to: subAgentStatus)
            }
        }

        // If agent completed, check if the whole team is done
        if status == .completed {
            if let agent = agents.first(where: { $0.id == agentId }) {
                let commanderId = agent.isMainAgent ? agent.id : agent.parentAgentId
                if let commanderId = commanderId {
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
