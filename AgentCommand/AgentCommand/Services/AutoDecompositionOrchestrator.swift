import Foundation
import Combine

// MARK: - Agent-to-Agent Auto-Decomposition Orchestrator

@MainActor
class AutoDecompositionOrchestrator: ObservableObject {

    @Published var activeOrchestrations: [UUID: OrchestrationState] = [:]  // keyed by commanderId

    /// Back-reference to AppState (set during init)
    weak var appState: AppState?

    // MARK: - Integrated Managers

    let concurrencyController = ConcurrencyController()
    let scheduler = TaskPriorityScheduler()
    let poolManager = SubAgentPoolManager()
    let monitor = SubAgentMonitor()

    /// Task queue manager for persistent, interruptible task execution
    weak var taskQueueManager: SubAgentTaskQueueManager?

    // MARK: - Init

    func configureManagers(lifecycleManager: AgentLifecycleManager?) {
        concurrencyController.lifecycleManager = lifecycleManager
        concurrencyController.cleanupManager = lifecycleManager?.cleanupManager
        poolManager.lifecycleManager = lifecycleManager
        monitor.lifecycleManager = lifecycleManager
        monitor.poolManager = poolManager
        monitor.concurrencyController = concurrencyController
        monitor.scheduler = scheduler

        // Wire concurrency controller callback to actually start sub-agent CLI
        concurrencyController.onStartSubAgent = { [weak self] commanderId, taskIndex, model in
            self?.doStartSubAgentCLI(commanderId: commanderId, taskIndex: taskIndex, model: model)
        }

        monitor.startMonitoring()
    }

    // MARK: - Public Entry Point

