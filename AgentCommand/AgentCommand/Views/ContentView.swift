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

                WorkspacePicker()
            }
        }
        .background(Color(nsColor: appState.sceneManager.sceneBackgroundColor))
        .onAppear {
            if appState.agents.isEmpty {
                appState.loadSampleConfig()
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
    }
}
