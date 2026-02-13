import SwiftUI

// MARK: - I4: Multi-Project Overlay (right-side floating panel)

struct MultiProjectOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#673AB7").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#673AB7").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#673AB7"))
            Text(localization.localized(.multiProject))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text("\(appState.multiProjectManager.projects.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            ForEach(appState.multiProjectManager.projects) { project in
                projectRow(project)
            }

            if appState.multiProjectManager.projects.isEmpty {
                Text(localization.localized(.mpNoProjects))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func projectRow(_ project: ProjectWorkspace) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: project.iconColor))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(project.isActive ? 0.8 : 0), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 10, weight: project.isActive ? .semibold : .regular))
                    .foregroundColor(.white.opacity(project.isActive ? 1.0 : 0.7))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 7))
                    Text("\(project.activeAgentCount)")
                        .font(.system(size: 8, design: .monospaced))
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 7))
                    Text("\(project.completedTasks)")
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            if project.isActive {
                Text(localization.localized(.mpActive))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(hex: "#4CAF50"))
            }
        }
    }
}
