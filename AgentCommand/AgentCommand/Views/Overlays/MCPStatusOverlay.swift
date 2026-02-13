import SwiftUI

// MARK: - L4: MCP Integration Status Overlay (right-side floating panel)

struct MCPStatusOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#00BCD4").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#00BCD4").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "network")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.mcpIntegration))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text("\(appState.mcpIntegrationManager.stats.connectedServers)/\(appState.mcpIntegrationManager.stats.totalServers)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let stats = appState.mcpIntegrationManager.stats

            HStack {
                Text(localization.localized(.mcpServers))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.connectedServers) / \(stats.totalServers)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }

            HStack {
                Text(localization.localized(.mcpTools))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.enabledTools)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.mcpTotalCalls))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalCalls)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Server list
            ForEach(appState.mcpIntegrationManager.servers.prefix(3)) { server in
                serverRow(server)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func serverRow(_ server: MCPServer) -> some View {
        HStack(spacing: 4) {
            Image(systemName: server.status.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: server.status.hexColor))
            Text(server.name)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text("\(server.tools.count)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
