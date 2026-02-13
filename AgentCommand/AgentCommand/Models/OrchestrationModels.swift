import Foundation

// MARK: - Agent-to-Agent Auto-Decomposition Orchestration Models

/// Tracks the full state of one auto-decomposition execution
struct OrchestrationState: Identifiable {
    let id: UUID
    let commanderId: UUID
    let originalPrompt: String
    var phase: OrchestrationPhase
    var subTasks: [OrchestratedSubTask]
    var currentWave: Int
    var synthesisResult: String?
    var createdAt: Date
    var completedAt: Date?

    init(commanderId: UUID, originalPrompt: String) {
        self.id = UUID()
        self.commanderId = commanderId
        self.originalPrompt = originalPrompt
        self.phase = .decomposing
        self.subTasks = []
        self.currentWave = 0
        self.synthesisResult = nil
        self.createdAt = Date()
        self.completedAt = nil
    }

    var completedCount: Int {
        subTasks.filter { $0.status == .completed }.count
    }

    var failedCount: Int {
        subTasks.filter { $0.status == .failed }.count
    }

    var progress: Double {
        guard !subTasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(subTasks.count)
    }

    var isFinished: Bool {
        phase == .completed || phase == .failed
    }
}

/// Phase of the orchestration lifecycle
enum OrchestrationPhase: String {
    case decomposing   // Commander is using Haiku CLI to split the prompt
    case executing     // Sub-agents are running their tasks in waves
    case synthesizing  // Commander is aggregating all results
    case completed     // Everything done successfully
    case failed        // Orchestration failed (fallback triggered)
}

/// Tracks a single sub-task within an orchestration
struct OrchestratedSubTask: Identifiable {
    let id: UUID
    let index: Int
    var title: String
    var prompt: String
    var dependencies: [Int]  // Indices of tasks this depends on
    var canParallel: Bool
    var estimatedComplexity: String
    var status: OrchestratedSubTaskStatus
    var agentId: UUID?
    var taskId: UUID?
    var result: String?
    var error: String?
    var startedAt: Date?
    var completedAt: Date?

    /// Which wave this task belongs to (computed from dependencies)
    var wave: Int {
        if dependencies.isEmpty { return 0 }
        return -1  // Will be computed by orchestrator
    }

    init(index: Int, definition: SubtaskDefinition) {
        self.id = UUID()
        self.index = index
        self.title = definition.title
        self.prompt = definition.prompt
        self.dependencies = definition.dependencies
        self.canParallel = definition.canParallel
        self.estimatedComplexity = definition.estimatedComplexity
        self.status = .pending
    }
}

/// Status of an orchestrated sub-task
enum OrchestratedSubTaskStatus: String {
    case pending     // Not yet started
    case waiting     // Dependencies not met
    case inProgress  // CLI running
    case completed   // Done successfully
    case failed      // CLI failed
}

// MARK: - CLI Decomposition JSON Structures

/// The JSON structure returned by Haiku CLI decomposition
struct DecompositionResult: Codable {
    let subtasks: [SubtaskDefinition]
}

/// A single subtask definition from CLI decomposition
struct SubtaskDefinition: Codable {
    let title: String
    let prompt: String
    let dependencies: [Int]
    let canParallel: Bool
    let estimatedComplexity: String

    enum CodingKeys: String, CodingKey {
        case title, prompt, dependencies
        case canParallel = "can_parallel"
        case estimatedComplexity = "estimated_complexity"
    }
}
