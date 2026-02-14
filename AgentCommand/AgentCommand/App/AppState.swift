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

    // RAG System state (H1)
    @Published var isRAGStatusVisible: Bool = false
    @Published var isRAGKnowledgeGraphVisible: Bool = false
    @Published var isRAGKnowledgeGraphInScene: Bool = false

    // Agent Memory System state (H2)
    @Published var isAgentMemoryVisible: Bool = false
    @Published var isAgentMemoryOverlayVisible: Bool = false

    // Auto-Decomposition state (H3)
    @Published var isTaskDecompositionStatusVisible: Bool = false
    @Published var isTaskDecompositionViewVisible: Bool = false

    // Prompt Optimization state (H4)
    @Published var isPromptOptimizationVisible: Bool = false
    @Published var isPromptOptimizationPanelVisible: Bool = false
    @Published var isPromptOptimizationInScene: Bool = false

    // CI/CD Integration state (I1)
    @Published var isCICDStatusVisible: Bool = false
    @Published var isCICDViewVisible: Bool = false
    @Published var isCICDInScene: Bool = false

    // Test Coverage state (I2)
    @Published var isTestCoverageStatusVisible: Bool = false
    @Published var isTestCoverageViewVisible: Bool = false
    @Published var isTestCoverageInScene: Bool = false

    // Code Quality state (I3)
    @Published var isCodeQualityStatusVisible: Bool = false
    @Published var isCodeQualityViewVisible: Bool = false
    @Published var isCodeQualityInScene: Bool = false

    // Multi-Project state (I4)
    @Published var isMultiProjectStatusVisible: Bool = false
    @Published var isMultiProjectViewVisible: Bool = false

    // Docker state (I5)
    @Published var isDockerStatusVisible: Bool = false
    @Published var isDockerViewVisible: Bool = false
    @Published var isDockerInScene: Bool = false

    // Code Knowledge Graph state (J1)
    @Published var isCodeKnowledgeGraphStatusVisible: Bool = false
    @Published var isCodeKnowledgeGraphViewVisible: Bool = false
    @Published var isCodeKnowledgeGraphInScene: Bool = false

    // Collaboration Visualization state (J2)
    @Published var isCollaborationVizStatusVisible: Bool = false
    @Published var isCollaborationVizViewVisible: Bool = false
    @Published var isCollaborationVizInScene: Bool = false

    // AR/VR state (J3)
    @Published var isARVRSettingsVisible: Bool = false

    // Data Flow Animation state (J4)
    @Published var isDataFlowStatusVisible: Bool = false
    @Published var isDataFlowViewVisible: Bool = false
    @Published var isDataFlowInScene: Bool = false

    // Workflow Automation state (L1)
    @Published var isWorkflowStatusVisible: Bool = false
    @Published var isWorkflowEditorVisible: Bool = false

    // Smart Scheduling state (L2)
    @Published var isSmartSchedulingStatusVisible: Bool = false
    @Published var isSmartSchedulingViewVisible: Bool = false

    // Anomaly Detection state (L3)
    @Published var isAnomalyDetectionStatusVisible: Bool = false
    @Published var isAnomalyDetectionViewVisible: Bool = false

    // MCP Integration state (L4)
    @Published var isMCPStatusVisible: Bool = false
    @Published var isMCPManagementVisible: Bool = false

    // Analytics Dashboard state (M1)
    @Published var isAnalyticsDashboardStatusVisible: Bool = false
    @Published var isAnalyticsDashboardViewVisible: Bool = false

    // Report Export state (M2)
    @Published var isReportExportStatusVisible: Bool = false
    @Published var isReportExportViewVisible: Bool = false

    // API Usage Analytics state (M3)
    @Published var isAPIUsageAnalyticsStatusVisible: Bool = false
    @Published var isAPIUsageAnalyticsViewVisible: Bool = false

    // Session History Analytics state (M4)
    @Published var isSessionHistoryAnalyticsStatusVisible: Bool = false
    @Published var isSessionHistoryAnalyticsViewVisible: Bool = false
    @Published var isSessionHistoryChartsVisible: Bool = false

    // Team Performance state (M5)
    @Published var isTeamPerformanceStatusVisible: Bool = false
    @Published var isTeamPerformanceViewVisible: Bool = false
    @Published var isTeamPerformanceChartsVisible: Bool = false

    // Semantic Understanding state (H5)
    @Published var isSemanticSearchEnabled: Bool = true
    @Published var semanticSearchConfig: RAGSemanticConfig = .default

    // Unified Knowledge Search state (H5+H1)
    @Published var isUnifiedSearchVisible: Bool = false
    @Published var unifiedSearchResponse: SemanticSearchResponse?
    @Published var isUnifiedSearchProcessing: Bool = false

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
    var ragManager = RAGSystemManager()
    let agentMemoryManager = AgentMemorySystemManager()
    let promptOptimizationManager = PromptOptimizationManager()
    let cicdManager = CICDManager()
    let testCoverageManager = TestCoverageManager()
    let codeQualityManager = CodeQualityManager()
    let multiProjectManager = MultiProjectManager()
    let dockerManager = DockerManager()
    let codeKnowledgeGraphManager = CodeKnowledgeGraphManager()
    let collaborationVizManager = CollaborationVizManager()
    let arvrManager = ARVRManager()
    let dataFlowAnimationManager = DataFlowAnimationManager()
    let workflowManager = WorkflowManager()
    let smartSchedulingManager = SmartSchedulingManager()
    let anomalyDetectionManager = AnomalyDetectionManager()
    let mcpIntegrationManager = MCPIntegrationManager()
    let analyticsDashboardManager = AnalyticsDashboardManager()
    let reportExportManager = ReportExportManager()
    let apiUsageAnalyticsManager = APIUsageAnalyticsManager()
    let sessionHistoryAnalyticsManager = SessionHistoryAnalyticsManager()
    let teamPerformanceManager = TeamPerformanceManager()
    let semanticOrchestrator = SemanticSearchOrchestrator()
    let orchestrator = AutoDecompositionOrchestrator()
    @Published var autoDecompositionEnabled: Bool = true
    private let dayNightController = DayNightCycleController()
    /// Timer for personality idle behaviors (E1)
    private var idleBehaviorTimer: DispatchWorkItem?

    // SubAgent Resume & Persistence
    let persistenceManager = AgentPersistenceManager()
    let taskQueueManager = SubAgentTaskQueueManager()
    @Published var pendingResumes: [ResumeContext] = []
    @Published var showResumePanel: Bool = false
    private let retryPolicy: RetryPolicy = .default

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
    /// Forward ragManager changes so views observing AppState re-render
    private var ragManagerCancellable: AnyCancellable?
    /// Forward agentMemoryManager changes (H2)
    private var agentMemoryCancellable: AnyCancellable?
    /// Forward promptOptimizationManager changes (H4)
    private var promptOptimizationCancellable: AnyCancellable?
    /// Auto-refresh 3D scene when prompt analysis data changes
    private var promptOptimizationSceneCancellable: AnyCancellable?
    /// Forward cicdManager changes (I1)
    private var cicdCancellable: AnyCancellable?
    /// Forward testCoverageManager changes (I2)
    private var testCoverageCancellable: AnyCancellable?
    /// Forward codeQualityManager changes (I3)
    private var codeQualityCancellable: AnyCancellable?
    /// Forward multiProjectManager changes (I4)
    private var multiProjectCancellable: AnyCancellable?
    /// Forward dockerManager changes (I5)
    private var dockerCancellable: AnyCancellable?
    /// Forward codeKnowledgeGraphManager changes (J1)
    private var codeKnowledgeGraphCancellable: AnyCancellable?
    /// Forward collaborationVizManager changes (J2)
    private var collaborationVizCancellable: AnyCancellable?
    /// Forward arvrManager changes (J3)
    private var arvrCancellable: AnyCancellable?
    /// Forward dataFlowAnimationManager changes (J4)
    private var dataFlowAnimationCancellable: AnyCancellable?
    /// Forward workflowManager changes (L1)
    private var workflowCancellable: AnyCancellable?
    /// Forward smartSchedulingManager changes (L2)
    private var smartSchedulingCancellable: AnyCancellable?
    /// Forward anomalyDetectionManager changes (L3)
    private var anomalyDetectionCancellable: AnyCancellable?
    /// Forward mcpIntegrationManager changes (L4)
    private var mcpIntegrationCancellable: AnyCancellable?
    /// Forward analyticsDashboardManager changes (M1)
    private var analyticsDashboardCancellable: AnyCancellable?
    /// Forward reportExportManager changes (M2)
    private var reportExportCancellable: AnyCancellable?
    /// Forward apiUsageAnalyticsManager changes (M3)
    private var apiUsageAnalyticsCancellable: AnyCancellable?
    /// Forward sessionHistoryAnalyticsManager changes (M4)
    private var sessionHistoryAnalyticsCancellable: AnyCancellable?
    /// Forward teamPerformanceManager changes (M5)
    private var teamPerformanceCancellable: AnyCancellable?
    /// Forward orchestrator changes
    private var orchestratorCancellable: AnyCancellable?
    /// Forward semanticOrchestrator changes (H5)
    private var semanticOrchestratorCancellable: AnyCancellable?

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
    private static let ragStatusKey = "ragStatusVisible"
    private static let memoryOverlayKey = "memoryOverlayVisible"
    private static let promptOptimizationKey = "promptOptimizationVisible"
    private static let cicdStatusKey = "cicdStatusVisible"
    private static let testCoverageStatusKey = "testCoverageStatusVisible"
    private static let codeQualityStatusKey = "codeQualityStatusVisible"
    private static let multiProjectStatusKey = "multiProjectStatusVisible"
    private static let dockerStatusKey = "dockerStatusVisible"
    private static let codeKnowledgeGraphStatusKey = "codeKnowledgeGraphStatusVisible"
    private static let collaborationVizStatusKey = "collaborationVizStatusVisible"
    private static let dataFlowStatusKey = "dataFlowStatusVisible"
    private static let workflowStatusKey = "workflowStatusVisible"
    private static let smartSchedulingStatusKey = "smartSchedulingStatusVisible"
    private static let anomalyDetectionStatusKey = "anomalyDetectionStatusVisible"
    private static let mcpStatusKey = "mcpStatusVisible"
    private static let analyticsDashboardStatusKey = "analyticsDashboardStatusVisible"
    private static let reportExportStatusKey = "reportExportStatusVisible"
    private static let apiUsageAnalyticsStatusKey = "apiUsageAnalyticsStatusVisible"
    private static let sessionHistoryAnalyticsStatusKey = "sessionHistoryAnalyticsStatusVisible"
    private static let sessionHistoryChartsKey = "sessionHistoryChartsVisible"
    private static let teamPerformanceStatusKey = "teamPerformanceStatusVisible"
    private static let teamPerformanceChartsKey = "teamPerformanceChartsVisible"
    private static let autoDecompositionKey = "autoDecompositionEnabled"

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
        isRAGStatusVisible = UserDefaults.standard.bool(forKey: Self.ragStatusKey)
        isAgentMemoryOverlayVisible = UserDefaults.standard.bool(forKey: Self.memoryOverlayKey)
        isPromptOptimizationVisible = UserDefaults.standard.bool(forKey: Self.promptOptimizationKey)
        isCICDStatusVisible = UserDefaults.standard.bool(forKey: Self.cicdStatusKey)
        isTestCoverageStatusVisible = UserDefaults.standard.bool(forKey: Self.testCoverageStatusKey)
        isCodeQualityStatusVisible = UserDefaults.standard.bool(forKey: Self.codeQualityStatusKey)
        isMultiProjectStatusVisible = UserDefaults.standard.bool(forKey: Self.multiProjectStatusKey)
        isDockerStatusVisible = UserDefaults.standard.bool(forKey: Self.dockerStatusKey)
        isCodeKnowledgeGraphStatusVisible = UserDefaults.standard.bool(forKey: Self.codeKnowledgeGraphStatusKey)
        isCollaborationVizStatusVisible = UserDefaults.standard.bool(forKey: Self.collaborationVizStatusKey)
        isDataFlowStatusVisible = UserDefaults.standard.bool(forKey: Self.dataFlowStatusKey)
        if isDataFlowStatusVisible {
            dataFlowAnimationManager.startAnimating()
        }
        isWorkflowStatusVisible = UserDefaults.standard.bool(forKey: Self.workflowStatusKey)
        isSmartSchedulingStatusVisible = UserDefaults.standard.bool(forKey: Self.smartSchedulingStatusKey)
        isAnomalyDetectionStatusVisible = UserDefaults.standard.bool(forKey: Self.anomalyDetectionStatusKey)
        isMCPStatusVisible = UserDefaults.standard.bool(forKey: Self.mcpStatusKey)
        isAnalyticsDashboardStatusVisible = UserDefaults.standard.bool(forKey: Self.analyticsDashboardStatusKey)
        isReportExportStatusVisible = UserDefaults.standard.bool(forKey: Self.reportExportStatusKey)
        isAPIUsageAnalyticsStatusVisible = UserDefaults.standard.bool(forKey: Self.apiUsageAnalyticsStatusKey)
        isSessionHistoryAnalyticsStatusVisible = UserDefaults.standard.bool(forKey: Self.sessionHistoryAnalyticsStatusKey)
        isSessionHistoryChartsVisible = UserDefaults.standard.bool(forKey: Self.sessionHistoryChartsKey)
        isTeamPerformanceStatusVisible = UserDefaults.standard.bool(forKey: Self.teamPerformanceStatusKey)
        isTeamPerformanceChartsVisible = UserDefaults.standard.bool(forKey: Self.teamPerformanceChartsKey)

        // Initialize M4/M5 managers
        sessionHistoryAnalyticsManager.appState = self
        teamPerformanceManager.appState = self

        // Initialize RAG system (H1)
        ragManager.initialize()

        // Initialize Agent Memory system (H2)
        agentMemoryManager.initialize()

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

        // Forward ragManager's @Published changes (H1)
        ragManagerCancellable = ragManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward agentMemoryManager's @Published changes (H2)
        agentMemoryCancellable = agentMemoryManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward promptOptimizationManager's @Published changes (H4)
        promptOptimizationCancellable = promptOptimizationManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Auto-refresh 3D prompt optimization graph when analysis data changes (H4)
        promptOptimizationSceneCancellable = promptOptimizationManager.$lastScore
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPromptOptimizationScene()
            }

        // Forward cicdManager's @Published changes (I1)
        cicdCancellable = cicdManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward testCoverageManager's @Published changes (I2)
        testCoverageCancellable = testCoverageManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward codeQualityManager's @Published changes (I3)
        codeQualityCancellable = codeQualityManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward multiProjectManager's @Published changes (I4)
        multiProjectCancellable = multiProjectManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward dockerManager's @Published changes (I5)
        dockerCancellable = dockerManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward codeKnowledgeGraphManager's @Published changes (J1)
        codeKnowledgeGraphCancellable = codeKnowledgeGraphManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward collaborationVizManager's @Published changes (J2)
        collaborationVizCancellable = collaborationVizManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward arvrManager's @Published changes (J3)
        arvrCancellable = arvrManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward dataFlowAnimationManager's @Published changes (J4)
        dataFlowAnimationCancellable = dataFlowAnimationManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward workflowManager's @Published changes (L1)
        workflowCancellable = workflowManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward smartSchedulingManager's @Published changes (L2)
        smartSchedulingCancellable = smartSchedulingManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward anomalyDetectionManager's @Published changes (L3)
        anomalyDetectionCancellable = anomalyDetectionManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward mcpIntegrationManager's @Published changes (L4)
        mcpIntegrationCancellable = mcpIntegrationManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward analyticsDashboardManager's @Published changes (M1)
        analyticsDashboardCancellable = analyticsDashboardManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward reportExportManager's @Published changes (M2)
        reportExportCancellable = reportExportManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward apiUsageAnalyticsManager's @Published changes (M3)
        apiUsageAnalyticsCancellable = apiUsageAnalyticsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Connect managers that need live AppState access
        collaborationVizManager.appState = self
        anomalyDetectionManager.appState = self
        multiProjectManager.appState = self
        workflowManager.appState = self
        analyticsDashboardManager.appState = self
        reportExportManager.appState = self
        apiUsageAnalyticsManager.appState = self

        // Initialize MCP servers from Claude config (L4)
        mcpIntegrationManager.loadFromClaudeConfig()

        // Load saved scheduling stats (L2)
        smartSchedulingManager.loadSavedStats()

        // Initialize Semantic Search Orchestrator (H5)
        semanticOrchestrator.ragManager = ragManager
        semanticOrchestrator.memoryManager = agentMemoryManager
        semanticOrchestratorCancellable = semanticOrchestrator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Initialize orchestrator
        orchestrator.appState = self
        orchestrator.configureManagers(lifecycleManager: nil)
        orchestratorCancellable = orchestrator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Load auto-decomposition preference (default: true)
        if UserDefaults.standard.object(forKey: Self.autoDecompositionKey) == nil {
            autoDecompositionEnabled = true
        } else {
            autoDecompositionEnabled = UserDefaults.standard.bool(forKey: Self.autoDecompositionKey)
        }

        // Initialize task queue manager
        taskQueueManager.persistenceManager = persistenceManager
        taskQueueManager.loadPersistedQueues()
        orchestrator.taskQueueManager = taskQueueManager

        // Load pending resume contexts from previous session
        pendingResumes = persistenceManager.allPendingResumes()
        if !pendingResumes.isEmpty {
            showResumePanel = true
            print("[AppState] Found \(pendingResumes.count) pending resume(s) from previous session")
        }

        // Start periodic auto-save of state snapshot
        persistenceManager.startAutoSave { [weak self] in
            self?.buildStateSnapshot()
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

    /// Smart entry point: when auto-decomposition is enabled, ALL prompts go through
    /// the orchestrator (Haiku CLI decides whether to split). If it produces <=1 subtask,
    /// it automatically falls back to direct execution.
    func submitPromptSmart(title: String) {
        // Auto-record prompt to history with quality analysis
        promptOptimizationManager.recordPrompt(title)

        if autoDecompositionEnabled {
            orchestrator.submitWithAutoDecomposition(prompt: title, model: selectedModelForNewTeam)
        } else {
            submitPromptWithNewTeam(title: title)
        }

        // Save preference
        UserDefaults.standard.set(autoDecompositionEnabled, forKey: Self.autoDecompositionKey)
    }

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

    func startCLIProcess(taskId: UUID, agentId: UUID, prompt: String, resumeSessionId: String? = nil) {
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

    func handleCLICompleted(_ taskId: UUID, result: String) {
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

        // H2: Record task completion as agent memory
        if let leadId = tasks[idx].assignedAgentId,
           let agent = agents.first(where: { $0.id == leadId }) {
            agentMemoryManager.recordTaskCompletion(
                agentName: agent.name,
                taskTitle: tasks[idx].title,
                result: String(result.prefix(500))
            )
            // Share knowledge across team
            let teamNames = tasks[idx].teamAgentIds.compactMap { id in agents.first { $0.id == id }?.name }
            agentMemoryManager.shareTeamKnowledge(teamAgentNames: teamNames)
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

    func handleCLIFailed(_ taskId: UUID, error: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        // Check if we should auto-retry before marking as failed
        let currentRetryCount = tasks[idx].retryCount
        if currentRetryCount < retryPolicy.maxRetries && !RetryPolicy.isUserCancellation(error) {
            tasks[idx].retryCount = currentRetryCount + 1
            tasks[idx].lastError = error
            let delay = retryPolicy.delay(forAttempt: currentRetryCount)
            print("[AppState] Auto-retrying task \(taskId) (attempt \(tasks[idx].retryCount)/\(retryPolicy.maxRetries)) after \(delay)s")

            timelineManager.recordEvent(
                kind: .taskFailed,
                taskId: taskId,
                agentId: tasks[idx].assignedAgentId,
                title: "Retrying: \(tasks[idx].title) (attempt \(tasks[idx].retryCount))",
                detail: String(error.prefix(100))
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.retryFailedTask(taskId)
            }
            return
        }

        tasks[idx].status = .failed
        tasks[idx].cliResult = "Error: \(error)"
        tasks[idx].lastError = error

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

        // H2: Record error pattern as agent memory
        if let leadId = tasks[idx].assignedAgentId,
           let agent = agents.first(where: { $0.id == leadId }) {
            agentMemoryManager.recordErrorPattern(
                agentName: agent.name,
                taskTitle: tasks[idx].title,
                error: error
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

    func handleDangerousCommand(taskId: UUID, agentId: UUID, tool: String, input: String, reason: String) {
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

    func handleAskUserQuestion(taskId: UUID, agentId: UUID, sessionId: String, inputJSON: String) {
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

    func handlePlanReview(taskId: UUID, agentId: UUID, sessionId: String, inputJSON: String) {
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

    // MARK: - SubAgent Resume & Persistence

    /// Shutdown: save all active agent contexts and final snapshot before app terminates
    func shutdown() {
        // Suspend all in-progress task queue items
        taskQueueManager.suspendAllQueues()

        // Save resume contexts for all active agents
        for agent in agents where agent.status == .working || agent.status == .thinking {
            saveResumeContextForAgent(agent.id, reason: .appTerminated)
        }

        // Save final state snapshot
        if let snapshot = buildStateSnapshot() {
            persistenceManager.saveSnapshot(snapshot)
        }

        persistenceManager.stopAutoSave()
        print("[AppState] Shutdown complete — saved \(pendingResumes.count) resume context(s)")
    }

    /// Resume a previously suspended agent from its saved context
    func resumeSuspendedAgent(_ context: ResumeContext) {
        // Recreate agent if not already in agents array
        if !agents.contains(where: { $0.id == context.agentId }) {
            let restoredAgent = Agent(
                id: context.agentId,
                name: context.agentName,
                role: context.agentRole,
                status: .idle,
                selectedModel: context.agentModel,
                personality: context.agentPersonality,
                appearance: context.agentAppearance,
                position: ScenePosition(x: 0, y: 0, z: 0, rotation: 0),
                parentAgentId: context.commanderId,
                subAgentIds: [],
                assignedTaskIds: [context.taskId]
            )
            agents.append(restoredAgent)
            rebuildScene()

            // Walk to desk before resuming
            sceneManager.walkAgentToDesk(restoredAgent.id) { [weak self] in
                Task { @MainActor in
                    self?.performResume(context)
                }
            }
        } else {
            performResume(context)
        }

        // Remove from pending list
        pendingResumes.removeAll { $0.agentId == context.agentId }
        persistenceManager.removeResumeContext(agentId: context.agentId)

        if pendingResumes.isEmpty {
            showResumePanel = false
        }
    }

    /// Discard a suspended agent without resuming
    func discardSuspendedAgent(_ context: ResumeContext) {
        persistenceManager.removeResumeContext(agentId: context.agentId)
        pendingResumes.removeAll { $0.agentId == context.agentId }

        // Remove agent from scene if it exists
        agents.removeAll { $0.id == context.agentId }
        tasks.removeAll { $0.id == context.taskId }
        rebuildScene()

        if pendingResumes.isEmpty {
            showResumePanel = false
        }
    }

    /// Retry a failed task with exponential backoff
    func retryFailedTask(_ taskId: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let task = tasks[idx]
        guard task.retryCount < retryPolicy.maxRetries else { return }
        guard let agentId = task.assignedAgentId else { return }

        tasks[idx].retryCount += 1
        tasks[idx].status = .inProgress
        tasks[idx].lastError = nil

        handleAgentStatusChange(agentId, to: .working)

        timelineManager.recordEvent(
            kind: .taskCreated,
            taskId: taskId,
            agentId: agentId,
            title: "Retrying task (attempt \(tasks[idx].retryCount)): \(task.title)"
        )

        // Use sessionId for resume if available, otherwise re-submit prompt
        startCLIProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: task.sessionId != nil ? "Continue from where you left off." : task.title,
            resumeSessionId: task.sessionId
        )
    }

    /// Build a state snapshot for persistence
    func buildStateSnapshot() -> AgentStateSnapshot? {
        guard !agents.isEmpty || !tasks.isEmpty else { return nil }
        return AgentStateSnapshot(
            savedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            agents: agents,
            tasks: tasks,
            resumeContexts: persistenceManager.allPendingResumes()
        )
    }

    // MARK: - Resume & Retry Private Helpers

    private func performResume(_ context: ResumeContext) {
        handleAgentStatusChange(context.agentId, to: .working)

        startCLIProcess(
            taskId: context.taskId,
            agentId: context.agentId,
            prompt: "Continue from where you left off.",
            resumeSessionId: context.sessionId
        )
    }

    private func saveResumeContextForAgent(_ agentId: UUID, reason: SuspensionReason) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }

        let cliProcess = cliProcessManager.processes.values.first(where: { $0.agentId == agentId })
        guard let sessionId = cliProcess?.sessionId ?? tasks.first(where: { $0.assignedAgentId == agentId })?.sessionId else {
            print("[AppState] Cannot save resume context: no sessionId for agent \(agent.name)")
            return
        }

        let taskId = agent.assignedTaskIds.last ?? UUID()
        let task = tasks.first(where: { $0.id == taskId })

        let context = ResumeContext(
            agentId: agentId,
            agentName: agent.name,
            agentRole: agent.role,
            agentModel: agent.selectedModel,
            agentPersonality: agent.personality,
            agentAppearance: agent.appearance,
            sessionId: sessionId,
            workingDirectory: workspaceManager.activeDirectory,
            taskId: taskId,
            taskTitle: task?.title ?? "",
            originalPrompt: cliProcess?.prompt ?? task?.title ?? "",
            suspendedAt: Date(),
            suspensionReason: reason,
            toolCallCount: cliProcess?.toolCallCount ?? 0,
            progressEstimate: task?.progress ?? 0,
            commanderId: agent.parentAgentId,
            teamAgentIds: agent.isMainAgent ? agent.subAgentIds : [],
            orchestrationId: orchestrator.activeOrchestrations[agent.parentAgentId ?? agent.id]?.id,
            orchestrationTaskIndex: nil,
            pendingInteraction: nil
        )

        persistenceManager.saveResumeContext(context)
        pendingResumes.append(context)
    }

    // MARK: - Team Disband

    /// Schedule a completed or failed team to disband after a delay.
    func scheduleDisbandIfNeeded(commanderId: UUID) {
        // Don't disband if orchestration is still active
        if let orchestrationState = orchestrator.activeOrchestrations[commanderId],
           !orchestrationState.isFinished {
            return
        }

        // Only schedule if the entire team is finished (completed or failed/error+idle)
        // Never schedule if any agent is waiting for user input or suspended
        let teamAgents = [commanderId] + subAgents(of: commanderId).map(\.id)
        let anyWaitingForUser = teamAgents.contains { agentId in
            guard let status = agents.first(where: { $0.id == agentId })?.status else { return false }
            return status.isWaitingForUser
        }
        guard !anyWaitingForUser else { return }

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

        // Verify no agent is waiting for user input or suspended
        let anyWaitingForUser = teamAgentIds.contains { agentId in
            guard let status = agents.first(where: { $0.id == agentId })?.status else { return false }
            return status.isWaitingForUser
        }
        guard !anyWaitingForUser else { return }

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

    func handleCLIOutput(agentId: UUID, entry: CLIOutputEntry) {
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

    func handleAgentStatusChange(_ agentId: UUID, to status: AgentStatus) {
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
        // Skip propagation during orchestration (sub-agents have their own CLI processes)
        if let agent = agents.first(where: { $0.id == agentId }), agent.isMainAgent {
            let isOrchestrating = orchestrator.activeOrchestrations[agentId] != nil
                && !(orchestrator.activeOrchestrations[agentId]?.isFinished ?? true)

            if !isOrchestrating {
                let subAgentStatus = subAgentStatusFor(commanderStatus: status)
                for sub in subAgents(of: agentId) {
                    if let subIdx = agents.firstIndex(where: { $0.id == sub.id }) {
                        agents[subIdx].status = subAgentStatus
                    }
                    sceneManager.updateAgentStatus(sub.id, to: subAgentStatus)
                }
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

        // If team resumes work or enters a waiting-for-user state, cancel any pending disband
        if status == .working || status == .thinking || status.isWaitingForUser {
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
            return .thinking  // Keep sub-agents visually alive while waiting for user
        case .waitingForAnswer:
            return .thinking  // Keep sub-agents visually alive while waiting for user
        case .reviewingPlan:
            return .thinking
        case .suspended:
            return .idle
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

    // MARK: - RAG System (H1)

    func toggleRAGStatus() {
        isRAGStatusVisible.toggle()
        UserDefaults.standard.set(isRAGStatusVisible, forKey: Self.ragStatusKey)
    }

    func startRAGIndexing() {
        let directoryURL = URL(fileURLWithPath: workspaceManager.activeDirectory)
        ragManager.indexDirectory(directoryURL)
        ragManager.startWatching(directory: directoryURL)
    }

    func toggleRAGVisualization() {
        isRAGKnowledgeGraphInScene.toggle()
        if isRAGKnowledgeGraphInScene {
            sceneManager.showRAGKnowledgeGraph(ragManager.documents, ragManager.relationships)
        } else {
            sceneManager.removeRAGKnowledgeGraph()
        }
    }

    // MARK: - Agent Memory System (H2)

    func toggleAgentMemoryOverlay() {
        isAgentMemoryOverlayVisible.toggle()
        UserDefaults.standard.set(isAgentMemoryOverlayVisible, forKey: Self.memoryOverlayKey)
    }

    // MARK: - Auto-Decomposition (H3)

    func toggleTaskDecompositionStatus() {
        isTaskDecompositionStatusVisible.toggle()
    }

    func showTaskDecompositionView() {
        isTaskDecompositionViewVisible = true
    }

    // MARK: - Prompt Optimization (H4)

    func togglePromptOptimization() {
        isPromptOptimizationVisible.toggle()
        UserDefaults.standard.set(isPromptOptimizationVisible, forKey: Self.promptOptimizationKey)
    }

    func togglePromptOptimizationVisualization() {
        isPromptOptimizationInScene.toggle()
        if isPromptOptimizationInScene {
            refreshPromptOptimizationScene()
        } else {
            sceneManager.removePromptOptimizationGraph()
        }
    }

    /// Refresh the 3D prompt optimization graph with latest data
    func refreshPromptOptimizationScene() {
        guard isPromptOptimizationInScene else { return }
        sceneManager.showPromptOptimizationGraph(
            score: promptOptimizationManager.lastScore,
            patterns: promptOptimizationManager.patterns,
            history: promptOptimizationManager.history,
            antiPatterns: promptOptimizationManager.detectedAntiPatterns
        )
    }

    // MARK: - Semantic Search (H5)

    /// Run the full semantic search pipeline on a user query
    func performSemanticSearch(query: String) -> SemanticSearchResponse {
        return semanticOrchestrator.search(query: query)
    }

    /// Async version with optional AI-enhanced classification fallback
    func performSemanticSearchAsync(query: String) async -> SemanticSearchResponse {
        return await semanticOrchestrator.searchAsync(query: query)
    }

    /// Toggle semantic search on/off
    func toggleSemanticSearch() {
        isSemanticSearchEnabled.toggle()
        semanticSearchConfig.enableSemanticSearch = isSemanticSearchEnabled
    }

    /// Update semantic search scoring weights preset
    func updateSemanticScoringPreset(_ preset: String) {
        semanticSearchConfig.scoringWeightsPreset = preset
        switch preset {
        case "codeSearch":
            semanticOrchestrator.scoringWeights = .codeSearch
        case "errorDiagnosis":
            semanticOrchestrator.scoringWeights = .errorDiagnosis
        default:
            semanticOrchestrator.scoringWeights = .default
        }
    }

    // MARK: - Unified Knowledge Search (H5+H1)

    func toggleUnifiedSearch() {
        isUnifiedSearchVisible.toggle()
    }

    /// Execute unified search combining RAG keyword + semantic pipeline
    func performUnifiedSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isUnifiedSearchProcessing = true
        let response = semanticOrchestrator.search(query: query)
        unifiedSearchResponse = response
        isUnifiedSearchProcessing = false
    }

    /// Async unified search with AI-enhanced fallback
    func performUnifiedSearchAsync(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await MainActor.run { isUnifiedSearchProcessing = true }
        let response = await semanticOrchestrator.searchAsync(query: query)
        await MainActor.run {
            unifiedSearchResponse = response
            isUnifiedSearchProcessing = false
        }
    }

    /// Clear unified search results
    func clearUnifiedSearch() {
        unifiedSearchResponse = nil
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

    // MARK: - CI/CD Integration (I1)

    func toggleCICDStatus() {
        isCICDStatusVisible.toggle()
        UserDefaults.standard.set(isCICDStatusVisible, forKey: Self.cicdStatusKey)
    }

    func startCICDMonitoring() {
        cicdManager.startMonitoring(directory: workspaceManager.activeDirectory)
    }

    func toggleCICDVisualization() {
        isCICDInScene.toggle()
        if isCICDInScene {
            sceneManager.showCICDVisualization(cicdManager.pipelines)
        } else {
            sceneManager.removeCICDVisualization()
        }
    }

    // MARK: - Test Coverage (I2)

    func toggleTestCoverageStatus() {
        isTestCoverageStatusVisible.toggle()
        UserDefaults.standard.set(isTestCoverageStatusVisible, forKey: Self.testCoverageStatusKey)
    }

    func initializeTestCoverage() {
        testCoverageManager.initialize(directory: workspaceManager.activeDirectory)
    }

    func toggleTestCoverageVisualization() {
        isTestCoverageInScene.toggle()
        if isTestCoverageInScene {
            if let report = testCoverageManager.currentReport {
                sceneManager.showTestCoverageVisualization(report)
            }
        } else {
            sceneManager.removeTestCoverageVisualization()
        }
    }

    // MARK: - Code Quality (I3)

    func toggleCodeQualityStatus() {
        isCodeQualityStatusVisible.toggle()
        UserDefaults.standard.set(isCodeQualityStatusVisible, forKey: Self.codeQualityStatusKey)
    }

    func analyzeCodeQuality() {
        codeQualityManager.initialize(directory: workspaceManager.activeDirectory)
        codeQualityManager.analyzeProject()
    }

    func toggleCodeQualityVisualization() {
        isCodeQualityInScene.toggle()
        if isCodeQualityInScene {
            sceneManager.showCodeQualityVisualization(codeQualityManager.complexities)
        } else {
            sceneManager.removeCodeQualityVisualization()
        }
    }

    // MARK: - Multi-Project Workspace (I4)

    func toggleMultiProjectStatus() {
        isMultiProjectStatusVisible.toggle()
        UserDefaults.standard.set(isMultiProjectStatusVisible, forKey: Self.multiProjectStatusKey)
    }

    // MARK: - Docker / Dev Environment (I5)

    func toggleDockerStatus() {
        isDockerStatusVisible.toggle()
        UserDefaults.standard.set(isDockerStatusVisible, forKey: Self.dockerStatusKey)
    }

    func startDockerMonitoring() {
        dockerManager.checkDockerAvailability()
        dockerManager.startMonitoring()
    }

    func toggleDockerVisualization() {
        isDockerInScene.toggle()
        if isDockerInScene {
            sceneManager.showDockerVisualization(dockerManager.containers)
        } else {
            sceneManager.removeDockerVisualization()
        }
    }

    // MARK: - Code Knowledge Graph (J1)

    func toggleCodeKnowledgeGraphStatus() {
        isCodeKnowledgeGraphStatusVisible.toggle()
        UserDefaults.standard.set(isCodeKnowledgeGraphStatusVisible, forKey: Self.codeKnowledgeGraphStatusKey)
    }

    func analyzeCodeKnowledgeGraph() {
        codeKnowledgeGraphManager.analyzeProject(directory: workspaceManager.activeDirectory)
    }

    func toggleCodeKnowledgeGraphVisualization() {
        isCodeKnowledgeGraphInScene.toggle()
        if isCodeKnowledgeGraphInScene {
            sceneManager.showCodeKnowledgeGraphVisualization(codeKnowledgeGraphManager.fileNodes, codeKnowledgeGraphManager.edges)
        } else {
            sceneManager.removeCodeKnowledgeGraphVisualization()
        }
    }

    // MARK: - Collaboration Visualization (J2)

    func toggleCollaborationVizStatus() {
        isCollaborationVizStatusVisible.toggle()
        UserDefaults.standard.set(isCollaborationVizStatusVisible, forKey: Self.collaborationVizStatusKey)
    }

    func toggleCollaborationVisualization() {
        isCollaborationVizInScene.toggle()
        if isCollaborationVizInScene {
            sceneManager.showCollaborationVisualization(
                collaborationVizManager.collaborationPaths,
                collaborationVizManager.taskHandoffs,
                collaborationVizManager.efficiencyMetrics
            )
        } else {
            sceneManager.removeCollaborationVisualization()
        }
    }

    // MARK: - Data Flow Animation (J4)

    func toggleDataFlowStatus() {
        isDataFlowStatusVisible.toggle()
        UserDefaults.standard.set(isDataFlowStatusVisible, forKey: Self.dataFlowStatusKey)
        // Start or stop animation based on whether any data flow UI is visible
        updateDataFlowAnimationState()
    }

    func toggleDataFlowVisualization() {
        isDataFlowInScene.toggle()
        if isDataFlowInScene {
            // Ensure animation is running so there is data to visualize
            if !dataFlowAnimationManager.isAnimating {
                dataFlowAnimationManager.startAnimating()
            }
            sceneManager.showDataFlowVisualization(
                dataFlowAnimationManager.tokenFlows,
                dataFlowAnimationManager.pipelineStages,
                dataFlowAnimationManager.toolCallChain
            )
        } else {
            sceneManager.removeDataFlowVisualization()
            updateDataFlowAnimationState()
        }
    }

    /// Start or stop the data flow animation timer depending on UI visibility.
    private func updateDataFlowAnimationState() {
        let needsAnimation = isDataFlowStatusVisible || isDataFlowInScene || isDataFlowViewVisible
        if needsAnimation && !dataFlowAnimationManager.isAnimating {
            dataFlowAnimationManager.startAnimating()
        } else if !needsAnimation && dataFlowAnimationManager.isAnimating {
            dataFlowAnimationManager.stopAnimating()
        }
    }

    // MARK: - Workflow Automation (L1)

    func toggleWorkflowStatus() {
        isWorkflowStatusVisible.toggle()
        UserDefaults.standard.set(isWorkflowStatusVisible, forKey: Self.workflowStatusKey)
    }

    // MARK: - Smart Scheduling (L2)

    func toggleSmartSchedulingStatus() {
        isSmartSchedulingStatusVisible.toggle()
        UserDefaults.standard.set(isSmartSchedulingStatusVisible, forKey: Self.smartSchedulingStatusKey)
    }

    // MARK: - Anomaly Detection (L3)

    func toggleAnomalyDetectionStatus() {
        isAnomalyDetectionStatusVisible.toggle()
        UserDefaults.standard.set(isAnomalyDetectionStatusVisible, forKey: Self.anomalyDetectionStatusKey)
    }

    // MARK: - MCP Integration (L4)

    func toggleMCPStatus() {
        isMCPStatusVisible.toggle()
        UserDefaults.standard.set(isMCPStatusVisible, forKey: Self.mcpStatusKey)
    }

    // MARK: - Analytics Dashboard (M1)

    func toggleAnalyticsDashboardStatus() {
        isAnalyticsDashboardStatusVisible.toggle()
        UserDefaults.standard.set(isAnalyticsDashboardStatusVisible, forKey: Self.analyticsDashboardStatusKey)
    }

    // MARK: - Report Export (M2)

    func toggleReportExportStatus() {
        isReportExportStatusVisible.toggle()
        UserDefaults.standard.set(isReportExportStatusVisible, forKey: Self.reportExportStatusKey)
    }

    // MARK: - API Usage Analytics (M3)

    func toggleAPIUsageAnalyticsStatus() {
        isAPIUsageAnalyticsStatusVisible.toggle()
        UserDefaults.standard.set(isAPIUsageAnalyticsStatusVisible, forKey: Self.apiUsageAnalyticsStatusKey)
    }

    // MARK: - Session History Analytics (M4)

    func toggleSessionHistoryAnalyticsStatus() {
        isSessionHistoryAnalyticsStatusVisible.toggle()
        UserDefaults.standard.set(isSessionHistoryAnalyticsStatusVisible, forKey: Self.sessionHistoryAnalyticsStatusKey)
    }

    func toggleSessionHistoryCharts() {
        isSessionHistoryChartsVisible.toggle()
        UserDefaults.standard.set(isSessionHistoryChartsVisible, forKey: Self.sessionHistoryChartsKey)
    }

    // MARK: - Team Performance (M5)

    func toggleTeamPerformanceStatus() {
        isTeamPerformanceStatusVisible.toggle()
        UserDefaults.standard.set(isTeamPerformanceStatusVisible, forKey: Self.teamPerformanceStatusKey)
    }

    func toggleTeamPerformanceCharts() {
        isTeamPerformanceChartsVisible.toggle()
        UserDefaults.standard.set(isTeamPerformanceChartsVisible, forKey: Self.teamPerformanceChartsKey)
    }

    // MARK: - Memory Management

    /// Coordinated cleanup of stale data across all managers.
    /// Call periodically or when transitioning between sessions to free memory.
    func performMemoryCleanup() {
        // Reset completed task metrics that are no longer displayed
        metricsManager.resetSession()

        // Clear resolved anomaly alerts
        anomalyDetectionManager.resolveAllAlerts()
        anomalyDetectionManager.alerts.removeAll { $0.isResolved }

        // Clear stale collaboration paths (inactive for > 60s)
        let cutoff = Date().addingTimeInterval(-60)
        collaborationVizManager.collaborationPaths.removeAll { !$0.isActive && $0.timestamp < cutoff }

        // Trim task handoff history
        if collaborationVizManager.taskHandoffs.count > 50 {
            collaborationVizManager.taskHandoffs = Array(collaborationVizManager.taskHandoffs.suffix(50))
        }

        // Clear completed scheduled tasks
        smartSchedulingManager.scheduledTasks.removeAll { $0.status == .completed }

        // Stop monitoring timers for features that are not visible
        if !isCollaborationVizStatusVisible { collaborationVizManager.stopMonitoring() }
        if !isAnomalyDetectionStatusVisible { anomalyDetectionManager.stopMonitoring() }
        if !isDataFlowStatusVisible { dataFlowAnimationManager.stopAnimating() }
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
