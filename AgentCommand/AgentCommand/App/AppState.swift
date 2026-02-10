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

    var localizationManager: LocalizationManager?
    let configLoader = ConfigurationLoader()
    let sceneManager = ThemeableScene()
    let cliProcessManager = CLIProcessManager()
    let workspaceManager = WorkspaceManager()

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
            agents = bundleAgents
            tasks = bundleTasks
            sceneConfig = bundleScene
        } else {
            loadFromSampleDirectory()
        }

        rebuildScene()
    }

    func loadFromDirectory(_ url: URL) {
        do {
            let result = try configLoader.loadAll(from: url)
            agents = result.agents
            tasks = result.tasks
            sceneConfig = result.sceneConfig
            rebuildScene()
        } catch {
            print("[AppState] Failed to load config: \(error)")
        }
    }

    // MARK: - Scene

    func rebuildScene() {
        let config = sceneConfig ?? defaultSceneConfig()
        let themeBuilder = SceneThemeBuilderFactory.builder(for: currentTheme)
        sceneManager.buildScene(config: config, agents: agents, themeBuilder: themeBuilder)
    }

    func selectAgent(_ id: UUID) {
        selectedAgentId = id
    }

    // MARK: - Prompt Task Submission

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

        // Update lead agent
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].assignedTaskIds.append(taskId)
            agents[idx].status = .working
            sceneManager.updateAgentStatus(agentId, to: .working)
        }

        // Update team members to thinking
        for descendant in descendants {
            if let idx = agents.firstIndex(where: { $0.id == descendant.id }) {
                agents[idx].status = .thinking
                sceneManager.updateAgentStatus(descendant.id, to: .thinking)
            }
        }

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
        // Reset all team agents to idle
        for agentId in tasks[idx].teamAgentIds {
            handleAgentStatusChange(agentId, to: .idle)
        }
    }

    private func startCLIProcess(taskId: UUID, agentId: UUID, prompt: String) {
        let workDir = workspaceManager.activeDirectory

        let _ = cliProcessManager.startProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: prompt,
            workingDirectory: workDir,
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

        // Update lead to error, team members to idle
        if let leadId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(leadId, to: .error)
        }
        let teamWithoutLead = tasks[idx].teamAgentIds.filter { $0 != tasks[idx].assignedAgentId }
        for agentId in teamWithoutLead {
            handleAgentStatusChange(agentId, to: .idle)
        }
    }

    func bestAvailableAgent() -> Agent? {
        if let idle = agents.first(where: { $0.status == .idle }) {
            return idle
        }
        if let main = agents.first(where: { $0.isMainAgent }) {
            return main
        }
        return agents.first
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

    // MARK: - Private

    private func handleAgentStatusChange(_ agentId: UUID, to status: AgentStatus) {
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].status = status
        }
        sceneManager.updateAgentStatus(agentId, to: status)
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
