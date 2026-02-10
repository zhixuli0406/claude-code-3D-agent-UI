import SwiftUI

@main
struct AgentCommandApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var localization = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(appState.workspaceManager)
                .environmentObject(appState.cliProcessManager)
                .onAppear {
                    appState.localizationManager = localization
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 800)
    }
}
