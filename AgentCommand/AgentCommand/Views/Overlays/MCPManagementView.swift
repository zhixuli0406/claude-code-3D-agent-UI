import SwiftUI

// MARK: - L4: MCP Management Detail View (Sheet)

struct MCPManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var newServerName = ""
    @State private var newServerURL = ""
    @State private var newServerDesc = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#00BCD4").opacity(0.3))

            TabView(selection: $selectedTab) {
                serversTab.tag(0)
                toolsTab.tag(1)
                callHistoryTab.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if appState.mcpIntegrationManager.servers.isEmpty {
                appState.mcpIntegrationManager.loadSampleData()
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "network")
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.mcpIntegration))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.mcpServers)).tag(0)
                Text(localization.localized(.mcpTools)).tag(1)
                Text(localization.localized(.mcpCallHistory)).tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Servers

    private var serversTab: some View {
        VStack(spacing: 12) {
            addServerSection
            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.mcpIntegrationManager.servers) { server in
                        serverCard(server)
                    }
                }
                .padding()
            }
        }
    }

    private var addServerSection: some View {
        HStack(spacing: 8) {
            TextField(localization.localized(.mcpServerName), text: $newServerName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)

            TextField(localization.localized(.mcpServerURL), text: $newServerURL)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)

            Button(localization.localized(.mcpAddServer)) {
                guard !newServerName.isEmpty, !newServerURL.isEmpty else { return }
                appState.mcpIntegrationManager.addServer(
                    name: newServerName,
                    url: newServerURL,
                    description: newServerDesc
                )
                newServerName = ""
                newServerURL = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#00BCD4"))
            .disabled(newServerName.isEmpty || newServerURL.isEmpty)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func serverCard(_ server: MCPServer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: server.status.iconName)
                    .foregroundColor(Color(hex: server.status.hexColor))
                Text(server.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("v\(server.version)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

                if server.status == .connected {
                    Button(action: { appState.mcpIntegrationManager.disconnectServer(server.id) }) {
                        Text(localization.localized(.mcpDisconnect))
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: { appState.mcpIntegrationManager.connectServer(server.id) }) {
                        Text(localization.localized(.mcpConnect))
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#4CAF50"))
                }

                Button(action: { appState.mcpIntegrationManager.removeServer(server.id) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)
            }

            Text(server.url)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            if !server.tools.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(server.tools.count) tools")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    if let lastPing = server.lastPingAt {
                        Text("Last ping: \(lastPing, style: .relative)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: server.status.hexColor).opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Tools

    private var toolsTab: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(appState.mcpIntegrationManager.servers) { server in
                    if !server.tools.isEmpty {
                        Section(header: sectionHeader(server.name, status: server.status)) {
                            ForEach(server.tools) { tool in
                                toolRow(tool, serverId: server.id)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ name: String, status: MCPServerStatus) -> some View {
        HStack {
            Image(systemName: status.iconName)
                .foregroundColor(Color(hex: status.hexColor))
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func toolRow(_ tool: MCPTool, serverId: UUID) -> some View {
        HStack(spacing: 8) {
            Image(systemName: tool.category.iconName)
                .foregroundColor(Color(hex: "#00BCD4").opacity(0.7))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text(tool.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Text("\(tool.callCount)x")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(String(format: "%.0fms", tool.avgResponseTime * 1000))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Toggle("", isOn: Binding(
                get: { tool.isEnabled },
                set: { _ in appState.mcpIntegrationManager.toggleTool(tool.id, in: serverId) }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.7)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Call History

    private var callHistoryTab: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(appState.mcpIntegrationManager.recentCalls) { call in
                    HStack(spacing: 8) {
                        Image(systemName: call.status == .connected ? "checkmark.circle" : "xmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: call.status == .connected ? "#4CAF50" : "#F44336"))
                        Text(call.toolName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        Text(call.serverName)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        if let duration = call.duration {
                            Text(String(format: "%.0fms", duration * 1000))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Text("\(call.tokenCost) tk")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Text(call.calledAt, style: .relative)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.02)))
                }
            }
            .padding()
        }
    }
}
