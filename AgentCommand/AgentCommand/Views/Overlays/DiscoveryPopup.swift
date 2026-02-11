import SwiftUI

/// Popup shown when an easter egg or lore item is discovered
struct DiscoveryPopup: View {
    let item: ExplorationItem
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            // Icon
            Image(systemName: item.icon)
                .font(.system(size: 36))
                .foregroundStyle(iconGradient)
                .shadow(color: iconColor.opacity(0.6), radius: 8)

            // Type label
            Text(typeLabel)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(iconColor)

            // Item name
            Text(item.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            // Description
            Text(item.description)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            // Coin reward
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.yellow)
                Text("+\(item.coinReward)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            .padding(.top, 4)

            // Dismiss button
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = 0.8
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onDismiss()
                }
            }) {
                Text("Continue")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(iconColor.opacity(0.6), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(iconColor.opacity(0.6), lineWidth: 2)
                )
        )
        .shadow(color: iconColor.opacity(0.3), radius: 20)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            // Auto-dismiss after 6 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 0.8
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.35) {
                    onDismiss()
                }
            }
        }
    }

    private var iconColor: Color {
        item.type == .easterEgg ? .yellow : .cyan
    }

    private var iconGradient: LinearGradient {
        if item.type == .easterEgg {
            return LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
        }
    }

    private var typeLabel: String {
        item.type == .easterEgg ? "EASTER EGG FOUND!" : "LORE DISCOVERED!"
    }
}
