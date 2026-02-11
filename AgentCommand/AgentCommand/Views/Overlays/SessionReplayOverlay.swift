import SwiftUI

/// Compact floating playback controls shown during session replay (D4)
struct SessionReplayOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause
            Button(action: {
                switch appState.sessionHistoryManager.replayState {
                case .playing:
                    appState.sessionHistoryManager.pauseReplay()
                case .paused, .finished:
                    if appState.sessionHistoryManager.replayState == .finished {
                        appState.sessionHistoryManager.seekTo(progress: 0)
                    }
                    appState.sessionHistoryManager.resumeReplay()
                default:
                    break
                }
            }) {
                Image(systemName: appState.sessionHistoryManager.replayState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            // Stop
            Button(action: { appState.stopSessionReplay() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))

            // Speed
            Menu {
                ForEach([0.5, 1.0, 2.0, 4.0, 8.0], id: \.self) { speed in
                    Button(action: {
                        appState.sessionHistoryManager.setReplaySpeed(speed)
                    }) {
                        HStack {
                            Text(speedLabel(speed))
                            if appState.sessionHistoryManager.replaySpeed == speed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(speedLabel(appState.sessionHistoryManager.replaySpeed))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00BCD4").opacity(0.15))
                    .cornerRadius(4)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#00BCD4"))
                        .frame(width: geometry.size.width * appState.sessionHistoryManager.replayProgress, height: 4)
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            appState.sessionHistoryManager.seekTo(progress: progress)
                        }
                )
            }
            .frame(width: 120, height: 24)

            // Event counter
            if let session = appState.sessionHistoryManager.replaySession {
                Text("\(appState.sessionHistoryManager.replayEventIndex)/\(session.timelineEvents.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Time
            if let time = appState.sessionHistoryManager.replayCurrentTime {
                Text(formatTime(time))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Replay mode badge
            HStack(spacing: 3) {
                Circle()
                    .fill(Color(hex: "#00BCD4"))
                    .frame(width: 5, height: 5)
                Text(localization.localized(.replayMode))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#0D1117").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#00BCD4").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 6)
    }

    private func speedLabel(_ speed: Double) -> String {
        if speed == 1.0 { return "1x" }
        if speed < 1 { return String(format: "%.1fx", speed) }
        return "\(Int(speed))x"
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }
}
