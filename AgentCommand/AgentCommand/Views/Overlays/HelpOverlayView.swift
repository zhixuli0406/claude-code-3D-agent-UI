import SwiftUI

struct HelpOverlayView: View {
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                Text(localization.localized(.helpOverlayTitle))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.6))

            Divider()
                .background(Color.cyan.opacity(0.3))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Keyboard Shortcuts Section
                    helpSection(
                        title: localization.localized(.helpKeyboardShortcuts),
                        icon: "keyboard",
                        items: [
                            (localization.localized(.helpKeyF1), localization.localized(.helpKeyF1Desc)),
                            (localization.localized(.helpKeyEscape), localization.localized(.helpKeyEscapeDesc))
                        ]
                    )

                    // Mouse Interactions Section
                    helpSection(
                        title: localization.localized(.helpMouseInteractions),
                        icon: "cursorarrow.click.2",
                        items: [
                            (localization.localized(.helpClickAgent), localization.localized(.helpClickAgentDesc)),
                            (localization.localized(.helpDoubleClickAgent), localization.localized(.helpDoubleClickAgentDesc)),
                            (localization.localized(.helpRightClickAgent), localization.localized(.helpRightClickAgentDesc)),
                            (localization.localized(.helpDragTask), localization.localized(.helpDragTaskDesc))
                        ]
                    )

                    // Camera Controls Section
                    helpSection(
                        title: localization.localized(.helpCameraControls),
                        icon: "camera.viewfinder",
                        items: [
                            (localization.localized(.helpCameraOrbit), localization.localized(.helpCameraOrbitDesc)),
                            (localization.localized(.helpCameraZoom), localization.localized(.helpCameraZoomDesc)),
                            (localization.localized(.helpCameraPresets), localization.localized(.helpCameraPresetsDesc)),
                            (localization.localized(.helpCameraPiP), localization.localized(.helpCameraPiPDesc)),
                            (localization.localized(.helpCameraFirstPerson), localization.localized(.helpCameraFirstPersonDesc))
                        ]
                    )

                    // Features Section
                    helpSection(
                        title: localization.localized(.helpFeatures),
                        icon: "star.fill",
                        items: [
                            (localization.localized(.achievements), localization.localized(.helpAchievements)),
                            (localization.localized(.cosmeticShop), localization.localized(.helpCosmeticShop)),
                            (localization.localized(.taskQueue), localization.localized(.helpTaskQueue)),
                            (localization.localized(.performanceMetrics), localization.localized(.helpPerformanceMetrics)),
                            (localization.localized(.miniMap), localization.localized(.helpMiniMap)),
                            (localization.localized(.gitIntegration), localization.localized(.helpGitIntegration)),
                            (localization.localized(.promptTemplates), localization.localized(.helpPromptTemplates)),
                            (localization.localized(.modelComparison), localization.localized(.helpModelComparison))
                        ]
                    )
                }
                .padding(16)
            }

            // Footer
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Text(localization.localized(.helpOKButton))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.cyan.opacity(0.8))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.4))
        }
        .frame(width: 520, height: 600)
        .background(Color(hex: "#0D1117"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 16)
    }

    private func helpSection(title: String, icon: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.cyan)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    helpItem(label: items[index].0, description: items[index].1)
                }
            }
        }
    }

    private func helpItem(label: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.9))
                .frame(minWidth: 140, alignment: .leading)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.03))
        .cornerRadius(4)
    }
}
