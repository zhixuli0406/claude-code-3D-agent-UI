import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

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

                Divider()

                Button(action: { appState.loadSampleConfig() }) {
                    Label(localization.localized(.loadConfig), systemImage: "folder")
                }
                .help(localization.localized(.helpLoadConfig))

                Divider()

                if appState.isSimulationRunning {
                    Button(action: { appState.pauseSimulation() }) {
                        Label(localization.localized(.pause), systemImage: "pause.fill")
                    }
                    .help(localization.localized(.helpPauseSimulation))
                } else {
                    Button(action: { appState.startSimulation() }) {
                        Label(localization.localized(.start), systemImage: "play.fill")
                    }
                    .help(localization.localized(.helpStartSimulation))
                    .disabled(appState.agents.isEmpty)
                }

                Button(action: { appState.resetSimulation() }) {
                    Label(localization.localized(.reset), systemImage: "arrow.counterclockwise")
                }
                .help(localization.localized(.helpResetSimulation))

                Divider()

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

                Divider()

                // Execution mode toggle
                Picker(localization.localized(.executionMode), selection: $appState.executionMode) {
                    Text(localization.localized(.simulation)).tag(AppState.ExecutionMode.simulation)
                    Text(localization.localized(.liveCLI)).tag(AppState.ExecutionMode.live)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                // Workspace picker (only in live mode)
                if appState.executionMode == .live {
                    WorkspacePicker()
                }
            }
        }
        .background(Color(nsColor: appState.sceneManager.sceneBackgroundColor))
        .onAppear {
            if appState.agents.isEmpty {
                appState.loadSampleConfig()
            }
        }
    }
}
