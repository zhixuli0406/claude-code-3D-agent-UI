import Foundation
import AppKit
import Combine

/// Manages multi-window state for D2 feature: pop-out CLI, detachable agent detail,
/// floating monitor, and multi-monitor support.
@MainActor
class WindowManager: ObservableObject {
    // MARK: - Window visibility state

    @Published var isCLIWindowOpen = false
    @Published var isCLIWindowDetached = false
    @Published var isAgentDetailWindowOpen = false
    @Published var isFloatingMonitorOpen = false

    // MARK: - Floating monitor settings

    @Published var floatingMonitorOpacity: Double = 0.9
    @Published var floatingMonitorSize: CGSize = CGSize(width: 320, height: 240)

    // MARK: - Persistence keys

    private static let cliWindowKey = "d2_cliWindowOpen"
    private static let agentDetailWindowKey = "d2_agentDetailWindowOpen"
    private static let floatingMonitorKey = "d2_floatingMonitorOpen"
    private static let floatingMonitorOpacityKey = "d2_floatingMonitorOpacity"

    // MARK: - Floating panel window reference

    private var floatingPanel: NSPanel?

    init() {
        // Restore persisted state
        if UserDefaults.standard.object(forKey: Self.floatingMonitorOpacityKey) != nil {
            floatingMonitorOpacity = UserDefaults.standard.double(forKey: Self.floatingMonitorOpacityKey)
        }
    }

    // MARK: - Toggle methods

    func toggleCLIWindow() {
        isCLIWindowOpen.toggle()
        // When opening CLI window, mark it as detached from side panel
        if isCLIWindowOpen {
            isCLIWindowDetached = true
        }
        UserDefaults.standard.set(isCLIWindowOpen, forKey: Self.cliWindowKey)
    }

    func toggleAgentDetailWindow() {
        isAgentDetailWindowOpen.toggle()
        UserDefaults.standard.set(isAgentDetailWindowOpen, forKey: Self.agentDetailWindowKey)
    }

    func toggleFloatingMonitor() {
        isFloatingMonitorOpen.toggle()
        UserDefaults.standard.set(isFloatingMonitorOpen, forKey: Self.floatingMonitorKey)

        if isFloatingMonitorOpen {
            showFloatingPanel()
        } else {
            hideFloatingPanel()
        }
    }

    func closeCLIWindow() {
        isCLIWindowOpen = false
        isCLIWindowDetached = false
        UserDefaults.standard.set(false, forKey: Self.cliWindowKey)
    }

    func closeAgentDetailWindow() {
        isAgentDetailWindowOpen = false
        UserDefaults.standard.set(false, forKey: Self.agentDetailWindowKey)
    }

    func closeFloatingMonitor() {
        isFloatingMonitorOpen = false
        UserDefaults.standard.set(false, forKey: Self.floatingMonitorKey)
        hideFloatingPanel()
    }

    func setFloatingMonitorOpacity(_ opacity: Double) {
        floatingMonitorOpacity = opacity
        UserDefaults.standard.set(opacity, forKey: Self.floatingMonitorOpacityKey)
        floatingPanel?.alphaValue = opacity
    }

    // MARK: - Floating Panel (Always-on-top)

    private func showFloatingPanel() {
        guard floatingPanel == nil else {
            floatingPanel?.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Agent Monitor"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.alphaValue = floatingMonitorOpacity
        panel.minSize = NSSize(width: 200, height: 150)

        // Position at bottom-right of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 340
            let y = screenFrame.minY + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.delegate = FloatingPanelDelegate(manager: self)
        panel.makeKeyAndOrderFront(nil)
        floatingPanel = panel
    }

    private func hideFloatingPanel() {
        floatingPanel?.close()
        floatingPanel = nil
    }

    /// Get the floating panel's NSWindow for hosting SwiftUI content
    var floatingPanelWindow: NSPanel? {
        floatingPanel
    }

    // MARK: - Multi-monitor utilities

    /// Returns available screens for multi-monitor layout
    var availableScreens: [NSScreen] {
        NSScreen.screens
    }

    /// Whether multi-monitor mode is available (more than 1 screen)
    var isMultiMonitorAvailable: Bool {
        NSScreen.screens.count > 1
    }

    /// Move a window to a specific screen
    func moveWindowToScreen(_ window: NSWindow?, screenIndex: Int) {
        guard let window = window,
              screenIndex < NSScreen.screens.count else { return }
        let targetScreen = NSScreen.screens[screenIndex]
        let screenFrame = targetScreen.visibleFrame
        let windowSize = window.frame.size
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2
        window.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true, animate: true)
    }
}

// MARK: - NSPanel Delegate

private class FloatingPanelDelegate: NSObject, NSWindowDelegate {
    weak var manager: WindowManager?

    init(manager: WindowManager) {
        self.manager = manager
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            manager?.isFloatingMonitorOpen = false
        }
    }
}
