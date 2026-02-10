import Foundation
import AppKit

@MainActor
class WorkspaceManager: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var activeWorkspace: Workspace?

    private static let storageKey = "savedWorkspaces"
    private static let activeKey = "activeWorkspaceId"

    init() {
        loadWorkspaces()
    }

    var activeDirectory: String {
        activeWorkspace?.path ?? NSHomeDirectory()
    }

    func addWorkspace(name: String, path: String) -> Workspace {
        let ws = Workspace(
            id: UUID(),
            name: name,
            path: path,
            lastUsedAt: Date(),
            isDefault: workspaces.isEmpty
        )
        workspaces.append(ws)
        if activeWorkspace == nil {
            activeWorkspace = ws
        }
        saveWorkspaces()
        return ws
    }

    func removeWorkspace(_ id: UUID) {
        workspaces.removeAll { $0.id == id }
        if activeWorkspace?.id == id {
            activeWorkspace = workspaces.first
        }
        saveWorkspaces()
    }

    func selectWorkspace(_ id: UUID) {
        guard let idx = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[idx].lastUsedAt = Date()
        activeWorkspace = workspaces[idx]
        UserDefaults.standard.set(id.uuidString, forKey: Self.activeKey)
        saveWorkspaces()
    }

    func addWorkspaceFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory"

        if panel.runModal() == .OK, let url = panel.url {
            let name = url.lastPathComponent
            let _ = addWorkspace(name: name, path: url.path)
        }
    }

    // MARK: - Persistence

    private func saveWorkspaces() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func loadWorkspaces() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let loaded = try? JSONDecoder().decode([Workspace].self, from: data) else { return }
        workspaces = loaded

        if let activeId = UserDefaults.standard.string(forKey: Self.activeKey),
           let uuid = UUID(uuidString: activeId),
           let ws = workspaces.first(where: { $0.id == uuid }) {
            activeWorkspace = ws
        } else {
            activeWorkspace = workspaces.first
        }
    }
}
