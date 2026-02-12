import SwiftUI

/// Floating tooltip that appears when hovering over a 3D agent
struct AgentTooltipOverlay: View {
    let hoveredAgent: Agent?
    let hoveredTask: AgentTask?
    let screenPosition: CGPoint
    let viewSize: CGSize

    var body: some View {
        if let agent = hoveredAgent {
            tooltipContent(agent: agent)
                .position(clampedPosition)
                .animation(.easeInOut(duration: 0.12), value: agent.id)
        }
    }

    private func tooltipContent(agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name + Role
            HStack(spacing: 4) {
                Text(agent.role.emoji)
                    .font(.system(size: 11))
                Text(agent.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text("(\(agent.role.displayName))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(nsColor: NSColor(hex: agent.status.hexColor)))
                    .frame(width: 6, height: 6)
                Text(agent.status.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: NSColor(hex: agent.status.hexColor)))
            }

            // Model
            HStack(spacing: 4) {
                Text(agent.selectedModel.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: NSColor(hex: agent.selectedModel.hexColor)))
            }

            // E1: Personality & Mood
            HStack(spacing: 4) {
                Text(agent.personality.trait.emoji)
                    .font(.system(size: 10))
                Text(agent.personality.trait.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Text(agent.personality.mood.emoji)
                    .font(.system(size: 10))
            }

            // Current task
            if let task = hoveredTask {
                Divider()
                    .background(Color.white.opacity(0.2))
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(task.title.prefix(50)))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                if task.progress > 0 {
                    ProgressView(value: task.progress)
                        .tint(Color(nsColor: NSColor(hex: "#4CAF50")))
                        .scaleEffect(y: 0.5)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }

    private var clampedPosition: CGPoint {
        let tooltipWidth: CGFloat = 200
        let tooltipHeight: CGFloat = 80
        let padding: CGFloat = 10

        var x = screenPosition.x
        var y = screenPosition.y - 50 // above the projected point

        // Clamp to view bounds
        x = max(tooltipWidth / 2 + padding, min(viewSize.width - tooltipWidth / 2 - padding, x))
        y = max(tooltipHeight / 2 + padding, min(viewSize.height - tooltipHeight / 2 - padding, y))

        return CGPoint(x: x, y: y)
    }
}
