import Foundation
import Combine

// MARK: - L4: MCP (Model Context Protocol) Integration Manager

@MainActor
class MCPIntegrationManager: ObservableObject {
    @Published var servers: [MCPServer] = []
    @Published var recentCalls: [MCPToolCall] = []
    @Published var stats: MCPStats = MCPStats()
    @Published var isDiscovering: Bool = false

    private var pingTimer: Timer?

    deinit {
        pingTimer?.invalidate()
    }

    func addServer(name: String, url: String, description: String = "") {
        let server = MCPServer(
            id: UUID(),
            name: name,
            url: url,
            status: .disconnected,
            tools: [],
            version: "1.0",
            description: description,
            isAutoConnect: true
        )
        servers.append(server)
        connectServer(server.id)
        updateStats()
    }

    func removeServer(_ serverId: UUID) {
        disconnectServer(serverId)
        servers.removeAll { $0.id == serverId }
        updateStats()
    }

    /// Load MCP servers from Claude's configuration file
    func loadFromClaudeConfig() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let configPaths = [
                NSString("~/.claude/claude_desktop_config.json").expandingTildeInPath,
                NSString("~/.config/claude/claude_desktop_config.json").expandingTildeInPath,
            ]

            var loadedServers: [MCPServer] = []

            for path in configPaths {
                guard let data = FileManager.default.contents(atPath: path),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let mcpServers = json["mcpServers"] as? [String: [String: Any]] else { continue }

                for (name, config) in mcpServers {
                    let command = config["command"] as? String ?? ""
                    let args = config["args"] as? [String] ?? []
                    let url = command.isEmpty ? "stdio://\(name)" : "stdio://\(command) \(args.joined(separator: " "))"

                    let server = MCPServer(
                        id: UUID(),
                        name: name,
                        url: url,
                        status: .disconnected,
                        tools: [],
                        version: "1.0",
                        description: "Loaded from Claude config",
                        isAutoConnect: true
                    )
                    loadedServers.append(server)
                }

                if !loadedServers.isEmpty { break }
            }

