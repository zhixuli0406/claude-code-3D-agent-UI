import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var tasks: [AgentTask] = []
    @Published var sceneConfig: SceneConfiguration?
    @Published var selectedAgentId: UUID?
    @Published var isSimulationRunning = false
    @Published var currentTheme: SceneTheme = .commandCenter
    @Published var showSceneSelection = true
    @Published var executionMode: ExecutionMode = .simulation

    enum ExecutionMode: String {
        case simulation
        case live
    }

    var localizationManager: LocalizationManager?
    let configLoader = ConfigurationLoader()
    let sceneManager = ThemeableScene()
    lazy var taskEngine = TaskEngine()
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

    func mainAgents() -> [Agent] {
        agents.filter { $0.isMainAgent }
    }

    func subAgents(of agentId: UUID) -> [Agent] {
        agents.filter { $0.parentAgentId == agentId }
    }

    // MARK: - Configuration Loading

    func loadSampleConfig() {
        // Try loading from bundle first
        let bundleAgents = configLoader.loadAgentsFromBundle()
        let bundleTasks = configLoader.loadTasksFromBundle()
        let bundleScene = configLoader.loadSceneConfigFromBundle()

        if !bundleAgents.isEmpty {
            agents = bundleAgents
            tasks = bundleTasks
            sceneConfig = bundleScene
        } else {
            // Fallback: load from file path
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

    // MARK: - Simulation

    func startSimulation() {
        guard !isSimulationRunning else { return }
        isSimulationRunning = true

        // Set all pending tasks to in-progress
        for i in tasks.indices where tasks[i].status == .pending {
            tasks[i].status = .inProgress
        }

        // Update agent statuses
        for i in agents.indices {
            let agentTasks = tasks.filter { agents[i].assignedTaskIds.contains($0.id) }
            if agentTasks.contains(where: { $0.status == .inProgress }) {
                agents[i].status = .working
                sceneManager.updateAgentStatus(agents[i].id, to: .working)
            }
        }

        taskEngine.startSimulation(
            agents: agents,
            tasks: tasks,
            onStatusChange: { [weak self] agentId, status in
                Task { @MainActor in
                    self?.handleAgentStatusChange(agentId, to: status)
                }
            },
            onTaskProgress: { [weak self] taskId, progress in
                Task { @MainActor in
                    self?.handleTaskProgress(taskId, progress: progress)
                }
            }
        )
    }

    func pauseSimulation() {
        isSimulationRunning = false
        taskEngine.stop()

        for i in agents.indices where agents[i].status == .working {
            agents[i].status = .idle
            sceneManager.updateAgentStatus(agents[i].id, to: .idle)
        }
    }

    func resetSimulation() {
        taskEngine.stop()
        isSimulationRunning = false
        loadSampleConfig()
    }

    // MARK: - Prompt Task Submission

    func submitPromptTask(title: String, assignTo agentId: UUID) {
        let taskId = UUID()
        let isLive = (executionMode == .live)
        let newTask = AgentTask(
            id: taskId,
            title: title,
            description: isLive ? "CLI task: \(title)" : "User task: \(title)",
            status: .inProgress,
            priority: .medium,
            assignedAgentId: agentId,
            subtasks: isLive ? [] : generateSubtasks(for: title),
            progress: 0,
            createdAt: Date(),
            estimatedDuration: isLive ? 0 : estimateDuration(for: title),
            isRealExecution: isLive
        )
        tasks.append(newTask)

        // Update agent
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].assignedTaskIds.append(taskId)
            agents[idx].status = .working
            sceneManager.updateAgentStatus(agentId, to: .working)
        }

        if isLive {
            startCLIProcess(taskId: taskId, agentId: agentId, prompt: title)
        } else {
            // Start or add to simulation
            if isSimulationRunning {
                taskEngine.addTask(newTask)
            } else {
                startSimulation()
            }
        }
    }

    func cancelTask(_ taskId: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        if tasks[idx].isRealExecution {
            cliProcessManager.cancelProcess(taskId: taskId)
        }
        tasks[idx].status = .failed
        if let agentId = tasks[idx].assignedAgentId {
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
            }
        )
    }

    private func handleCLICompleted(_ taskId: UUID, result: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].status = .completed
        tasks[idx].progress = 1.0
        tasks[idx].completedAt = Date()
        tasks[idx].cliResult = result

        if let agentId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(agentId, to: .completed)
        }
    }

    private func handleCLIFailed(_ taskId: UUID, error: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].status = .failed
        tasks[idx].cliResult = "Error: \(error)"

        if let agentId = tasks[idx].assignedAgentId {
            handleAgentStatusChange(agentId, to: .error)
        }
    }

    func bestAvailableAgent() -> Agent? {
        // Prefer idle agents
        if let idle = agents.first(where: { $0.status == .idle }) {
            return idle
        }
        // Then main agents
        if let main = agents.first(where: { $0.isMainAgent }) {
            return main
        }
        // Any agent
        return agents.first
    }

    private func generateSubtasks(for title: String) -> [SubTask] {
        let words = title.split(separator: " ")
        let count = min(max(words.count, 2), 5)
        return (1...count).map { i in
            SubTask(id: UUID(), title: "Step \(i)", isCompleted: false)
        }
    }

    private func estimateDuration(for title: String) -> TimeInterval {
        let base = 8.0
        let lengthFactor = Double(title.count) / 20.0
        return base + lengthFactor * 4.0
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

            // Mark all subtasks as completed
            for si in tasks[idx].subtasks.indices {
                tasks[idx].subtasks[si].isCompleted = true
            }

            // Check if the assigned agent has all tasks completed
            if let agentId = tasks[idx].assignedAgentId,
               let agentIdx = agents.firstIndex(where: { $0.id == agentId }) {
                let agentTasks = tasks.filter { agents[agentIdx].assignedTaskIds.contains($0.id) }
                if agentTasks.allSatisfy({ $0.status == .completed }) {
                    agents[agentIdx].status = .completed
                    sceneManager.updateAgentStatus(agentId, to: .completed)
                }
            }
        } else {
            // Update subtask completion based on progress
            let totalSubtasks = tasks[idx].subtasks.count
            let completedCount = Int(progress * Double(totalSubtasks))
            for si in tasks[idx].subtasks.indices {
                tasks[idx].subtasks[si].isCompleted = si < completedCount
            }
        }

        // Check if simulation is done
        if tasks.allSatisfy({ $0.status == .completed || $0.status == .failed }) {
            isSimulationRunning = false
            taskEngine.stop()
        }
    }

    private func loadFromSampleDirectory() {
        // Try to find configs relative to executable
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
