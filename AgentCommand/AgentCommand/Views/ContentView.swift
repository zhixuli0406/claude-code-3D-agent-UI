import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.openWindow) private var openWindow
    @State private var showAchievementGallery = false
    @State private var showStatsDashboard = false
    @State private var showCosmeticShop = false
    @State private var showSkillBook = false
    @State private var showSessionHistory = false
    @State private var showGitIntegration = false
    @State private var showCICDView = false
    @State private var showTestCoverageView = false
    @State private var showCodeQualityView = false
    @State private var showMultiProjectView = false
    @State private var showDockerView = false
    @State private var showCodeKnowledgeGraphView = false
    @State private var showCollaborationVizView = false
    @State private var showDataFlowView = false
    @State private var showWorkflowEditorView = false
    @State private var showSmartSchedulingView = false
    @State private var showAnomalyDetectionView = false
    @State private var showMCPManagementView = false

    var body: some View {
        Group {
            if appState.showSceneSelection {
                SceneSelectionView()
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        mainContentBase
            .modifier(SheetGroupA(
                appState: appState,
                localization: localization,
                showAchievementGallery: $showAchievementGallery,
                showStatsDashboard: $showStatsDashboard,
                showCosmeticShop: $showCosmeticShop,
                showSkillBook: $showSkillBook,
                showSessionHistory: $showSessionHistory,
                showGitIntegration: $showGitIntegration
            ))
            .modifier(SheetGroupB(
                appState: appState,
                localization: localization,
                showCICDView: $showCICDView,
                showTestCoverageView: $showTestCoverageView,
                showCodeQualityView: $showCodeQualityView,
                showMultiProjectView: $showMultiProjectView,
                showDockerView: $showDockerView
            ))
            .modifier(SheetGroupC(
                appState: appState,
                localization: localization,
                showCodeKnowledgeGraphView: $showCodeKnowledgeGraphView,
                showCollaborationVizView: $showCollaborationVizView,
                showDataFlowView: $showDataFlowView
            ))
            .modifier(SheetGroupD(
                appState: appState,
                localization: localization,
                showWorkflowEditorView: $showWorkflowEditorView,
                showSmartSchedulingView: $showSmartSchedulingView,
                showAnomalyDetectionView: $showAnomalyDetectionView,
                showMCPManagementView: $showMCPManagementView
            ))
            .modifier(SheetGroupE(
                appState: appState,
                localization: localization
            ))
            .overlay(alignment: .bottom) {
                if let reward = appState.coinManager.lastCoinReward {
                    CoinRewardToast(reward: reward)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                appState.coinManager.lastCoinReward = nil
                            }
                        }
                }
            }
            .overlay(alignment: .center) {
                if appState.showResumePanel && !appState.pendingResumes.isEmpty {
                    ResumePanelView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(100)
                }
            }
    }

    private var mainContentBase: some View {
        HSplitView {
            SceneContainerView()
                .frame(minWidth: 600, idealWidth: 900)
            SidePanelView()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Group {
                    toolbarSettingsMenu
                    toolbarAIMenu
                    toolbarDevOpsMenu
                    toolbarVisualizationMenu
                }
                Group {
                    toolbarDataAnalyticsMenu
                    toolbarAutomationMenu
                    toolbarStoreMenu
                    toolbarWindowMenu
                    toolbarAudioMenu
                }
                Group {
                    Button(action: { appState.toggleHelpOverlay() }) {
                        Label(localization.localized(.help), systemImage: "questionmark.circle")
                    }
                    .help(localization.localized(.helpShowHelp))

                    WorkspacePicker()
                }
            }
        }
        .background(Color(nsColor: appState.sceneManager.sceneBackgroundColor))
        .onAppear {
            if appState.agents.isEmpty {
                appState.rebuildScene()
            }
        }
        .onKeyPress(phases: .down) { press in
            if press.key == KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!)) {
                appState.toggleHelpOverlay()
                return .handled
            }
            return .ignored
        }
        .alert(
            localization.localized(.dangerousCommandDetected),
            isPresented: Binding(
                get: { appState.dangerousCommandAlert != nil },
                set: { if !$0 { appState.dismissDangerousAlert() } }
            )
        ) {
            Button(localization.localized(.continueExecution)) {
                appState.dismissDangerousAlert()
            }
            Button(localization.localized(.cancelTask), role: .destructive) {
                appState.cancelDangerousTask()
            }
        } message: {
            if let alert = appState.dangerousCommandAlert {
                Text(alert.reason)
            }
        }
    }

    // MARK: - Toolbar Menus

    // 1. Settings
    private var toolbarSettingsMenu: some View {
        Menu {
            Button(action: { appState.showThemeSelection() }) {
                Label(localization.localized(.theme), systemImage: "paintpalette")
            }
            Menu {
                ForEach(AppLanguage.allCases) { lang in
                    Button(action: { localization.setLanguage(lang) }) {
                        HStack {
                            Text(lang.displayName)
                            if localization.currentLanguage == lang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(localization.localized(.language), systemImage: "globe")
            }
            Menu {
                Button("Overview") { appState.sceneManager.setCameraPreset(.overview) }
                Button("Close-Up") { appState.sceneManager.setCameraPreset(.closeUp) }
                Button("Cinematic") { appState.sceneManager.setCameraPreset(.cinematic) }
            } label: {
                Label("Camera", systemImage: "camera.viewfinder")
            }
        } label: {
            Label(localization.localized(.theme), systemImage: "gearshape")
        }
        .help(localization.localized(.helpChangeTheme))
    }

    // 2. AI Intelligence
    private var toolbarAIMenu: some View {
        Menu {
            // Unified Knowledge Search
            Button(action: { appState.isUnifiedSearchVisible = true }) {
                Label(localization.localized(.unifiedSearch), systemImage: "brain.head.profile")
            }
            Divider()
            // RAG
            Button(action: { appState.isRAGKnowledgeGraphVisible = true }) {
                Label(localization.localized(.ragKnowledgeBase), systemImage: "text.book.closed.fill")
            }
            Button(action: { appState.toggleRAGStatus() }) {
                Label(localization.localized(.ragKnowledgeGraph), systemImage: "point.3.connected.trianglepath.dotted")
            }
            Divider()
            // Agent Memory
            Button(action: { appState.isAgentMemoryVisible = true }) {
                Label(localization.localized(.agentMemory), systemImage: "brain.head.profile")
            }
            Button(action: { appState.toggleAgentMemoryOverlay() }) {
                Label(localization.localized(.memoryTimeline), systemImage: appState.isAgentMemoryOverlayVisible ? "brain.fill" : "brain")
            }
            Divider()
            // Auto Decomposition
            Button(action: { appState.isTaskDecompositionViewVisible = true }) {
                Label(localization.localized(.taskDecomposition), systemImage: "bolt.horizontal.fill")
            }
            Button(action: { appState.toggleTaskDecompositionStatus() }) {
                Label(localization.localized(.helpTaskDecompositionStatus), systemImage: appState.isTaskDecompositionStatusVisible ? "bolt.horizontal.fill" : "bolt.horizontal")
            }
            Button(action: { appState.autoDecompositionEnabled.toggle() }) {
                Label(
                    localization.localized(.autoDecompositionToggle),
                    systemImage: appState.autoDecompositionEnabled ? "bolt.fill" : "bolt.slash"
                )
            }
            Divider()
            // Prompt Optimization
            Button(action: { appState.isPromptOptimizationPanelVisible = true }) {
                Label(localization.localized(.promptOptimization), systemImage: "wand.and.stars")
            }
            Button(action: { appState.togglePromptOptimization() }) {
                Label(localization.localized(.promptQuality), systemImage: appState.isPromptOptimizationVisible ? "gauge.with.needle.fill" : "gauge.with.needle")
            }
            Divider()
            // Templates & Comparison
            Button(action: { appState.isTemplateGalleryVisible = true }) {
                Label(localization.localized(.promptTemplates), systemImage: "doc.text.fill")
            }
            Button(action: { appState.isModelComparisonVisible = true }) {
                Label(localization.localized(.modelComparison), systemImage: "arrow.left.arrow.right")
            }
        } label: {
            Label("AI", systemImage: "sparkles")
        }
        .help("AI Intelligence")
    }

    // 3. DevOps
    private var toolbarDevOpsMenu: some View {
        Menu {
            // CI/CD
            Button(action: { showCICDView = true }) {
                Label(localization.localized(.cicdPipeline), systemImage: "arrow.triangle.branch")
            }
            Button(action: { appState.toggleCICDStatus() }) {
                Label(localization.localized(.cicdSuccessRate), systemImage: appState.isCICDStatusVisible ? "burst.fill" : "burst")
            }
            Divider()
            // Test Coverage
            Button(action: { showTestCoverageView = true }) {
                Label(localization.localized(.testCoverage), systemImage: "checkmark.shield.fill")
            }
            Button(action: { appState.toggleTestCoverageStatus() }) {
                Label(localization.localized(.testOverallCoverage), systemImage: "testtube.2")
            }
            Divider()
            // Code Quality
            Button(action: { showCodeQualityView = true }) {
                Label(localization.localized(.codeQuality), systemImage: "wand.and.stars.inverse")
            }
            Button(action: { appState.toggleCodeQualityStatus() }) {
                Label(localization.localized(.cqComplexity), systemImage: appState.isCodeQualityStatusVisible ? "gauge.with.dots.needle.bottom.50percent.badge.plus" : "gauge.with.dots.needle.bottom.50percent")
            }
            Divider()
            // Docker
            Button(action: { showDockerView = true }) {
                Label(localization.localized(.dockerContainers), systemImage: "shippingbox.fill")
            }
            Button(action: { appState.toggleDockerStatus() }) {
                Label(localization.localized(.dockerRunning), systemImage: appState.isDockerStatusVisible ? "cube.fill" : "cube")
            }
            Divider()
            // Git
            Button(action: { showGitIntegration = true }) {
                Label(localization.localized(.gitIntegration), systemImage: "arrow.triangle.branch")
            }
        } label: {
            Label("DevOps", systemImage: "hammer")
        }
        .help("DevOps")
    }

    // 4. Visualization
    private var toolbarVisualizationMenu: some View {
        Menu {
            // Code Knowledge Graph
            Button(action: { showCodeKnowledgeGraphView = true }) {
                Label(localization.localized(.codeKnowledgeGraph), systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
            Button(action: { appState.toggleCodeKnowledgeGraphStatus() }) {
                Label(localization.localized(.ckgDependencies), systemImage: appState.isCodeKnowledgeGraphStatusVisible ? "circle.hexagongrid.fill" : "circle.hexagongrid")
            }
            Divider()
            // Collaboration
            Button(action: { showCollaborationVizView = true }) {
                Label(localization.localized(.collabVisualization), systemImage: "person.3.fill")
            }
            Button(action: { appState.toggleCollaborationVizStatus() }) {
                Label(localization.localized(.collabActivePaths), systemImage: "arrow.triangle.swap")
            }
            Divider()
            // Data Flow
            Button(action: { showDataFlowView = true }) {
                Label(localization.localized(.dataFlowAnimation), systemImage: "waveform.path")
            }
            Button(action: { appState.toggleDataFlowStatus() }) {
                Label(localization.localized(.dfActiveFlows), systemImage: "waveform.path.ecg")
            }
            Divider()
            // Anomaly Detection
            Button(action: { showAnomalyDetectionView = true }) {
                Label(localization.localized(.adAnomalyDetection), systemImage: "shield.checkered")
            }
            Button(action: { appState.toggleAnomalyDetectionStatus() }) {
                Label(localization.localized(.adActiveAlerts), systemImage: appState.isAnomalyDetectionStatusVisible ? "exclamationmark.shield.fill" : "exclamationmark.shield")
            }
        } label: {
            Label("Viz", systemImage: "eye")
        }
        .help("Visualization")
    }

    // 5. Data & Analytics (M-series)
    private var toolbarDataAnalyticsMenu: some View {
        Menu {
            // M1: Analytics Dashboard
            Button(action: { appState.isAnalyticsDashboardViewVisible = true }) {
                Label(localization.localized(.adAnalyticsDashboard), systemImage: "chart.bar.xaxis")
            }
            Button(action: { appState.toggleAnalyticsDashboardStatus() }) {
                Label(localization.localized(.adReports), systemImage: appState.isAnalyticsDashboardStatusVisible ? "chart.xyaxis.line" : "chart.line.flattrend.xyaxis")
            }
            Divider()
            // M2: Report Export
            Button(action: { appState.isReportExportViewVisible = true }) {
                Label(localization.localized(.reExportReports), systemImage: "doc.richtext")
            }
            Button(action: { appState.toggleReportExportStatus() }) {
                Label(localization.localized(.reSchedules), systemImage: appState.isReportExportStatusVisible ? "calendar.badge.clock" : "calendar")
            }
            Divider()
            // M3: API Usage Analytics
            Button(action: { appState.isAPIUsageAnalyticsViewVisible = true }) {
                Label(localization.localized(.auAPIUsageAnalytics), systemImage: "dollarsign.arrow.circlepath")
            }
            Button(action: { appState.toggleAPIUsageAnalyticsStatus() }) {
                Label(localization.localized(.auBudget), systemImage: appState.isAPIUsageAnalyticsStatusVisible ? "gauge.with.needle.fill" : "gauge.with.needle")
            }
            Divider()
            // M4: Session History Analytics
            Button(action: { appState.isSessionHistoryAnalyticsViewVisible = true }) {
                Label(localization.localized(.shSessionAnalytics), systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }
            Button(action: { appState.toggleSessionHistoryAnalyticsStatus() }) {
                Label(localization.localized(.shProductivity), systemImage: appState.isSessionHistoryAnalyticsStatusVisible ? "chart.line.uptrend.xyaxis" : "chart.line.flattrend.xyaxis")
            }
            Button(action: { appState.toggleSessionHistoryCharts() }) {
                Label("Session Charts", systemImage: appState.isSessionHistoryChartsVisible ? "chart.xyaxis.line" : "chart.dots.scatter")
            }
            Divider()
            // M5: Team Performance Metrics
            Button(action: { appState.isTeamPerformanceViewVisible = true }) {
                Label(localization.localized(.tpTeamPerformance), systemImage: "person.3.sequence.fill")
            }
            Button(action: { appState.toggleTeamPerformanceStatus() }) {
                Label(localization.localized(.tpEfficiency), systemImage: appState.isTeamPerformanceStatusVisible ? "speedometer" : "gauge.with.dots.needle.33percent")
            }
            Button(action: { appState.toggleTeamPerformanceCharts() }) {
                Label("Team Charts", systemImage: appState.isTeamPerformanceChartsVisible ? "chart.bar.xaxis" : "chart.bar")
            }
        } label: {
            Label("Data", systemImage: "chart.bar")
        }
        .help("Data & Analytics")
    }

    // 6. Automation
    private var toolbarAutomationMenu: some View {
        Menu {
            // Workflow
            Button(action: { showWorkflowEditorView = true }) {
                Label(localization.localized(.wfWorkflowEngine), systemImage: "gearshape.2.fill")
            }
            Button(action: { appState.toggleWorkflowStatus() }) {
                Label(localization.localized(.wfActiveWorkflows), systemImage: appState.isWorkflowStatusVisible ? "gearshape.2" : "gearshape")
            }
            Divider()
            // Smart Scheduling
            Button(action: { showSmartSchedulingView = true }) {
                Label(localization.localized(.ssSmartScheduling), systemImage: "calendar.badge.clock")
            }
            Button(action: { appState.toggleSmartSchedulingStatus() }) {
                Label(localization.localized(.ssScheduledTasks), systemImage: appState.isSmartSchedulingStatusVisible ? "clock.badge.checkmark.fill" : "clock.badge.checkmark")
            }
            Divider()
            // MCP
            Button(action: { showMCPManagementView = true }) {
                Label(localization.localized(.mcpIntegration), systemImage: "network")
            }
            Button(action: { appState.toggleMCPStatus() }) {
                Label(localization.localized(.mcpServers), systemImage: "server.rack")
            }
            Divider()
            // Multi Project
            Button(action: { showMultiProjectView = true }) {
                Label(localization.localized(.multiProject), systemImage: "square.stack.3d.up.fill")
            }
            Button(action: { appState.toggleMultiProjectStatus() }) {
                Label(localization.localized(.mpActive), systemImage: appState.isMultiProjectStatusVisible ? "square.stack.3d.up.badge.automatic.fill" : "square.stack.3d.up")
            }
        } label: {
            Label("Auto", systemImage: "gearshape.2")
        }
        .help("Automation")
    }

    // 6. Store & Achievements
    private var toolbarStoreMenu: some View {
        Menu {
            Button(action: { showAchievementGallery = true }) {
                Label(localization.localized(.achievements), systemImage: "trophy.fill")
            }
            Button(action: { showStatsDashboard = true }) {
                Label(localization.localized(.statsDashboard), systemImage: "chart.bar.xaxis")
            }
            Button(action: { showCosmeticShop = true }) {
                Label(localization.localized(.cosmeticShop), systemImage: "bag.fill")
            }
            Button(action: { showSkillBook = true }) {
                Label(localization.localized(.skillStore), systemImage: "puzzlepiece.extension.fill")
            }
            Divider()
            Button(action: { showSessionHistory = true }) {
                Label(localization.localized(.sessionHistory), systemImage: "clock.arrow.circlepath")
            }
        } label: {
            Label(localization.localized(.achievements), systemImage: "trophy")
        }
        .help(localization.localized(.helpAchievements))
    }

    // 7. Window & Display
    private var toolbarWindowMenu: some View {
        Menu {
            // Multi-window management
            Button(action: {
                openWindow(id: "cli-output")
                appState.windowManager.isCLIWindowOpen = true
                appState.windowManager.isCLIWindowDetached = true
            }) {
                Label(localization.localized(.popOutCLI), systemImage: "terminal")
            }
            Button(action: {
                openWindow(id: "agent-details")
                appState.windowManager.isAgentDetailWindowOpen = true
            }) {
                Label(localization.localized(.detachAgentPanel), systemImage: "person.crop.rectangle")
            }
            Button(action: {
                openWindow(id: "floating-monitor")
                appState.windowManager.isFloatingMonitorOpen = true
            }) {
                Label(localization.localized(.floatingMonitor), systemImage: "pip")
            }
            if NSScreen.screens.count > 1 {
                Menu(localization.localized(.multiMonitor)) {
                    ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                        Button("\(localization.localized(.moveToScreen)) \(index + 1)") {
                            if let window = NSApp.mainWindow {
                                appState.windowManager.moveWindowToScreen(window, screenIndex: index)
                            }
                        }
                    }
                }
            }
            Divider()
            // Display toggles
            Button(action: { appState.toggleMiniMap() }) {
                Label(localization.localized(.miniMap), systemImage: appState.isMiniMapVisible ? "map.fill" : "map")
            }
            Button(action: { appState.toggleTaskQueue() }) {
                Label(localization.localized(.taskQueue), systemImage: appState.isTaskQueueVisible ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
            }
            Button(action: { appState.toggleMetrics() }) {
                Label(localization.localized(.performanceMetrics), systemImage: appState.isMetricsVisible ? "gauge.with.dots.needle.67percent" : "gauge.with.dots.needle.33percent")
            }
            Divider()
            Button(action: { appState.isARVRSettingsVisible = true }) {
                Label(localization.localized(.arvrSettings), systemImage: "visionpro")
            }
        } label: {
            Label(localization.localized(.multiWindow), systemImage: "macwindow.on.rectangle")
        }
        .help(localization.localized(.helpMultiWindow))
    }

    // 8. Audio & Notifications
    private var toolbarAudioMenu: some View {
        Menu {
            Button(action: { appState.soundManager.isMuted.toggle() }) {
                Label(localization.localized(.sound), systemImage: appState.soundManager.isMuted ? "speaker.slash" : "speaker.wave.2")
            }
            Button(action: { appState.soundManager.isAmbientEnabled.toggle() }) {
                Label("Ambient", systemImage: appState.soundManager.isAmbientEnabled ? "music.note" : "music.note.slash")
            }
            Button(action: { appState.backgroundMusicManager.isMusicEnabled.toggle() }) {
                Label(localization.localized(.backgroundMusic), systemImage: appState.backgroundMusicManager.isMusicEnabled ? "music.quarternote.3" : "music.quarternote.3")
            }
            Divider()
            Button(action: {
                appState.notificationManager.requestPermission()
                appState.notificationManager.isEnabled.toggle()
            }) {
                Label("Notifications", systemImage: appState.notificationManager.isEnabled ? "bell.fill" : "bell.slash")
            }
        } label: {
            Label(localization.localized(.sound), systemImage: "speaker.wave.2")
        }
        .help(localization.localized(.helpToggleSound))
    }
}

// MARK: - Sheet Modifier Groups

private struct SheetGroupA: ViewModifier {
    @ObservedObject var appState: AppState
    var localization: LocalizationManager
    @Binding var showAchievementGallery: Bool
    @Binding var showStatsDashboard: Bool
    @Binding var showCosmeticShop: Bool
    @Binding var showSkillBook: Bool
    @Binding var showSessionHistory: Bool
    @Binding var showGitIntegration: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: $appState.askUserQuestionData) { questionData in
                AskUserQuestionSheet(
                    data: questionData,
                    onSubmit: { answers in appState.submitAskUserAnswer(answers) },
                    onCancel: { appState.cancelAskUserQuestion() }
                )
                .environmentObject(localization)
            }
            .sheet(item: $appState.planReviewData) { reviewData in
                PlanReviewSheet(
                    data: reviewData,
                    onApprove: { appState.approvePlan() },
                    onReject: { feedback in appState.rejectPlan(feedback: feedback) }
                )
                .environmentObject(localization)
            }
            .sheet(isPresented: $showAchievementGallery) {
                AchievementGalleryView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showStatsDashboard) {
                AgentStatsDashboardView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showCosmeticShop) {
                CosmeticShopView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showSkillBook) {
                SkillBookView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showSessionHistory) {
                SessionHistoryView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showGitIntegration) {
                GitIntegrationView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isTemplateGalleryVisible) {
                PromptTemplateGalleryView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isModelComparisonVisible) {
                ModelComparisonView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isHelpOverlayVisible) {
                HelpOverlayView()
                    .environmentObject(localization)
            }
    }
}

private struct SheetGroupB: ViewModifier {
    @ObservedObject var appState: AppState
    var localization: LocalizationManager
    @Binding var showCICDView: Bool
    @Binding var showTestCoverageView: Bool
    @Binding var showCodeQualityView: Bool
    @Binding var showMultiProjectView: Bool
    @Binding var showDockerView: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $appState.isRAGKnowledgeGraphVisible) {
                RAGKnowledgeGraphView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isUnifiedSearchVisible) {
                UnifiedKnowledgeSearchView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isAgentMemoryVisible) {
                MemoryTimelineView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isTaskDecompositionViewVisible) {
                TaskDecompositionView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isPromptOptimizationPanelVisible) {
                PromptOptimizationPanel()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showCICDView) {
                CICDView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showTestCoverageView) {
                TestCoverageView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showCodeQualityView) {
                CodeQualityDashboardView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showMultiProjectView) {
                MultiProjectView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showDockerView) {
                DockerView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
    }
}

private struct SheetGroupC: ViewModifier {
    @ObservedObject var appState: AppState
    var localization: LocalizationManager
    @Binding var showCodeKnowledgeGraphView: Bool
    @Binding var showCollaborationVizView: Bool
    @Binding var showDataFlowView: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCodeKnowledgeGraphView) {
                CodeKnowledgeGraphDetailView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showCollaborationVizView) {
                CollaborationVizView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isARVRSettingsVisible) {
                ARVRSettingsView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showDataFlowView) {
                DataFlowDetailView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
    }
}

private struct SheetGroupD: ViewModifier {
    @ObservedObject var appState: AppState
    var localization: LocalizationManager
    @Binding var showWorkflowEditorView: Bool
    @Binding var showSmartSchedulingView: Bool
    @Binding var showAnomalyDetectionView: Bool
    @Binding var showMCPManagementView: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showWorkflowEditorView) {
                WorkflowEditorView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showSmartSchedulingView) {
                SmartSchedulingView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showAnomalyDetectionView) {
                AnomalyDetectionView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $showMCPManagementView) {
                MCPManagementView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
    }
}

private struct SheetGroupE: ViewModifier {
    @ObservedObject var appState: AppState
    var localization: LocalizationManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $appState.isAnalyticsDashboardViewVisible) {
                AnalyticsDashboardView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isReportExportViewVisible) {
                ReportExportView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isAPIUsageAnalyticsViewVisible) {
                APIUsageAnalyticsView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isSessionHistoryAnalyticsViewVisible) {
                SessionHistoryAnalyticsView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
            .sheet(isPresented: $appState.isTeamPerformanceViewVisible) {
                TeamPerformanceView()
                    .environmentObject(appState)
                    .environmentObject(localization)
            }
    }
}