            Task { @MainActor in
                guard let self = self else { return }
                if !loadedServers.isEmpty {
                    // Merge with existing servers (avoid duplicates by name)
                    let existingNames = Set(self.servers.map(\.name))
                    for server in loadedServers where !existingNames.contains(server.name) {
                        self.servers.append(server)
                    }
                    // Auto-connect servers that have autoConnect enabled
                    for server in self.servers where server.isAutoConnect && server.status == .disconnected {
                        self.connectServer(server.id)
                    }
                }
                self.updateStats()
            }
        }
    }

    func connectServer(_ serverId: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == serverId }) else { return }
        servers[index].status = .connecting

        // Attempt to verify server availability by checking if command exists
        let serverUrl = servers[index].url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Extract command from stdio:// URL
            let command = serverUrl.replacingOccurrences(of: "stdio://", with: "").components(separatedBy: " ").first ?? ""
            var isAvailable = true

            if !command.isEmpty && command != serverUrl {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = ["which", command]
                task.standardOutput = Pipe()
                task.standardError = Pipe()
                do {
                    try task.run()
                    task.waitUntilExit()
                    isAvailable = task.terminationStatus == 0
                } catch {
                    isAvailable = false
                }
            }

            Task { @MainActor in
                guard let self = self,
                      let idx = self.servers.firstIndex(where: { $0.id == serverId }) else { return }
                if isAvailable {
                    self.servers[idx].status = .connected
                    self.servers[idx].connectedAt = Date()
                    self.servers[idx].lastPingAt = Date()
                    self.discoverTools(serverId)
                } else {
                    self.servers[idx].status = .error
                }
                self.updateStats()
            }
        }
    }

    func disconnectServer(_ serverId: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == serverId }) else { return }
        servers[index].status = .disconnected
        updateStats()
    }

    func discoverTools(_ serverId: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == serverId }) else { return }
        isDiscovering = true

        // Infer tools from server name/URL
        let serverName = servers[index].name.lowercased()
        let serverUrl = servers[index].url.lowercased()
        let tools: [MCPTool]

        if serverName.contains("file") || serverName.contains("filesystem") || serverUrl.contains("filesystem") {
            tools = [
                MCPTool(id: UUID(), name: "read_file", description: "Read file contents", category: .fileSystem, callCount: 0, avgResponseTime: 0.1, isEnabled: true, serverId: serverId),
                MCPTool(id: UUID(), name: "write_file", description: "Write content to file", category: .fileSystem, callCount: 0, avgResponseTime: 0.15, isEnabled: true, serverId: serverId),
                MCPTool(id: UUID(), name: "list_directory", description: "List directory contents", category: .fileSystem, callCount: 0, avgResponseTime: 0.05, isEnabled: true, serverId: serverId),
            ]
        } else if serverName.contains("web") || serverName.contains("browser") || serverName.contains("puppeteer") || serverUrl.contains("puppeteer") {
            tools = [
                MCPTool(id: UUID(), name: "fetch_url", description: "Fetch webpage content", category: .webBrowser, callCount: 0, avgResponseTime: 1.2, isEnabled: true, serverId: serverId),
                MCPTool(id: UUID(), name: "screenshot", description: "Take page screenshot", category: .webBrowser, callCount: 0, avgResponseTime: 2.0, isEnabled: true, serverId: serverId),
            ]
        } else if serverName.contains("sqlite") || serverName.contains("postgres") || serverName.contains("database") || serverName.contains("db") {
            tools = [
                MCPTool(id: UUID(), name: "query", description: "Execute SQL query", category: .database, callCount: 0, avgResponseTime: 0.3, isEnabled: true, serverId: serverId),
                MCPTool(id: UUID(), name: "list_tables", description: "List database tables", category: .database, callCount: 0, avgResponseTime: 0.1, isEnabled: true, serverId: serverId),
            ]
        } else if serverName.contains("git") || serverUrl.contains("git") {
            tools = [
                MCPTool(id: UUID(), name: "git_status", description: "Show git status", category: .codeExecution, callCount: 0, avgResponseTime: 0.2, isEnabled: true, serverId: serverId),
                MCPTool(id: UUID(), name: "git_diff", description: "Show git diff", category: .codeExecution, callCount: 0, avgResponseTime: 0.3, isEnabled: true, serverId: serverId),
                MCPTool(id: UUID(), name: "git_log", description: "Show git log", category: .codeExecution, callCount: 0, avgResponseTime: 0.2, isEnabled: true, serverId: serverId),
            ]
        } else {
            tools = [
                MCPTool(id: UUID(), name: "execute", description: "Execute custom action", category: .custom, callCount: 0, avgResponseTime: 0.5, isEnabled: true, serverId: serverId),
            ]
        }

        servers[index].tools = tools
        isDiscovering = false
        updateStats()
    }

    func toggleTool(_ toolId: UUID, in serverId: UUID) {
        guard let serverIndex = servers.firstIndex(where: { $0.id == serverId }),
              let toolIndex = servers[serverIndex].tools.firstIndex(where: { $0.id == toolId }) else { return }
        servers[serverIndex].tools[toolIndex].isEnabled.toggle()
        updateStats()
    }

    func recordToolCall(toolId: UUID, toolName: String, serverName: String, input: String, output: String?, duration: TimeInterval, tokenCost: Int) {
        let call = MCPToolCall(
            id: UUID(),
            toolId: toolId,
            toolName: toolName,
            serverName: serverName,
            input: input,
            output: output,
            status: output != nil ? .connected : .error,
            calledAt: Date(),
            duration: duration,
            tokenCost: tokenCost
        )
        recentCalls.insert(call, at: 0)
        if recentCalls.count > 50 {
            recentCalls = Array(recentCalls.prefix(50))
        }

        // Update tool stats
        for serverIndex in servers.indices {
            if let toolIndex = servers[serverIndex].tools.firstIndex(where: { $0.id == toolId }) {
                servers[serverIndex].tools[toolIndex].callCount += 1
                servers[serverIndex].tools[toolIndex].lastCalledAt = Date()
                let oldAvg = servers[serverIndex].tools[toolIndex].avgResponseTime
                let count = Double(servers[serverIndex].tools[toolIndex].callCount)
                servers[serverIndex].tools[toolIndex].avgResponseTime = (oldAvg * (count - 1) + duration) / count
            }
        }
        updateStats()
    }

    func startPingLoop() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pingServers()
            }
        }
    }

    func stopPingLoop() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    func loadSampleData() {
        let fileServer = MCPServer(
            id: UUID(),
            name: "File System Server",
            url: "stdio://mcp-server-filesystem",
            status: .connected,
            tools: [
                MCPTool(id: UUID(), name: "read_file", description: "Read file contents", category: .fileSystem, callCount: 42, avgResponseTime: 0.08, lastCalledAt: Date().addingTimeInterval(-60), isEnabled: true, serverId: UUID()),
                MCPTool(id: UUID(), name: "write_file", description: "Write content to file", category: .fileSystem, callCount: 18, avgResponseTime: 0.12, lastCalledAt: Date().addingTimeInterval(-300), isEnabled: true, serverId: UUID()),
                MCPTool(id: UUID(), name: "list_directory", description: "List directory contents", category: .fileSystem, callCount: 35, avgResponseTime: 0.05, lastCalledAt: Date().addingTimeInterval(-120), isEnabled: true, serverId: UUID()),
            ],
            connectedAt: Date().addingTimeInterval(-3600),
            lastPingAt: Date(),
            version: "1.2.0",
            description: "Local file system access via MCP",
            isAutoConnect: true
        )

        let webServer = MCPServer(
            id: UUID(),
            name: "Web Browser Server",
            url: "stdio://mcp-server-puppeteer",
            status: .connected,
            tools: [
                MCPTool(id: UUID(), name: "fetch_url", description: "Fetch webpage content", category: .webBrowser, callCount: 15, avgResponseTime: 1.5, lastCalledAt: Date().addingTimeInterval(-600), isEnabled: true, serverId: UUID()),
                MCPTool(id: UUID(), name: "screenshot", description: "Take page screenshot", category: .webBrowser, callCount: 8, avgResponseTime: 2.3, lastCalledAt: Date().addingTimeInterval(-900), isEnabled: true, serverId: UUID()),
            ],
            connectedAt: Date().addingTimeInterval(-7200),
            lastPingAt: Date(),
            version: "1.0.3",
            description: "Web browsing and scraping via Puppeteer",
            isAutoConnect: false
        )

        let dbServer = MCPServer(
            id: UUID(),
            name: "SQLite Server",
            url: "stdio://mcp-server-sqlite",
            status: .disconnected,
            tools: [],
            version: "0.9.1",
            description: "SQLite database access",
            isAutoConnect: false
        )

        servers = [fileServer, webServer, dbServer]

        recentCalls = [
            MCPToolCall(id: UUID(), toolId: UUID(), toolName: "read_file", serverName: "File System Server", input: "src/main.swift", output: "// File contents...", status: .connected, calledAt: Date().addingTimeInterval(-60), duration: 0.08, tokenCost: 120),
            MCPToolCall(id: UUID(), toolId: UUID(), toolName: "fetch_url", serverName: "Web Browser Server", input: "https://docs.example.com/api", output: "API documentation...", status: .connected, calledAt: Date().addingTimeInterval(-300), duration: 1.2, tokenCost: 450),
            MCPToolCall(id: UUID(), toolId: UUID(), toolName: "list_directory", serverName: "File System Server", input: "src/", output: "[main.swift, utils.swift, ...]", status: .connected, calledAt: Date().addingTimeInterval(-600), duration: 0.04, tokenCost: 80),
        ]

        updateStats()
    }

    // MARK: - Private

    private func pingServers() {
        for index in servers.indices {
            if servers[index].status == .connected {
                servers[index].lastPingAt = Date()
            }
        }
    }

    private func updateStats() {
        stats.totalServers = servers.count
        stats.connectedServers = servers.filter { $0.status == .connected }.count
        stats.totalTools = servers.flatMap(\.tools).count
        stats.enabledTools = servers.flatMap(\.tools).filter(\.isEnabled).count
        stats.totalCalls = recentCalls.count

        let durations = recentCalls.compactMap(\.duration)
        stats.avgResponseTime = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        // Top tools
        let toolCounts = Dictionary(grouping: recentCalls, by: \.toolName).mapValues { $0.count }
        stats.topTools = toolCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}