    /// Determine if the prompt should be auto-decomposed
    func shouldDecompose(prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count

        // Short prompts: don't decompose
        guard wordCount > 8 else { return false }

        // Check for multi-step indicator keywords
        let indicators = [
            // English
            "and then", "after that", "also", "additionally", "next",
            "first", "second", "third", "finally", "step",
            "refactor", "update", "add tests", "write tests",
            "fix", "implement", "create", "migrate",
            // Chinese
            "然後", "接著", "同時", "另外", "最後",
            "第一", "第二", "第三", "首先",
            "重構", "更新", "測試", "修復", "實作", "建立",
        ]

        let lowerPrompt = trimmed.lowercased()

        // Count how many indicators appear
        let matchCount = indicators.filter { lowerPrompt.contains($0.lowercased()) }.count
        if matchCount >= 2 { return true }

        // Check for comma/semicolon separated tasks
        let separators = trimmed.filter { $0 == "," || $0 == ";" || $0 == "、" }.count
        if separators >= 2 && wordCount > 12 { return true }

        // Check for numbered list patterns
        let numberedPattern = trimmed.range(of: #"\d+[\.\)]\s"#, options: .regularExpression) != nil
        if numberedPattern { return true }

        return false
    }

    /// Main entry point: submit a prompt with auto-decomposition
    func submitWithAutoDecomposition(prompt: String, model: ClaudeModel) {
        guard let appState = appState else { return }

        // Adjust concurrency based on current resource pressure
        if let lm = poolManager.lifecycleManager {
            let pressure = lm.cleanupManager.resourcePressure
            concurrencyController.adjustForPressure(pressure)
            poolManager.evaluateAndResize(resourcePressure: pressure)
        }

        // Create commander agent
        let commander = AgentFactory.createCommander(model: model)
        appState.agents.append(commander)
        appState.rebuildScene()

        // Walk commander to desk
        appState.sceneManager.walkAgentToDesk(commander.id) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.appState?.sceneManager.playWaveForAgent(commander.id)

                // Start decomposition after wave animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startDecompositionPhase(commanderId: commander.id, prompt: prompt, model: model)
                }
            }
        }
    }

    /// Cancel an active orchestration
    func cancelOrchestration(commanderId: UUID) {
        guard var state = activeOrchestrations[commanderId] else { return }
        state.phase = .failed
        state.completedAt = Date()
        activeOrchestrations[commanderId] = state

        // Cancel all running sub-agent CLI processes
        for subTask in state.subTasks where subTask.status == .inProgress {
            if let taskId = subTask.taskId {
                appState?.cliProcessManager.cancelProcess(taskId: taskId)
            }
            concurrencyController.taskCancelled(commanderId: commanderId, taskIndex: subTask.index)
        }

        // Clean up scheduler
        scheduler.removeOrchestration(commanderId: commanderId)

        // Release idle sub-agents back to pool
        releaseIdleSubAgents(commanderId: commanderId)
    }

    // MARK: - Phase 1: Decomposition

    private func startDecompositionPhase(commanderId: UUID, prompt: String, model: ClaudeModel) {
        guard let appState = appState else { return }

        var orchestration = OrchestrationState(commanderId: commanderId, originalPrompt: prompt)
        orchestration.phase = .decomposing
        activeOrchestrations[commanderId] = orchestration

        // Update commander status to working
        appState.handleAgentStatusChange(commanderId, to: .thinking)

        // Build decomposition prompt for Haiku CLI
        let decompositionPrompt = buildDecompositionPrompt(userPrompt: prompt)

        // Create a task for the decomposition step
        let taskId = UUID()
        let decompositionTask = AgentTask(
            id: taskId,
            title: "Decomposing: \(String(prompt.prefix(50)))",
            description: "Auto-decomposing user prompt into sub-tasks",
            status: .inProgress,
            priority: .medium,
            assignedAgentId: commanderId,
            subtasks: [],
            progress: 0,
            createdAt: Date(),
            estimatedDuration: 0,
            teamAgentIds: [commanderId],
            isRealExecution: true
        )
        appState.tasks.append(decompositionTask)

        if let idx = appState.agents.firstIndex(where: { $0.id == commanderId }) {
            appState.agents[idx].assignedTaskIds.append(taskId)
        }

        // Use Haiku for fast decomposition
        let workDir = appState.workspaceManager.activeDirectory
        let _ = appState.cliProcessManager.startProcess(
            taskId: taskId,
            agentId: commanderId,
            prompt: decompositionPrompt,
            workingDirectory: workDir,
            model: .haiku,
            onStatusChange: { [weak self] agentId, status in
                Task { @MainActor in
                    self?.appState?.handleAgentStatusChange(agentId, to: status)
                }
            },
            onProgress: { [weak self] taskId, progress in
                Task { @MainActor in
                    if let idx = self?.appState?.tasks.firstIndex(where: { $0.id == taskId }) {
                        self?.appState?.tasks[idx].progress = progress
                    }
                }
            },
            onCompleted: { [weak self] taskId, result in
                Task { @MainActor in
                    self?.handleDecompositionCompleted(commanderId: commanderId, taskId: taskId, result: result, originalPrompt: prompt, model: model)
                }
            },
            onFailed: { [weak self] taskId, error in
                Task { @MainActor in
                    self?.handleDecompositionFailed(commanderId: commanderId, taskId: taskId, error: error, originalPrompt: prompt, model: model)
                }
            },
            onDangerousCommand: { [weak self] taskId, agentId, tool, input, reason in
                Task { @MainActor in
                    self?.appState?.handleDangerousCommand(taskId: taskId, agentId: agentId, tool: tool, input: input, reason: reason)
                }
            },
            onAskUserQuestion: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.appState?.handleAskUserQuestion(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onPlanReview: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.appState?.handlePlanReview(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onOutput: { [weak self] agentId, entry in
                Task { @MainActor in
                    self?.appState?.handleCLIOutput(agentId: agentId, entry: entry)
                }
            }
        )
    }

    private func buildDecompositionPrompt(userPrompt: String) -> String {
        return """
        You are a task decomposition assistant. Analyze the following user request and break it down into independent sub-tasks that can be executed by separate AI agents.

        IMPORTANT: You must respond with ONLY a JSON object, no other text. Do not use markdown code fences.

        User request: \(userPrompt)

        Respond with this exact JSON structure:
        {"subtasks":[{"title":"short title","prompt":"detailed instruction for this sub-task","dependencies":[],"can_parallel":true,"estimated_complexity":"low"}]}

        Rules:
        - Maximum 6 subtasks
        - dependencies is an array of 0-based indices of tasks that must complete before this one
        - can_parallel: true if this task has no dependencies or its dependencies are the same as other tasks
        - estimated_complexity: "low", "medium", or "high"
        - Each prompt should be self-contained and specific
        - Respond with ONLY the JSON, nothing else
        """
    }

    // MARK: - Phase 1 Completion

    private func handleDecompositionCompleted(commanderId: UUID, taskId: UUID, result: String, originalPrompt: String, model: ClaudeModel) {
        guard let appState = appState else { return }

        // Mark decomposition task as completed
        if let idx = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[idx].status = .completed
            appState.tasks[idx].progress = 1.0
            appState.tasks[idx].completedAt = Date()
        }

        // Try to parse JSON from the result
        guard let decompositionResult = parseDecompositionResult(result) else {
            print("[Orchestrator] Failed to parse decomposition JSON, falling back")
            fallbackToDirectExecution(commanderId: commanderId, prompt: originalPrompt, model: model)
            return
        }

        let definitions = Array(decompositionResult.subtasks.prefix(6))

        // If only 1 or fewer subtasks, skip decomposition
        guard definitions.count > 1 else {
            print("[Orchestrator] Only \(definitions.count) subtask(s), falling back to direct execution")
            fallbackToDirectExecution(commanderId: commanderId, prompt: originalPrompt, model: model)
            return
        }

        // Update orchestration state
        guard var state = activeOrchestrations[commanderId] else { return }
        state.subTasks = definitions.enumerated().map { OrchestratedSubTask(index: $0.offset, definition: $0.element) }
        state.phase = .executing
        activeOrchestrations[commanderId] = state

        // Register sub-tasks with the priority scheduler
        scheduler.scheduleSubTasks(commanderId: commanderId, subTasks: state.subTasks)

        // Start demand-driven execution: only create agents for tasks that can run now
        executeNextBatch(commanderId: commanderId, model: model)
    }

    private func handleDecompositionFailed(commanderId: UUID, taskId: UUID, error: String, originalPrompt: String, model: ClaudeModel) {
        guard let appState = appState else { return }

        if let idx = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[idx].status = .failed
            appState.tasks[idx].cliResult = "Decomposition failed: \(error)"
        }

        print("[Orchestrator] Decomposition failed: \(error), falling back")
        fallbackToDirectExecution(commanderId: commanderId, prompt: originalPrompt, model: model)
    }

    private func parseDecompositionResult(_ rawResult: String) -> DecompositionResult? {
        // Try to find JSON in the result (may have surrounding text)
        let trimmed = rawResult.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct parse first
        if let data = trimmed.data(using: .utf8),
           let result = try? JSONDecoder().decode(DecompositionResult.self, from: data) {
            return result
        }

        // Try to extract JSON from markdown code block
        let patterns = [
            #"\{[\s\S]*"subtasks"[\s\S]*\}"#,
        ]

        for pattern in patterns {
            if let range = trimmed.range(of: pattern, options: .regularExpression) {
                let jsonStr = String(trimmed[range])
                if let data = jsonStr.data(using: .utf8),
                   let result = try? JSONDecoder().decode(DecompositionResult.self, from: data) {
                    return result
                }
            }
        }

        return nil
    }

    // MARK: - Phase 2: Demand-Driven Execution Engine

    /// Execute the next batch of ready tasks, creating sub-agents on-demand.
    /// Unlike the old approach that created all sub-agents upfront, this only
    /// creates agents when they have immediate work to do, preventing idle agents.
    private func executeNextBatch(commanderId: UUID, model: ClaudeModel) {
        guard var state = activeOrchestrations[commanderId] else { return }

        // Ask scheduler for the next batch of ready tasks
        let readyCount = scheduler.readyCount(commanderId: commanderId)

        // If nothing is ready and nothing is running, check if we're done
        if readyCount == 0 {
            let runningCount = concurrencyController.runningCount(for: commanderId)
            if runningCount == 0 {
                let allDone = state.subTasks.allSatisfy { $0.status == .completed || $0.status == .failed }
                if allDone {
                    // Release all idle sub-agents before synthesis
                    releaseIdleSubAgents(commanderId: commanderId)
                    startSynthesisPhase(commanderId: commanderId, model: model)
                }
            }
            return
        }

        // Calculate optimal wave size based on available concurrency slots
        let totalRemaining = state.subTasks.filter { $0.status == .pending || $0.status == .waiting }.count
        let waveSize = concurrencyController.optimalWaveSize(readyCount: readyCount, totalRemaining: totalRemaining)

        guard waveSize > 0 else { return }

        // Get the prioritized batch
        let batch = scheduler.nextBatch(commanderId: commanderId, maxSize: waveSize)

        state.currentWave += 1
        activeOrchestrations[commanderId] = state

        for item in batch {
            // Create sub-agent on-demand (try pool first)
            ensureSubAgentExists(commanderId: commanderId, taskIndex: item.taskIndex, model: model)

            // Infer priority from scheduler
            let priority = item.priority

            // Request start through concurrency controller
            // If the slot is available, it will call doStartSubAgentCLI immediately via callback
            // If not, it will be queued and started when a slot opens up
            concurrencyController.requestStart(
                commanderId: commanderId,
                taskIndex: item.taskIndex,
                model: model,
                priority: priority
            )
        }

        // Refresh monitor
        monitor.refresh()
    }

    /// Ensure a sub-agent exists for a given task index; create one on-demand if needed
    private func ensureSubAgentExists(commanderId: UUID, taskIndex: Int, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }
        guard taskIndex < state.subTasks.count else { return }

        // If agent already assigned, nothing to do
        if state.subTasks[taskIndex].agentId != nil { return }

        let roles: [AgentRole] = [.developer, .researcher, .reviewer, .tester, .designer]
        let role = roles[taskIndex % roles.count]

        // Try pool first, then factory
        let subAgent = poolManager.acquireOrCreate(role: role, parentId: commanderId, model: model)

        // Register sub-agent
        appState.agents.append(subAgent)
        if let cmdIdx = appState.agents.firstIndex(where: { $0.id == commanderId }) {
            appState.agents[cmdIdx].subAgentIds.append(subAgent.id)
        }

        state.subTasks[taskIndex].agentId = subAgent.id
        activeOrchestrations[commanderId] = state

        // Rebuild scene with new agent
        appState.rebuildScene()

        // Walk sub-agent to desk (non-blocking)
        appState.sceneManager.walkAgentToDesk(subAgent.id) { [weak appState] in
            Task { @MainActor in
                appState?.sceneManager.playWaveForAgent(subAgent.id)
            }
        }
    }

    /// Actually start a sub-agent CLI process (called by ConcurrencyController callback)
    private func doStartSubAgentCLI(commanderId: UUID, taskIndex: Int, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }
        guard taskIndex < state.subTasks.count else { return }

        let subTask = state.subTasks[taskIndex]
        guard let agentId = subTask.agentId else { return }

        // Skip if already completed (prevents re-execution on resume)
        if subTask.status == .completed {
            print("[Orchestrator] Skipping already-completed task \(taskIndex): \(subTask.title)")
            return
        }

        // Mark as in progress
        state.subTasks[taskIndex].status = .inProgress
        state.subTasks[taskIndex].startedAt = Date()
        activeOrchestrations[commanderId] = state

        // Mark in scheduler
        scheduler.markStarted(commanderId: commanderId, taskIndex: taskIndex)

        // Track in task queue for persistence
        let queueItem = SubAgentTaskQueueItem(
            id: UUID(),
            commanderId: commanderId,
            orchestrationTaskIndex: taskIndex,
            title: subTask.title,
            prompt: subTask.prompt,
            agentId: agentId,
            dependencies: subTask.dependencies,
            status: .inProgress,
            enqueuedAt: Date(),
            startedAt: Date()
        )
        taskQueueManager?.enqueue(queueItem)

        // Create a real task entry
        let taskId = UUID()
        let agentTask = AgentTask(
            id: taskId,
            title: subTask.title,
            description: subTask.prompt,
            status: .inProgress,
            priority: .medium,
            assignedAgentId: agentId,
            subtasks: [],
            progress: 0,
            createdAt: Date(),
            estimatedDuration: 0,
            teamAgentIds: [agentId],
            isRealExecution: true
        )
        appState.tasks.append(agentTask)

        if let idx = appState.agents.firstIndex(where: { $0.id == agentId }) {
            appState.agents[idx].assignedTaskIds.append(taskId)
        }

        // Update orchestration with taskId
        if var updatedState = activeOrchestrations[commanderId] {
            updatedState.subTasks[taskIndex].taskId = taskId
            activeOrchestrations[commanderId] = updatedState
        }

        appState.handleAgentStatusChange(agentId, to: .working)

        // Build sub-agent prompt with context from completed dependencies
        let enrichedPrompt = buildSubAgentPrompt(state: state, taskIndex: taskIndex)

        // Start CLI process
        let workDir = appState.workspaceManager.activeDirectory
        let _ = appState.cliProcessManager.startProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: enrichedPrompt,
            workingDirectory: workDir,
            model: model,
            onStatusChange: { [weak self] agentId, status in
                Task { @MainActor in
                    self?.appState?.handleAgentStatusChange(agentId, to: status)
                }
            },
            onProgress: { [weak self] taskId, progress in
                Task { @MainActor in
                    if let idx = self?.appState?.tasks.firstIndex(where: { $0.id == taskId }) {
                        self?.appState?.tasks[idx].progress = progress
                    }
                }
            },
            onCompleted: { [weak self] taskId, result in
                Task { @MainActor in
                    self?.handleSubAgentCompleted(commanderId: commanderId, taskIndex: taskIndex, taskId: taskId, result: result, model: model)
                }
            },
            onFailed: { [weak self] taskId, error in
                Task { @MainActor in
                    self?.handleSubAgentFailed(commanderId: commanderId, taskIndex: taskIndex, taskId: taskId, error: error, model: model)
                }
            },
            onDangerousCommand: { [weak self] taskId, agentId, tool, input, reason in
                Task { @MainActor in
                    self?.appState?.handleDangerousCommand(taskId: taskId, agentId: agentId, tool: tool, input: input, reason: reason)
                }
            },
            onAskUserQuestion: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.appState?.handleAskUserQuestion(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onPlanReview: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.appState?.handlePlanReview(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onOutput: { [weak self] agentId, entry in
                Task { @MainActor in
                    self?.appState?.handleCLIOutput(agentId: agentId, entry: entry)
                }
            }
        )
    }

    private func buildSubAgentPrompt(state: OrchestrationState, taskIndex: Int) -> String {
        let subTask = state.subTasks[taskIndex]
        var prompt = subTask.prompt

        // Add context from completed dependency results
        let completedDeps = subTask.dependencies.compactMap { depIdx -> (String, String)? in
            guard depIdx >= 0 && depIdx < state.subTasks.count,
                  let result = state.subTasks[depIdx].result else { return nil }
            return (state.subTasks[depIdx].title, String(result.prefix(500)))
        }

        if !completedDeps.isEmpty {
            prompt += "\n\nContext from previous steps:\n"
            for (title, result) in completedDeps {
                prompt += "- \(title): \(result)\n"
            }
        }

        return prompt
    }

    // MARK: - Sub-Agent Completion

    private func handleSubAgentCompleted(commanderId: UUID, taskIndex: Int, taskId: UUID, result: String, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }
        guard taskIndex < state.subTasks.count else { return }

        // Update sub-task state
        state.subTasks[taskIndex].status = .completed
        state.subTasks[taskIndex].result = result
        state.subTasks[taskIndex].completedAt = Date()
        activeOrchestrations[commanderId] = state

        // Update agent task
        if let idx = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[idx].status = .completed
            appState.tasks[idx].progress = 1.0
            appState.tasks[idx].completedAt = Date()
            appState.tasks[idx].cliResult = result
        }

        // Update agent status
        if let agentId = state.subTasks[taskIndex].agentId {
            appState.handleAgentStatusChange(agentId, to: .completed)
        }

        // Notify scheduler and concurrency controller
        scheduler.markCompleted(commanderId: commanderId, taskIndex: taskIndex)
        concurrencyController.taskCompleted(commanderId: commanderId, taskIndex: taskIndex)

        // Update task queue
        if let queueItem = taskQueueManager?.item(commanderId: commanderId, taskIndex: taskIndex) {
            taskQueueManager?.markCompleted(itemId: queueItem.id, commanderId: commanderId, result: result)
        }

        // Try to release the completed sub-agent back to pool if there are no more
        // tasks for it (prevents idle sub-agents waiting around)
        releaseCompletedSubAgentIfPossible(commanderId: commanderId, taskIndex: taskIndex)

        // Execute next batch of tasks
        executeNextBatch(commanderId: commanderId, model: model)
    }

    private func handleSubAgentFailed(commanderId: UUID, taskIndex: Int, taskId: UUID, error: String, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }
        guard taskIndex < state.subTasks.count else { return }

        // Update sub-task state
        state.subTasks[taskIndex].status = .failed
        state.subTasks[taskIndex].error = error
        state.subTasks[taskIndex].completedAt = Date()
        activeOrchestrations[commanderId] = state

        // Update agent task
        if let idx = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[idx].status = .failed
            appState.tasks[idx].cliResult = "Error: \(error)"
        }

        // Update agent status
        if let agentId = state.subTasks[taskIndex].agentId {
            appState.handleAgentStatusChange(agentId, to: .error)
        }

        // Notify scheduler and concurrency controller
        scheduler.markFailed(commanderId: commanderId, taskIndex: taskIndex)
        concurrencyController.taskCompleted(commanderId: commanderId, taskIndex: taskIndex)

        // Update task queue
        if let queueItem = taskQueueManager?.item(commanderId: commanderId, taskIndex: taskIndex) {
            taskQueueManager?.markFailed(itemId: queueItem.id, commanderId: commanderId, error: error)
        }

        // Continue with next batch
        executeNextBatch(commanderId: commanderId, model: model)
    }

    // MARK: - Sub-Agent Pool Release

    /// Release a completed sub-agent back to the pool if it has no more work
    private func releaseCompletedSubAgentIfPossible(commanderId: UUID, taskIndex: Int) {
        guard let state = activeOrchestrations[commanderId],
              taskIndex < state.subTasks.count,
              let agentId = state.subTasks[taskIndex].agentId,
              let agent = appState?.agents.first(where: { $0.id == agentId }) else { return }

        // Check if this agent has any pending tasks in the current orchestration
        let hasMoreWork = state.subTasks.contains { subTask in
            subTask.agentId == agentId &&
            (subTask.status == .pending || subTask.status == .inProgress || subTask.status == .waiting)
        }

        guard !hasMoreWork else { return }

        // Try to return to pool
        poolManager.release(agent)
    }

    /// Release all idle/completed sub-agents back to pool (called before synthesis or after cancel)
    private func releaseIdleSubAgents(commanderId: UUID) {
        guard let state = activeOrchestrations[commanderId] else { return }

        for subTask in state.subTasks {
            guard let agentId = subTask.agentId,
                  subTask.status == .completed || subTask.status == .failed,
                  let agent = appState?.agents.first(where: { $0.id == agentId }) else { continue }
            poolManager.release(agent)
        }
    }

    // MARK: - Phase 3: Synthesis

    private func startSynthesisPhase(commanderId: UUID, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }

        state.phase = .synthesizing
        activeOrchestrations[commanderId] = state

        appState.handleAgentStatusChange(commanderId, to: .working)

        // Build synthesis prompt
        let synthesisPrompt = buildSynthesisPrompt(state: state)

        let taskId = UUID()
        let synthesisTask = AgentTask(
            id: taskId,
            title: "Synthesizing results",
            description: "Commander aggregating all sub-agent results",
            status: .inProgress,
            priority: .medium,
            assignedAgentId: commanderId,
            subtasks: [],
            progress: 0,
            createdAt: Date(),
            estimatedDuration: 0,
            teamAgentIds: [commanderId],
            isRealExecution: true
        )
        appState.tasks.append(synthesisTask)

        if let idx = appState.agents.firstIndex(where: { $0.id == commanderId }) {
            appState.agents[idx].assignedTaskIds.append(taskId)
        }

        let workDir = appState.workspaceManager.activeDirectory
        let _ = appState.cliProcessManager.startProcess(
            taskId: taskId,
            agentId: commanderId,
            prompt: synthesisPrompt,
            workingDirectory: workDir,
            model: model,
            onStatusChange: { [weak self] agentId, status in
                Task { @MainActor in
                    self?.appState?.handleAgentStatusChange(agentId, to: status)
                }
            },
            onProgress: { [weak self] taskId, progress in
                Task { @MainActor in
                    if let idx = self?.appState?.tasks.firstIndex(where: { $0.id == taskId }) {
                        self?.appState?.tasks[idx].progress = progress
                    }
                }
            },
            onCompleted: { [weak self] taskId, result in
                Task { @MainActor in
                    self?.handleSynthesisCompleted(commanderId: commanderId, taskId: taskId, result: result)
                }
            },
            onFailed: { [weak self] taskId, error in
                Task { @MainActor in
                    self?.handleSynthesisFailed(commanderId: commanderId, taskId: taskId, error: error)
                }
            },
            onDangerousCommand: { [weak self] taskId, agentId, tool, input, reason in
                Task { @MainActor in
                    self?.appState?.handleDangerousCommand(taskId: taskId, agentId: agentId, tool: tool, input: input, reason: reason)
                }
            },
            onAskUserQuestion: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.appState?.handleAskUserQuestion(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onPlanReview: { [weak self] taskId, agentId, sessionId, inputJSON in
                Task { @MainActor in
                    self?.appState?.handlePlanReview(taskId: taskId, agentId: agentId, sessionId: sessionId, inputJSON: inputJSON)
                }
            },
            onOutput: { [weak self] agentId, entry in
                Task { @MainActor in
                    self?.appState?.handleCLIOutput(agentId: agentId, entry: entry)
                }
            }
        )
    }

    private func buildSynthesisPrompt(state: OrchestrationState) -> String {
        var prompt = """
        You are synthesizing the results of a multi-agent task execution.

        Original user request: \(state.originalPrompt)

        The following sub-tasks were executed by separate agents:

        """

        for subTask in state.subTasks {
            let statusStr = subTask.status == .completed ? "COMPLETED" : "FAILED"
            prompt += "## \(subTask.title) [\(statusStr)]\n"
            if let result = subTask.result {
                prompt += String(result.prefix(800))
            } else if let error = subTask.error {
                prompt += "Error: \(error)"
            }
            prompt += "\n\n"
        }

        prompt += """

        Please review all the results above and:
        1. Verify that the original request has been fully addressed
        2. Fix any remaining issues or inconsistencies between sub-tasks
        3. Provide a brief summary of what was accomplished
        """

        return prompt
    }

    // MARK: - Synthesis Completion

    private func handleSynthesisCompleted(commanderId: UUID, taskId: UUID, result: String) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }

        // Mark synthesis task completed
        if let idx = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[idx].status = .completed
            appState.tasks[idx].progress = 1.0
            appState.tasks[idx].completedAt = Date()
            appState.tasks[idx].cliResult = result
        }

        // Complete orchestration
        state.phase = .completed
        state.synthesisResult = result
        state.completedAt = Date()
        activeOrchestrations[commanderId] = state

        // Clean up scheduler and concurrency state
        scheduler.removeOrchestration(commanderId: commanderId)
        concurrencyController.reset()

        // Set commander to completed
        appState.handleAgentStatusChange(commanderId, to: .completed)

        // Schedule team disband
        appState.scheduleDisbandIfNeeded(commanderId: commanderId)

        // Refresh monitor
        monitor.refresh()
    }

    private func handleSynthesisFailed(commanderId: UUID, taskId: UUID, error: String) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }

        if let idx = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[idx].status = .failed
            appState.tasks[idx].cliResult = "Synthesis failed: \(error)"
        }

        // Mark orchestration as completed (with partial results)
        state.phase = .completed
        state.completedAt = Date()
        activeOrchestrations[commanderId] = state

        // Clean up
        scheduler.removeOrchestration(commanderId: commanderId)
        concurrencyController.reset()

        appState.handleAgentStatusChange(commanderId, to: .error)
        appState.scheduleDisbandIfNeeded(commanderId: commanderId)

        monitor.refresh()
    }

    // MARK: - Fallback

    /// Fall back to direct execution when decomposition fails or produces <=1 subtask
    private func fallbackToDirectExecution(commanderId: UUID, prompt: String, model: ClaudeModel) {
        guard let appState = appState else { return }

        // Remove orchestration state
        activeOrchestrations.removeValue(forKey: commanderId)

        // Create default sub-agents like normal team (try pool first)
        let subAgentCount = 2
        for _ in 0..<subAgentCount {
            let roles: [AgentRole] = [.developer, .researcher, .reviewer, .tester, .designer]
            let role = roles.randomElement() ?? .developer
            let subAgent = poolManager.acquireOrCreate(role: role, parentId: commanderId, model: model)
            appState.agents.append(subAgent)
            if let cmdIdx = appState.agents.firstIndex(where: { $0.id == commanderId }) {
                appState.agents[cmdIdx].subAgentIds.append(subAgent.id)
            }
        }

        appState.rebuildScene()

        // Walk sub-agents to desks
        let subAgentIds = appState.subAgents(of: commanderId).map(\.id)
        let walkGroup = DispatchGroup()
        for agentId in subAgentIds {
            walkGroup.enter()
            appState.sceneManager.walkAgentToDesk(agentId) {
                walkGroup.leave()
            }
        }

        walkGroup.notify(queue: .main) { [weak appState] in
            Task { @MainActor in
                appState?.submitPromptTask(title: prompt, assignTo: commanderId)
            }
        }
    }

}
