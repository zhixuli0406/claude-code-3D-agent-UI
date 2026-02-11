import SwiftUI

/// Animated popup when an achievement is unlocked
struct AchievementPopup: View {
    let achievementId: AchievementId
    let onDismiss: () -> Void

    @State private var isShowing = false
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        if isShowing {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 16))

                    Text("Achievement Unlocked!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.yellow)
                }

                HStack(spacing: 10) {
                    Image(systemName: achievementId.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievementId.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        Text(achievementId.description)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.6), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: .yellow.opacity(0.3), radius: 12)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onTapGesture { dismiss() }
        }
    }

    private func dismiss() {
        autoDismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.3)) {
            isShowing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }

    func onAppearAnimate() -> some View {
        self.onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isShowing = true
            }
            autoDismissTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { dismiss() }
            }
        }
    }
}
