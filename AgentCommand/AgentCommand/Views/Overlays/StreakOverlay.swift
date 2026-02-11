import SwiftUI

/// Displays the current task completion streak counter
struct StreakOverlay: View {
    let streak: Int
    let bestStreak: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(streakColor)
                    .font(.system(size: 14))

                Text("\(streak)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                if streak >= 3 {
                    Text("x\(multiplier)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(streakColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(streakColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(streakColor.opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }

    private var streakColor: Color {
        if streak >= 10 { return .red }
        if streak >= 5 { return .orange }
        if streak >= 3 { return .yellow }
        return .orange
    }

    private var multiplier: String {
        if streak >= 10 { return "3" }
        if streak >= 5 { return "2" }
        return "1.5"
    }
}

/// Animated overlay shown when a streak is broken
struct StreakBreakOverlay: View {
    let lostStreak: Int
    let agentName: String

    @State private var isAnimating = false
    @State private var shakeOffset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.slash.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 1) {
                Text("STREAK LOST")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)

                Text("\(lostStreak)x combo broken!")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.8), lineWidth: 1.5)
                )
        )
        .offset(x: shakeOffset)
        .opacity(opacity)
        .onAppear {
            // Shake animation
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 5).speed(2)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 5).speed(2)) {
                    shakeOffset = -6
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 8)) {
                    shakeOffset = 0
                }
            }

            // Fade out after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.8)) {
                    opacity = 0
                }
            }
        }
    }
}
