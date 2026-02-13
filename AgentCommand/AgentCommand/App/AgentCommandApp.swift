import SwiftUI

@main
struct AgentCommandApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var localization = LocalizationManager()

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(appState.workspaceManager)
                .environmentObject(appState.cliProcessManager)
                .environmentObject(appState.windowManager)
                .onAppear {
                    appState.localizationManager = localization
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appState.shutdown()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 800)

        // D2: Pop-out CLI Output window
        Window("CLI Output", id: "cli-output") {
            CLIOutputWindowView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(appState.cliProcessManager)
                .environmentObject(appState.windowManager)
        }
        .defaultSize(width: 700, height: 500)
        .defaultPosition(.trailing)

        // D2: Detachable Agent Detail window
        Window("Agent Details", id: "agent-details") {
            AgentDetailWindowView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(appState.windowManager)
        }
        .defaultSize(width: 420, height: 600)
        .defaultPosition(.leading)

        // D2: Floating Monitor window
        Window("Agent Monitor", id: "floating-monitor") {
            FloatingMonitorView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(appState.windowManager)
        }
        .defaultSize(width: 320, height: 280)
        .defaultPosition(.bottomTrailing)
        .windowStyle(.hiddenTitleBar)
    }
}
