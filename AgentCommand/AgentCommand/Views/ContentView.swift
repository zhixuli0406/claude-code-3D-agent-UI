import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

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
                    Label("Theme", systemImage: "paintpalette")
                }
                .help("Change scene theme (\(appState.currentTheme.displayName))")

                Divider()

                Button(action: { appState.loadSampleConfig() }) {
                    Label("Load Config", systemImage: "folder")
                }
                .help("Load sample configuration")

                Divider()

                if appState.isSimulationRunning {
                    Button(action: { appState.pauseSimulation() }) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .help("Pause simulation")
                } else {
                    Button(action: { appState.startSimulation() }) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .help("Start simulation")
                    .disabled(appState.agents.isEmpty)
                }

                Button(action: { appState.resetSimulation() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .help("Reset simulation")
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
