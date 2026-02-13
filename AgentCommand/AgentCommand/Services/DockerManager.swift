import Foundation
import Combine

// MARK: - I5: Docker / Dev Environment Manager

@MainActor
class DockerManager: ObservableObject {
    @Published var containers: [DockerContainer] = []
    @Published var logEntries: [DockerLogEntry] = []
    @Published var resourceHistory: [DockerResourceSnapshot] = []
    @Published var stats: DockerStats = DockerStats()
    @Published var isDockerAvailable: Bool = false
    @Published var isMonitoring: Bool = false

    private var monitorTimer: Timer?

    deinit {
        monitorTimer?.invalidate()
    }

    func checkDockerAvailability() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["docker", "info"]
            task.standardOutput = Pipe()
            task.standardError = Pipe()

            var available = false
            do {
                try task.run()
                task.waitUntilExit()
                available = task.terminationStatus == 0
            } catch {
                available = false
            }

            Task { @MainActor in
                self?.isDockerAvailable = available
                if available {
                    self?.refreshContainers()
                } else {
                    self?.loadSampleData()
                }
            }
        }
    }

    func startMonitoring() {
        isMonitoring = true
        refreshContainers()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshContainers()
            }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    func refreshContainers() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["docker", "ps", "-a", "--format", "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            var parsed: [DockerContainer] = []

            do {
                try task.run()
                task.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

                for line in lines {
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 4 else { continue }

                    let containerId = parts[0]
                    let name = parts[1]
                    let image = parts[2]
                    let statusStr = parts[3].lowercased()

                    let status: ContainerStatus
                    if statusStr.contains("up") { status = .running }
                    else if statusStr.contains("exited") { status = .exited }
                    else if statusStr.contains("paused") { status = .paused }
                    else if statusStr.contains("restarting") { status = .restarting }
                    else { status = .stopped }

                    parsed.append(DockerContainer(
                        id: UUID(),
                        containerId: String(containerId.prefix(12)),
                        name: name,
                        image: image,
                        status: status,
                        ports: [],
                        cpuUsage: 0,
                        memoryUsage: 0,
                        memoryLimit: 0,
                        networkIn: 0,
                        networkOut: 0,
                        createdAt: Date().addingTimeInterval(-86400),
                        startedAt: status == .running ? Date().addingTimeInterval(-3600) : nil,
                        uptime: status == .running ? 3600 : nil
                    ))
                }
            } catch {
                // Docker not available
            }

            // Fetch real resource stats for running containers
            let statsMap = Self.fetchDockerStats()

            Task { @MainActor in
                if parsed.isEmpty {
                    self?.loadSampleData()
                } else {
                    // Apply real stats to parsed containers
                    for i in parsed.indices {
                        if let stats = statsMap[parsed[i].containerId] ?? statsMap[parsed[i].name] {
                            parsed[i].cpuUsage = stats.cpu
                            parsed[i].memoryUsage = stats.memUsage
                            parsed[i].memoryLimit = stats.memLimit
                            parsed[i].networkIn = stats.netIn
                            parsed[i].networkOut = stats.netOut
                        }
                    }
                    self?.containers = parsed
                }
                self?.updateStats()
                self?.recordResourceSnapshot()
            }
        }
    }

    /// Fetch real resource stats via `docker stats --no-stream`
    private static func fetchDockerStats() -> [String: (cpu: Double, memUsage: Double, memLimit: Double, netIn: Double, netOut: Double)] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["docker", "stats", "--no-stream", "--format", "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return [:]
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var result: [String: (cpu: Double, memUsage: Double, memLimit: Double, netIn: Double, netOut: Double)] = [:]

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 4 else { continue }

            let name = parts[0]
            let cpuStr = parts[1].replacingOccurrences(of: "%", with: "")
            let cpu = Double(cpuStr) ?? 0

            // Parse memory: "123.4MiB / 1.952GiB"
            let memParts = parts[2].components(separatedBy: " / ")
            let memUsage = Self.parseMemoryValue(memParts.first ?? "0")
            let memLimit = Self.parseMemoryValue(memParts.count > 1 ? memParts[1] : "0")

            // Parse network: "1.23kB / 4.56kB"
            let netParts = parts[3].components(separatedBy: " / ")
            let netIn = Self.parseMemoryValue(netParts.first ?? "0")
            let netOut = Self.parseMemoryValue(netParts.count > 1 ? netParts[1] : "0")

            result[name] = (cpu, memUsage, memLimit, netIn, netOut)
        }

        return result
    }

    /// Parse Docker memory/network values like "123.4MiB", "1.952GiB", "4.56kB"
    private static func parseMemoryValue(_ str: String) -> Double {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("GiB") || trimmed.hasSuffix("GB") {
            let numStr = trimmed.replacingOccurrences(of: "GiB", with: "").replacingOccurrences(of: "GB", with: "")
            return (Double(numStr) ?? 0) * 1024
        } else if trimmed.hasSuffix("MiB") || trimmed.hasSuffix("MB") {
            let numStr = trimmed.replacingOccurrences(of: "MiB", with: "").replacingOccurrences(of: "MB", with: "")
            return Double(numStr) ?? 0
        } else if trimmed.hasSuffix("KiB") || trimmed.hasSuffix("kB") || trimmed.hasSuffix("KB") {
            let numStr = trimmed.replacingOccurrences(of: "KiB", with: "").replacingOccurrences(of: "kB", with: "").replacingOccurrences(of: "KB", with: "")
            return (Double(numStr) ?? 0) / 1024
        } else if trimmed.hasSuffix("B") {
            let numStr = trimmed.replacingOccurrences(of: "B", with: "")
            return (Double(numStr) ?? 0) / (1024 * 1024)
        }
        return Double(trimmed) ?? 0
    }

    func startContainer(_ containerId: String) {
        executeDockerCommand(["docker", "start", containerId])
    }

    func stopContainer(_ containerId: String) {
        executeDockerCommand(["docker", "stop", containerId])
    }

    func restartContainer(_ containerId: String) {
        executeDockerCommand(["docker", "restart", containerId])
    }

    func fetchLogs(containerId: String, tail: Int = 50) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["docker", "logs", "--tail", "\(tail)", "--timestamps", containerId]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

                Task { @MainActor in
                    self?.logEntries = lines.map { line in
                        DockerLogEntry(
                            id: UUID(),
                            timestamp: Date(),
                            message: line,
                            stream: .stdout,
                            containerId: containerId
                        )
                    }
                }
            } catch {
                // Ignore
            }
        }
    }

    private func executeDockerCommand(_ args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = args
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            try? task.run()
            task.waitUntilExit()

            Task { @MainActor in
                self.refreshContainers()
            }
        }
    }

    private func loadSampleData() {
        containers = [
            DockerContainer(id: UUID(), containerId: "a1b2c3d4e5f6", name: "app-backend", image: "node:18-alpine", status: .running, ports: [PortMapping(hostPort: 3000, containerPort: 3000, protocol_: "tcp")], cpuUsage: 8.5, memoryUsage: 256, memoryLimit: 512, networkIn: 45000, networkOut: 12000, createdAt: Date().addingTimeInterval(-172800), startedAt: Date().addingTimeInterval(-7200), uptime: 7200),
            DockerContainer(id: UUID(), containerId: "b2c3d4e5f6g7", name: "postgres-db", image: "postgres:15", status: .running, ports: [PortMapping(hostPort: 5432, containerPort: 5432, protocol_: "tcp")], cpuUsage: 2.1, memoryUsage: 128, memoryLimit: 1024, networkIn: 8000, networkOut: 15000, createdAt: Date().addingTimeInterval(-604800), startedAt: Date().addingTimeInterval(-86400), uptime: 86400),
            DockerContainer(id: UUID(), containerId: "c3d4e5f6g7h8", name: "redis-cache", image: "redis:7-alpine", status: .running, ports: [PortMapping(hostPort: 6379, containerPort: 6379, protocol_: "tcp")], cpuUsage: 0.5, memoryUsage: 32, memoryLimit: 256, networkIn: 2000, networkOut: 3000, createdAt: Date().addingTimeInterval(-604800), startedAt: Date().addingTimeInterval(-86400), uptime: 86400),
            DockerContainer(id: UUID(), containerId: "d4e5f6g7h8i9", name: "nginx-proxy", image: "nginx:latest", status: .stopped, ports: [], cpuUsage: 0, memoryUsage: 0, memoryLimit: 128, networkIn: 0, networkOut: 0, createdAt: Date().addingTimeInterval(-259200)),
            DockerContainer(id: UUID(), containerId: "e5f6g7h8i9j0", name: "test-runner", image: "python:3.11", status: .exited, ports: [], cpuUsage: 0, memoryUsage: 0, memoryLimit: 512, networkIn: 0, networkOut: 0, createdAt: Date().addingTimeInterval(-3600)),
        ]
    }

    private func updateStats() {
        stats.totalContainers = containers.count
        stats.runningContainers = containers.filter { $0.status == .running }.count
        stats.stoppedContainers = containers.filter { $0.status != .running }.count
        stats.totalCPU = containers.reduce(0) { $0 + $1.cpuUsage }
        stats.totalMemory = containers.reduce(0) { $0 + $1.memoryUsage }
        stats.totalNetworkIn = containers.reduce(0) { $0 + $1.networkIn }
        stats.totalNetworkOut = containers.reduce(0) { $0 + $1.networkOut }
    }

    private func recordResourceSnapshot() {
        let snapshot = DockerResourceSnapshot(
            id: UUID(),
            timestamp: Date(),
            totalCPU: stats.totalCPU,
            totalMemory: stats.totalMemory,
            totalNetworkIn: stats.totalNetworkIn,
            totalNetworkOut: stats.totalNetworkOut
        )
        resourceHistory.append(snapshot)
        // Keep last 60 snapshots (10 minutes at 10s interval)
        if resourceHistory.count > 60 {
            resourceHistory.removeFirst(resourceHistory.count - 60)
        }
    }
}
