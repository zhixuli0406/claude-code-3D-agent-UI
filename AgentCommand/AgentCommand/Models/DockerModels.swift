import Foundation

// MARK: - I5: Docker / Dev Environment Models

enum ContainerStatus: String, CaseIterable {
    case running = "running"
    case stopped = "stopped"
    case paused = "paused"
    case restarting = "restarting"
    case creating = "creating"
    case removing = "removing"
    case exited = "exited"

    var hexColor: String {
        switch self {
        case .running: return "#4CAF50"
        case .stopped: return "#9E9E9E"
        case .paused: return "#FF9800"
        case .restarting: return "#2196F3"
        case .creating: return "#00BCD4"
        case .removing: return "#F44336"
        case .exited: return "#607D8B"
        }
    }

    var iconName: String {
        switch self {
        case .running: return "play.circle.fill"
        case .stopped: return "stop.circle.fill"
        case .paused: return "pause.circle.fill"
        case .restarting: return "arrow.clockwise.circle.fill"
        case .creating: return "plus.circle.fill"
        case .removing: return "minus.circle.fill"
        case .exited: return "xmark.circle"
        }
    }
}

struct DockerContainer: Identifiable {
    let id: UUID
    var containerId: String
    var name: String
    var image: String
    var status: ContainerStatus
    var ports: [PortMapping]
    var cpuUsage: Double // percentage
    var memoryUsage: Double // MB
    var memoryLimit: Double // MB
    var networkIn: Double // bytes
    var networkOut: Double // bytes
    var createdAt: Date
    var startedAt: Date?
    var uptime: TimeInterval?

    var memoryUsagePercent: Double {
        memoryLimit > 0 ? memoryUsage / memoryLimit : 0
    }
}

struct PortMapping {
    var hostPort: Int
    var containerPort: Int
    var protocol_: String // "tcp" or "udp"
}

struct DockerLogEntry: Identifiable {
    let id: UUID
    var timestamp: Date
    var message: String
    var stream: LogStream
    var containerId: String
}

enum LogStream: String {
    case stdout = "stdout"
    case stderr = "stderr"
}

struct DockerResourceSnapshot: Identifiable {
    let id: UUID
    var timestamp: Date
    var totalCPU: Double
    var totalMemory: Double
    var totalNetworkIn: Double
    var totalNetworkOut: Double
}

struct DockerStats {
    var totalContainers: Int = 0
    var runningContainers: Int = 0
    var stoppedContainers: Int = 0
    var totalCPU: Double = 0
    var totalMemory: Double = 0
    var totalNetworkIn: Double = 0
    var totalNetworkOut: Double = 0
}
