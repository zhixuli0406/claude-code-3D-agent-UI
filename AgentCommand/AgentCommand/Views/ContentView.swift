import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.openWindow) private var openWindow
    @State private var showAchievementGallery = false
    @State private var showStatsDashboard = false
    @State private var showCosmeticShop = false
    @State private var showSkillBook = false

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
        HSplitView {
            // Left: 3D Scene
            SceneContainerView()
                .frame(minWidth: 600, idealWidth: 900)

            // Right: Side panel
            SidePanelView()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { appState.showThemeSelection() }) {
                    Label(localization.localized(.theme), systemImage: "paintpalette")
                }
                .help(localization.localized(.helpChangeTheme))

                Button(action: { appState.loadSampleConfig() }) {
                    Label(localization.localized(.loadConfig), systemImage: "folder")
                }
                .help(localization.localized(.helpLoadConfig))

                // Language switcher
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
                .help(localization.localized(.language))

                // Camera presets
                Menu {
                    Button("Overview") {
                        appState.sceneManager.setCameraPreset(.overview)
                    }
                    Button("Close-Up") {
                        appState.sceneManager.setCameraPreset(.closeUp)
                    }
                    Button("Cinematic") {
                        appState.sceneManager.setCameraPreset(.cinematic)
                    }
                } label: {
                    Label("Camera", systemImage: "camera.viewfinder")
                }
                .help("Camera presets")

                // Achievement gallery
                Button(action: { showAchievementGallery = true }) {
                    Label(localization.localized(.achievements), systemImage: "trophy.fill")
                }
                .help(localization.localized(.helpAchievements))

                // Stats dashboard (B3)
                Button(action: { showStatsDashboard = true }) {
                    Label(localization.localized(.statsDashboard), systemImage: "chart.bar.xaxis")
                }
                .help(localization.localized(.helpStatsDashboard))

                // Cosmetic shop (B4)
                Button(action: { showCosmeticShop = true }) {
                    Label(localization.localized(.cosmeticShop), systemImage: "bag.fill")
                }
                .help(localization.localized(.helpCosmeticShop))

                // Skill Store (Agent Skills)
                Button(action: { showSkillBook = true }) {
                    Label(localization.localized(.skillStore), systemImage: "puzzlepiece.extension.fill")
                }
                .help(localization.localized(.helpSkillStore))

                // Task Queue toggle (D1)
                Button(action: { appState.toggleTaskQueue() }) {
                    Label(localization.localized(.taskQueue), systemImage: appState.isTaskQueueVisible ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                }
                .help(localization.localized(.helpTaskQueue))

                // Multi-Window menu (D2)
                Menu {
                    Button(action: {
                        openWindow(id: "cli-output")
                        appState.windowManager.isCLIWindowOpen = true
                        appState.windowManager.isCLIWindowDetached = true
                    }) {
                        Label(localization.localized(.popOutCLI), systemImage: "terminal")
                    }
                    .help(localization.localized(.helpPopOutCLI))

                    Button(action: {
                        openWindow(id: "agent-details")
                        appState.windowManager.isAgentDetailWindowOpen = true
                    }) {
                        Label(localization.localized(.detachAgentPanel), systemImage: "person.crop.rectangle")
                    }
                    .help(localization.localized(.helpDetachAgentPanel))

                    Button(action: {
                        openWindow(id: "floating-monitor")
                        appState.windowManager.isFloatingMonitorOpen = true
                    }) {
                        Label(localization.localized(.floatingMonitor), systemImage: "pip")
                    }
                    .help(localization.localized(.helpFloatingMonitor))

                    if NSScreen.screens.count > 1 {
                        Divider()
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
                } label: {
                    Label(localization.localized(.multiWindow), systemImage: "macwindow.on.rectangle")
                }
                .help(localization.localized(.helpMultiWindow))

                // Mini-map toggle (B6)
                Button(action: { appState.toggleMiniMap() }) {
                    Label(localization.localized(.miniMap), systemImage: appState.isMiniMapVisible ? "map.fill" : "map")
                }
                .help(localization.localized(.helpMiniMap))

                // Notifications toggle
                Button(action: {
                    appState.notificationManager.requestPermission()
                    appState.notificationManager.isEnabled.toggle()
                }) {
                    Label("Notifications", systemImage: appState.notificationManager.isEnabled ? "bell.fill" : "bell.slash")
                }
                .help("Toggle notifications")

                Button(action: { appState.soundManager.isMuted.toggle() }) {
                    Label(localization.localized(.sound), systemImage: appState.soundManager.isMuted ? "speaker.slash" : "speaker.wave.2")
                }
                .help(localization.localized(.helpToggleSound))

                WorkspacePicker()
            }
        }
        .background(Color(nsColor: appState.sceneManager.sceneBackgroundColor))
        .onAppear {
            if appState.agents.isEmpty {
                appState.rebuildScene()
            }
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
        .sheet(item: $appState.askUserQuestionData) { questionData in
            AskUserQuestionSheet(
                data: questionData,
                onSubmit: { answers in
                    appState.submitAskUserAnswer(answers)
                },
                onCancel: {
                    appState.cancelAskUserQuestion()
                }
            )
            .environmentObject(localization)
        }
        .sheet(item: $appState.planReviewData) { reviewData in
            PlanReviewSheet(
                data: reviewData,
                onApprove: {
                    appState.approvePlan()
                },
                onReject: { feedback in
                    appState.rejectPlan(feedback: feedback)
                }
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
    }
}
