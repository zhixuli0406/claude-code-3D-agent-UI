import SwiftUI

/// Modal sheet for AR/VR Settings (J3)
struct ARVRSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            settingsContent
        }
        .frame(width: 500, height: 450)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "visionpro")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#AB47BC"))
            Text(localization.localized(.arvrSettings))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text(appState.arvrManager.settings.currentPlatform.displayName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#AB47BC"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#AB47BC").opacity(0.1))
                .cornerRadius(4)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Platform
                sectionHeader(localization.localized(.arvrPlatform))
                HStack(spacing: 12) {
                    ForEach(ARVRPlatform.allCases) { platform in
                        platformCard(platform)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Immersive Level
                sectionHeader(localization.localized(.arvrImmersiveLevel))
                HStack(spacing: 8) {
                    ForEach(ImmersiveLevel.allCases, id: \.rawValue) { level in
                        Button(action: { appState.arvrManager.setImmersiveLevel(level) }) {
                            VStack(spacing: 4) {
                                Text(level.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(appState.arvrManager.settings.immersiveLevel == level ? Color(hex: level.hexColor) : .white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(appState.arvrManager.settings.immersiveLevel == level ? Color(hex: level.hexColor).opacity(0.15) : Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Controls
                sectionHeader(localization.localized(.arvrControls))

                toggleRow(
                    icon: "hand.raised",
                    title: localization.localized(.arvrGestureControl),
                    subtitle: localization.localized(.arvrGestureControlDesc),
                    isOn: appState.arvrManager.settings.gestureControlEnabled,
                    action: { appState.arvrManager.toggleGestureControl() }
                )

                toggleRow(
                    icon: "hand.point.up.left",
                    title: localization.localized(.arvrHandTracking),
                    subtitle: localization.localized(.arvrHandTrackingDesc),
                    isOn: appState.arvrManager.settings.handTrackingEnabled,
                    action: { appState.arvrManager.toggleHandTracking() }
                )

                toggleRow(
                    icon: "speaker.wave.3.fill",
                    title: localization.localized(.arvrSpatialAudio),
                    subtitle: localization.localized(.arvrSpatialAudioDesc),
                    isOn: appState.arvrManager.settings.spatialAudioEnabled,
                    action: { appState.arvrManager.toggleSpatialAudio() }
                )

                toggleRow(
                    icon: "rectangle.on.rectangle",
                    title: localization.localized(.arvrPassthrough),
                    subtitle: localization.localized(.arvrPassthroughDesc),
                    isOn: appState.arvrManager.settings.passthrough,
                    action: { appState.arvrManager.togglePassthrough() }
                )

                // Gesture types
                if appState.arvrManager.settings.gestureControlEnabled {
                    Divider().background(Color.white.opacity(0.1))
                    sectionHeader(localization.localized(.arvrGestures))

                    ForEach(GestureType.allCases, id: \.rawValue) { gesture in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: gesture.hexColor))
                                .frame(width: 8, height: 8)
                            Text(gesture.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                    }
                }

                // visionOS status
                if !appState.arvrManager.isVisionOSAvailable {
                    Divider().background(Color.white.opacity(0.1))
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FF9800"))
                        Text(localization.localized(.arvrVisionOSNotAvailable))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(10)
                    .background(Color(hex: "#FF9800").opacity(0.05))
                    .cornerRadius(6)
                }
            }
            .padding(16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white.opacity(0.9))
    }

    private func platformCard(_ platform: ARVRPlatform) -> some View {
        let isSelected = appState.arvrManager.settings.currentPlatform == platform
        return VStack(spacing: 8) {
            Image(systemName: platform.iconName)
                .font(.system(size: 24))
            Text(platform.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(isSelected ? Color(hex: "#AB47BC") : .white.opacity(0.5))
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color(hex: "#AB47BC").opacity(0.1) : Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color(hex: "#AB47BC").opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isOn ? Color(hex: "#AB47BC") : .white.opacity(0.4))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn ? Color(hex: "#AB47BC") : Color.white.opacity(0.15))
                    .frame(width: 36, height: 20)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .offset(x: isOn ? 8 : -8)
                    )
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
