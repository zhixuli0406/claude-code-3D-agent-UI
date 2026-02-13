import Foundation

/// All possible lifecycle events that trigger state transitions
enum LifecycleEvent: String, Codable, CaseIterable {
    case create
    case resourcesLoaded
    case assignTask
    case aiReasoning
    case toolInvoked
    case permissionNeeded
    case permissionGranted
    case permissionDenied
    case questionAsked
    case answerReceived
    case planReady
    case planApproved
    case planRejected
    case processTerminated
    case taskCompleted
    case taskFailed
    case resume
    case cancel
    case retry
    case timeout
    case idleTimeout
    case poolReturn
    case poolEviction
    case assignNewTask
    case returnToPool
    case disbandScheduled
    case cleanupTriggered
    case animationComplete

    var displayName: String {
        switch self {
        case .create: return "Create"
        case .resourcesLoaded: return "Resources Loaded"
        case .assignTask: return "Assign Task"
        case .aiReasoning: return "AI Reasoning"
        case .toolInvoked: return "Tool Invoked"
        case .permissionNeeded: return "Permission Needed"
        case .permissionGranted: return "Permission Granted"
        case .permissionDenied: return "Permission Denied"
        case .questionAsked: return "Question Asked"
        case .answerReceived: return "Answer Received"
        case .planReady: return "Plan Ready"
        case .planApproved: return "Plan Approved"
        case .planRejected: return "Plan Rejected"
        case .processTerminated: return "Process Terminated"
        case .taskCompleted: return "Task Completed"
        case .taskFailed: return "Task Failed"
        case .resume: return "Resume"
        case .cancel: return "Cancel"
        case .retry: return "Retry"
        case .timeout: return "Timeout"
        case .idleTimeout: return "Idle Timeout"
        case .poolReturn: return "Pool Return"
        case .poolEviction: return "Pool Eviction"
        case .assignNewTask: return "Assign New Task"
        case .returnToPool: return "Return to Pool"
        case .disbandScheduled: return "Disband Scheduled"
        case .cleanupTriggered: return "Cleanup Triggered"
        case .animationComplete: return "Animation Complete"
        }
    }
}

/// Context passed to guard/action closures during state transitions
struct AgentLifecycleContext {
    let agentId: UUID
    let currentState: AgentLifecycleState
    let sessionId: String?
    let taskId: UUID?
    let poolCapacity: Int
    let currentPoolSize: Int
    let idleDuration: TimeInterval

    init(
        agentId: UUID,
        currentState: AgentLifecycleState,
        sessionId: String? = nil,
        taskId: UUID? = nil,
        poolCapacity: Int = 12,
        currentPoolSize: Int = 0,
        idleDuration: TimeInterval = 0
    ) {
        self.agentId = agentId
        self.currentState = currentState
        self.sessionId = sessionId
        self.taskId = taskId
        self.poolCapacity = poolCapacity
        self.currentPoolSize = currentPoolSize
        self.idleDuration = idleDuration
    }
}
