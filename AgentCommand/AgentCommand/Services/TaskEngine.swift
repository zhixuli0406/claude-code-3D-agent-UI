import Foundation

/// Timer-based simulation engine that advances task progress
class TaskEngine {
    private var timer: Timer?
    private var taskStates: [UUID: TaskSimState] = [:]
    private var onStatusChange: ((UUID, AgentStatus) -> Void)?
    private var onTaskProgress: ((UUID, Double) -> Void)?

    private struct TaskSimState {
        let taskId: UUID
        let agentId: UUID?
        let estimatedDuration: TimeInterval
        var elapsed: TimeInterval = 0
        var isThinking = false
        var thinkingTimer: TimeInterval = 0
        var hasErrored = false
    }

    func startSimulation(
        agents: [Agent],
        tasks: [AgentTask],
        onStatusChange: @escaping (UUID, AgentStatus) -> Void,
        onTaskProgress: @escaping (UUID, Double) -> Void
    ) {
        self.onStatusChange = onStatusChange
        self.onTaskProgress = onTaskProgress

        // Initialize task simulation states
        taskStates.removeAll()
        for task in tasks where task.status != .completed {
            taskStates[task.id] = TaskSimState(
                taskId: task.id,
                agentId: task.assignedAgentId,
                estimatedDuration: task.estimatedDuration
            )
        }

        // Start timer on main thread
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick(deltaTime: 0.5)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func addTask(_ task: AgentTask) {
        taskStates[task.id] = TaskSimState(
            taskId: task.id,
            agentId: task.assignedAgentId,
            estimatedDuration: task.estimatedDuration
        )
    }

    private func tick(deltaTime: TimeInterval) {
        for taskId in taskStates.keys {
            guard var state = taskStates[taskId] else { continue }

            // Random thinking pause
            if state.isThinking {
                state.thinkingTimer -= deltaTime
                if state.thinkingTimer <= 0 {
                    state.isThinking = false
                    // Resume working
                    if let agentId = state.agentId {
                        onStatusChange?(agentId, .working)
                    }
                }
                taskStates[taskId] = state
                continue
            }

            // Random chance to enter thinking mode
            if Double.random(in: 0...1) < 0.05 {
                state.isThinking = true
                state.thinkingTimer = Double.random(in: 1.5...4.0)
                if let agentId = state.agentId {
                    onStatusChange?(agentId, .thinking)
                }
                taskStates[taskId] = state
                continue
            }

            // Small chance of temporary error
            if !state.hasErrored && Double.random(in: 0...1) < 0.01 {
                state.hasErrored = true
                if let agentId = state.agentId {
                    onStatusChange?(agentId, .error)
                }
                // Auto-recover after a short time
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard var s = self?.taskStates[taskId] else { return }
                    if let agentId = s.agentId {
                        self?.onStatusChange?(agentId, .working)
                    }
                    s.hasErrored = false
                    self?.taskStates[taskId] = s
                }
                taskStates[taskId] = state
                continue
            }

            // Advance progress
            state.elapsed += deltaTime
            let progress = min(state.elapsed / state.estimatedDuration, 1.0)
            onTaskProgress?(taskId, progress)

            if progress >= 1.0 {
                // Task completed
                taskStates.removeValue(forKey: taskId)
                if let agentId = state.agentId {
                    onStatusChange?(agentId, .completed)
                }
            } else {
                taskStates[taskId] = state
            }
        }
    }
}
