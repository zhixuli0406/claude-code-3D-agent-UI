import SwiftUI

struct WorkspacePicker: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        Menu {
            ForEach(workspaceManager.workspaces) { ws in
                Button(action: { workspaceManager.selectWorkspace(ws.id) }) {
                    HStack {
                        Text(ws.name)
                        Text(ws.displayPath)
                            .foregroundColor(.secondary)
                        if workspaceManager.activeWorkspace?.id == ws.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button(action: { workspaceManager.addWorkspaceFromPanel() }) {
                Label(localization.localized(.addWorkspace), systemImage: "plus.circle")
            }

            if let activeId = workspaceManager.activeWorkspace?.id {
                Button(action: { workspaceManager.removeWorkspace(activeId) }) {
                    Label(localization.localized(.removeWorkspace), systemImage: "minus.circle")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                Text(workspaceManager.activeWorkspace?.name ?? localization.localized(.noWorkspace))
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundColor(Color(hex: "#00BCD4"))
        }
    }
}
