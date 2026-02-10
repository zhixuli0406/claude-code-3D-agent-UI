import SwiftUI

struct StatusBadgeOverlay: View {
    let agents: [Agent]
    let selectedAgentId: UUID?

    var body: some View {
        // This is a placeholder overlay.
        // In a full implementation, we would use SCNSceneRenderer.projectPoint()
        // to convert 3D positions to 2D screen coordinates each frame.
        // For now, we show a legend in the corner.
        VStack(alignment: .leading, spacing: 4) {
            ForEach(agents) { agent in
                HStack(spacing: 6) {
                    StatusIndicator(status: agent.status, size: 8)
                    Text(agent.name)
                        .font(.system(size: 10, weight: selectedAgentId == agent.id ? .bold : .regular, design: .monospaced))
                        .foregroundColor(selectedAgentId == agent.id ? Color(hex: "#00BCD4") : .white.opacity(0.7))
                    Text("[\(agent.status.displayName)]")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: agent.status.hexColor))
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
        .padding(8)
    }
}
