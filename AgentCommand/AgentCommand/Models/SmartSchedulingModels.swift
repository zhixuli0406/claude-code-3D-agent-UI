import Foundation

// MARK: - L2: Smart Scheduling System Models

enum SchedulePriority: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var hexColor: String {
        switch self {
        case .low: return "#4CAF50"
        case .medium: return "#2196F3"
        case .high: return "#FF9800"
        case .critical: return "#F44336"
        }
    }

    var weight: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

enum ScheduleStatus: String, CaseIterable {
    case pending = "pending"
    case scheduled = "scheduled"
    case running = "running"
    case completed = "completed"
    case skipped = "skipped"

    var hexColor: String {
        switch self {
        case .pending: return "#9E9E9E"
        case .scheduled: return "#2196F3"
        case .running: return "#FF9800"
        case .completed: return "#4CAF50"
        case .skipped: return "#607D8B"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .scheduled: return "calendar.badge.clock"
        case .running: return "arrow.clockwise"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "forward.fill"
        }
    }
}

struct ScheduledTask: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var priority: SchedulePriority
    var status: ScheduleStatus
    var scheduledAt: Date
    var estimatedDuration: TimeInterval
    var actualDuration: TimeInterval?
    var suggestedTime: Date?
    var assignedAgentName: String?
    var estimatedTokens: Int
    var isBatch: Bool
}

struct TimeSlot: Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date
    var isAvailable: Bool
    var reservedForTask: UUID?
    var utilizationPercent: Double
}

struct ScheduleOptimization {
    var originalOrder: [UUID]
    var optimizedOrder: [UUID]
    var estimatedTimeSaved: TimeInterval
    var reason: String
}

struct SchedulingStats {
    var totalScheduled: Int = 0
    var completedOnTime: Int = 0
    var avgWaitTime: TimeInterval = 0
    var avgAccuracy: Double = 0
    var peakHours: [Int] = []
    var resourceUtilization: Double = 0
}
