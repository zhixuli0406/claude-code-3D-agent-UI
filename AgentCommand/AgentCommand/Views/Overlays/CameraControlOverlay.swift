import SwiftUI

/// Floating camera control buttons overlay on the 3D scene
struct CameraControlOverlay: View {
    let onPreset: (ThemeableScene.CameraPreset) -> Void
    let onTogglePiP: () -> Void
    let onToggleFirstPerson: () -> Void
    let isPiPEnabled: Bool
    let isFirstPersonMode: Bool
    let hasSelectedAgent: Bool

    var body: some View {
        VStack(spacing: 6) {
            cameraButton(icon: "eye", tooltip: "Overview", preset: .overview)
            cameraButton(icon: "magnifyingglass", tooltip: "Close-up", preset: .closeUp)
            cameraButton(icon: "film", tooltip: "Cinematic", preset: .cinematic)

            Divider()
                .frame(width: 20)
                .background(Color.white.opacity(0.2))

            // PiP toggle
            toggleButton(
                icon: "rectangle.inset.filled",
                tooltip: "Picture-in-Picture",
                isActive: isPiPEnabled,
                action: onTogglePiP
            )

            // First-person toggle
            toggleButton(
                icon: "person.fill.viewfinder",
                tooltip: "First-Person View",
                isActive: isFirstPersonMode,
                action: onToggleFirstPerson
            )
            .disabled(!hasSelectedAgent && !isFirstPersonMode)
            .opacity((!hasSelectedAgent && !isFirstPersonMode) ? 0.4 : 1.0)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func cameraButton(icon: String, tooltip: String, preset: ThemeableScene.CameraPreset) -> some View {
        Button(action: { onPreset(preset) }) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func toggleButton(icon: String, tooltip: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isActive ? Color(hex: "#00BCD4") : .white.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(isActive ? Color(hex: "#00BCD4").opacity(0.2) : Color.white.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color(hex: "#00BCD4").opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
