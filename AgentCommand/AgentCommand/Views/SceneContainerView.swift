import SwiftUI

struct SceneContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // 3D Scene
                SceneKitView(
                    sceneManager: appState.sceneManager,
                    backgroundColor: appState.sceneManager.sceneBackgroundColor,
                    onAgentSelected: { agentId in
                        appState.selectAgent(agentId)
                    },
                    onAgentDoubleClicked: { agentId in
                        appState.doubleClickAgent(agentId)
                    },
                    onAgentRightClicked: { agentId, screenPos in
                        appState.rightClickAgent(agentId, at: screenPos)
                    },
                    onAgentHovered: { agentId, screenPos in
                        appState.hoveredAgentId = agentId
                        appState.hoveredAgentScreenPos = screenPos
                    },
                    isFirstPersonMode: appState.isFirstPersonMode,
                    firstPersonUpdateHandler: appState.isFirstPersonMode ? { [weak sceneManager = appState.sceneManager] in
                        sceneManager?.updateFirstPersonCamera()
                    } : nil,
                    onTaskDragHovered: { agentId in
                        appState.dragHoveredAgentId = agentId
                        if let agentId = agentId {
                            appState.sceneManager.showDropHighlight(agentId)
                        } else {
                            appState.sceneManager.clearDropHighlight()
                        }
                    },
                    onTaskDroppedOnAgent: { agentId, payload in
                        appState.sceneManager.clearDropHighlight()
                        appState.dragHoveredAgentId = nil
                        // Parse "task:<UUID>" payload
                        let taskIdString = String(payload.dropFirst("task:".count))
                        guard let taskId = UUID(uuidString: taskIdString) else { return false }
                        appState.assignPendingTaskToAgent(taskId: taskId, agentId: agentId)
                        return true
                    }
                )

                // Top-left: agent status legend
                VStack(alignment: .leading) {
                    StatusBadgeOverlay(
                        agents: appState.agents,
                        selectedAgentId: appState.selectedAgentId
                    )
                    .allowsHitTesting(false)

                    Spacer()
                }

                // Top-center: progress HUD
                VStack {
                    HStack {
                        Spacer()
                        ProgressOverlay(tasks: appState.tasks)
                            .allowsHitTesting(false)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 8)

                // Top-right: camera controls + streak
                VStack(alignment: .trailing, spacing: 8) {
                    CameraControlOverlay(
                        onPreset: { preset in
                            appState.sceneManager.setCameraPreset(preset)
                        },
                        onTogglePiP: {
                            appState.togglePiP()
                        },
                        onToggleFirstPerson: {
                            appState.toggleFirstPerson()
                        },
                        isPiPEnabled: appState.isPiPEnabled,
                        isFirstPersonMode: appState.isFirstPersonMode,
                        hasSelectedAgent: appState.selectedAgentId != nil
                    )

                    // Streak counter or streak-break notification
                    if let breakInfo = appState.streakBreakInfo {
                        StreakBreakOverlay(lostStreak: breakInfo.lostStreak, agentName: breakInfo.agentName)
                            .transition(.scale.combined(with: .opacity))
                            .id("streakBreak-\(breakInfo.lostStreak)-\(breakInfo.agentName)")
                    } else if let selectedAgent = appState.selectedAgent {
                        let stats = appState.statsManager.statsFor(agentName: selectedAgent.name)
                        StreakOverlay(streak: stats.currentStreak, bestStreak: stats.bestStreak)
                    }

                    Spacer()
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Hover tooltip
                GeometryReader { geometry in
                    AgentTooltipOverlay(
                        hoveredAgent: appState.hoveredAgent,
                        hoveredTask: appState.hoveredAgentTask,
                        screenPosition: appState.hoveredAgentScreenPos ?? .zero,
                        viewSize: geometry.size
                    )
                }
                .allowsHitTesting(false)

                // Achievement popup
                if let achievementId = appState.achievementManager.pendingPopup {
                    VStack {
                        AchievementPopup(
                            achievementId: achievementId,
                            onDismiss: {
                                appState.achievementManager.dismissPopup()
                            }
                        )
                        .onAppearAnimate()
                        .padding(.top, 60)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(true)
                }

                // PiP inset (bottom-left corner)
                if appState.isPiPEnabled {
                    let pipConfig = appState.sceneManager.pipCameraConfig()
                    VStack {
                        Spacer()
                        HStack {
                            PiPSceneView(
                                scene: appState.sceneManager.scene,
                                cameraPosition: pipConfig.position,
                                lookAt: pipConfig.lookAt,
                                fov: pipConfig.fov
                            )
                            .frame(width: 220, height: 165)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#00BCD4").opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .padding(12)
                            Spacer()
                        }
                    }
                }

                // Task Queue (left side, D1)
                if appState.isTaskQueueVisible && !appState.pendingTasksOrdered.isEmpty {
                    VStack {
                        HStack {
                            TaskQueueOverlay()
                                .padding(.leading, 12)
                                .padding(.top, 80)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                // Performance Metrics & RAG Status & Task Decomposition & Memory & Prompt Optimization & I-series (right side)
                if appState.isMetricsVisible || appState.isRAGStatusVisible || appState.isTaskDecompositionStatusVisible || appState.isAgentMemoryOverlayVisible || appState.isPromptOptimizationVisible || appState.isCICDStatusVisible || appState.isTestCoverageStatusVisible || appState.isCodeQualityStatusVisible || appState.isMultiProjectStatusVisible || appState.isDockerStatusVisible || appState.isCodeKnowledgeGraphStatusVisible || appState.isCollaborationVizStatusVisible || appState.isDataFlowStatusVisible || appState.isWorkflowStatusVisible || appState.isSmartSchedulingStatusVisible || appState.isAnomalyDetectionStatusVisible || appState.isMCPStatusVisible {
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 8) {
                                    if appState.isMetricsVisible {
                                        PerformanceMetricsOverlay()
                                    }
                                    if appState.isRAGStatusVisible {
                                        RAGStatusOverlay()
                                    }
                                    if appState.isAgentMemoryOverlayVisible {
                                        AgentMemoryOverlay()
                                    }
                                    if appState.isTaskDecompositionStatusVisible {
                                        TaskDecompositionStatusOverlay()
                                    }
                                    if appState.isPromptOptimizationVisible {
                                        PromptOptimizationOverlay()
                                    }
                                    if appState.isCICDStatusVisible {
                                        CICDStatusOverlay()
                                    }
                                    if appState.isTestCoverageStatusVisible {
                                        TestCoverageOverlay()
                                    }
                                    if appState.isCodeQualityStatusVisible {
                                        CodeQualityOverlay()
                                    }
                                    if appState.isMultiProjectStatusVisible {
                                        MultiProjectOverlay()
                                    }
                                    if appState.isDockerStatusVisible {
                                        DockerStatusOverlay()
                                    }
                                    if appState.isCodeKnowledgeGraphStatusVisible {
                                        CodeKnowledgeGraphOverlay()
                                    }
                                    if appState.isCollaborationVizStatusVisible {
                                        CollaborationVizOverlay()
                                    }
                                    if appState.isDataFlowStatusVisible {
                                        DataFlowOverlay()
                                    }
                                    if appState.isWorkflowStatusVisible {
                                        WorkflowStatusOverlay()
                                    }
                                    if appState.isSmartSchedulingStatusVisible {
                                        SmartSchedulingOverlay()
                                    }
                                    if appState.isAnomalyDetectionStatusVisible {
                                        AnomalyDetectionOverlay()
                                    }
                                    if appState.isMCPStatusVisible {
                                        MCPStatusOverlay()
                                    }
                                    if appState.isAnalyticsDashboardStatusVisible {
                                        AnalyticsDashboardOverlay()
                                    }
                                    if appState.isReportExportStatusVisible {
                                        ReportExportOverlay()
                                    }
                                    if appState.isAPIUsageAnalyticsStatusVisible {
                                        APIUsageAnalyticsOverlay()
                                    }
                                }
                            }
                            .padding(.trailing, 12)
                            .padding(.top, 80)
                        }
                        Spacer()
                    }
                }

                // Mini-map (bottom-right corner, B6)
                if appState.isMiniMapVisible {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MiniMapOverlay(onAgentTap: { agentId in
                                appState.selectAgent(agentId)
                                appState.sceneManager.zoomToAgent(agentId)
                            })
                            .padding(12)
                        }
                    }
                }

                // Discovery popup (center, B6)
                if let discovery = appState.discoveryPopupItem {
                    DiscoveryPopup(
                        item: discovery,
                        onDismiss: { appState.dismissDiscoveryPopup() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }

                // Session Replay controls (bottom-center, D4)
                if appState.isInReplayMode {
                    VStack {
                        Spacer()
                        SessionReplayOverlay()
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Timeline
            if !appState.timelineManager.events.isEmpty {
                TimelineView(timelineManager: appState.timelineManager)
            }

            // Unified search results overlay (above prompt bar)
            if !appState.ragManager.searchResults.isEmpty || appState.unifiedSearchResponse?.hasResults == true {
                RAGSearchResultsOverlay(onSelectSnippet: { _ in })
            }

            // Bottom: prompt input bar or replay indicator
            if appState.isInReplayMode {
                replayModeBar
            } else {
                PromptInputBar()
            }
        }
        // Escape key to exit first-person mode or close help overlay
        .onKeyPress(.escape) {
            if appState.isHelpOverlayVisible {
                appState.isHelpOverlayVisible = false
                return .handled
            }
            if appState.isFirstPersonMode {
                appState.exitFirstPerson()
                return .handled
            }
            return .ignored
        }
        // Right-click context menu via popover
        .overlay {
            if let agentId = appState.rightClickedAgentId,
               let agent = appState.agents.first(where: { $0.id == agentId }) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.rightClickedAgentId = nil
                    }
                    .overlay(alignment: .topLeading) {
                        AgentContextMenu(
                            agent: agent,
                            onViewLogs: {
                                appState.selectAgent(agentId)
                                appState.rightClickedAgentId = nil
                            },
                            onZoomTo: {
                                appState.doubleClickAgent(agentId)
                                appState.rightClickedAgentId = nil
                            },
                            onCancel: {
                                if let task = appState.tasks.first(where: { $0.assignedAgentId == agentId && $0.status == .inProgress }) {
                                    appState.cancelTask(task.id)
                                }
                                appState.rightClickedAgentId = nil
                            },
                            onDismiss: {
                                appState.rightClickedAgentId = nil
                            }
                        )
                        .offset(
                            x: appState.rightClickScreenPos?.x ?? 0,
                            y: appState.rightClickScreenPos?.y ?? 0
                        )
                    }
            }
        }
    }

    // D4: Replay mode indicator bar
    private var replayModeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.circle.fill")
                .foregroundColor(Color(hex: "#00BCD4"))
            Text("Replay Mode")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Button(action: { appState.stopSessionReplay() }) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                    Text("Stop Replay")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.6))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#0D1117"))
    }
}

/// Context menu shown on right-click of an agent
struct AgentContextMenu: View {
    let agent: Agent
    let onViewLogs: () -> Void
    let onZoomTo: () -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeader

            Divider()
                .background(Color.white.opacity(0.2))

            menuItem(icon: "doc.text", title: "View Logs", action: onViewLogs)
            menuItem(icon: "camera.metering.spot", title: "Zoom To Agent", action: onZoomTo)

            if agent.status == .working || agent.status == .thinking {
                Divider()
                    .background(Color.white.opacity(0.2))
                menuItem(icon: "xmark.circle", title: "Cancel Task", isDestructive: true, action: onCancel)
            }
        }
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#1E1E2E")))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var menuHeader: some View {
        HStack(spacing: 6) {
            Text(agent.role.emoji)
                .font(.system(size: 14))
            Text(agent.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Circle()
                .fill(Color(nsColor: NSColor(hex: agent.status.hexColor)))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func menuItem(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red : .white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }
}
