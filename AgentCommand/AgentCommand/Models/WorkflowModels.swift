import Foundation

// MARK: - L1: Workflow Automation Engine Models

enum WorkflowTriggerType: String, CaseIterable, Identifiable {
    case manual = "manual"
    case gitPush = "git_push"
    case fileChange = "file_change"
    case schedule = "schedule"
    case taskComplete = "task_complete"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .gitPush: return "Git Push"
        case .fileChange: return "File Change"
        case .schedule: return "Schedule"
        case .taskComplete: return "Task Complete"
        }
    }

    var iconName: String {
        switch self {
        case .manual: return "hand.tap"
        case .gitPush: return "arrow.triangle.branch"
        case .fileChange: return "doc.badge.ellipsis"
        case .schedule: return "clock"
        case .taskComplete: return "checkmark.circle"
        }
    }
}

enum WorkflowStepType: String, CaseIterable, Identifiable {
    case action = "action"
    case condition = "condition"
    case parallel = "parallel"
    case delay = "delay"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .action: return "Action"
        case .condition: return "Condition"
        case .parallel: return "Parallel"
        case .delay: return "Delay"
        }
    }

    var iconName: String {
        switch self {
        case .action: return "bolt.fill"
        case .condition: return "arrow.triangle.branch"
        case .parallel: return "arrow.triangle.swap"
        case .delay: return "timer"
        }
    }
}

enum WorkflowStatus: String, CaseIterable {
    case draft = "draft"
    case active = "active"
    case paused = "paused"
    case running = "running"
    case completed = "completed"
    case failed = "failed"

    var hexColor: String {
        switch self {
        case .draft: return "#9E9E9E"
        case .active: return "#4CAF50"
        case .paused: return "#FF9800"
        case .running: return "#2196F3"
        case .completed: return "#4CAF50"
        case .failed: return "#F44336"
        }
    }

    var iconName: String {
        switch self {
        case .draft: return "pencil"
        case .active: return "play.circle"
        case .paused: return "pause.circle"
        case .running: return "arrow.clockwise"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

struct WorkflowStep: Identifiable {
    let id: UUID
    var name: String
    var type: WorkflowStepType
    var action: String
    var conditionExpression: String?
    var trueBranchStepId: UUID?
    var falseBranchStepId: UUID?
    var nextStepId: UUID?
    var status: WorkflowStatus
    var output: String?
}

struct WorkflowTrigger: Identifiable {
    let id: UUID
    var type: WorkflowTriggerType
    var configuration: [String: String]
    var isEnabled: Bool
}

struct Workflow: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var trigger: WorkflowTrigger
    var steps: [WorkflowStep]
    var status: WorkflowStatus
    var createdAt: Date
    var lastRunAt: Date?
    var runCount: Int
    var isTemplate: Bool
}

struct WorkflowExecution: Identifiable {
    let id: UUID
    var workflowId: UUID
    var workflowName: String
    var status: WorkflowStatus
    var startedAt: Date
    var completedAt: Date?
    var currentStepIndex: Int
    var totalSteps: Int
    var logs: [String]
}

struct WorkflowStats {
    var totalWorkflows: Int = 0
    var activeWorkflows: Int = 0
    var totalExecutions: Int = 0
    var successRate: Double = 0
    var avgDuration: TimeInterval = 0
}
