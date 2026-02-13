import Foundation
import Combine

// MARK: - Agent-to-Agent Auto-Decomposition Orchestrator

@MainActor
class AutoDecompositionOrchestrator: ObservableObject {

    @Published var activeOrchestrations: [UUID: OrchestrationState] = [:]  // keyed by commanderId

    /// Back-reference to AppState (set during init)
    weak var appState: AppState?

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
        }
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

        // Create sub-agents and execute
        createSubAgentsAndExecute(commanderId: commanderId, model: model)
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

    // MARK: - Phase 2: Create Sub-Agents & Execute

    private func createSubAgentsAndExecute(commanderId: UUID, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }

        let roles: [AgentRole] = [.developer, .researcher, .reviewer, .tester, .designer]

        // Create a sub-agent for each subtask
        for i in 0..<state.subTasks.count {
            let role = roles[i % roles.count]
            let subAgent = AgentFactory.createSubAgent(parentId: commanderId, role: role, model: model)

            // Register sub-agent
            appState.agents.append(subAgent)
            if let cmdIdx = appState.agents.firstIndex(where: { $0.id == commanderId }) {
                appState.agents[cmdIdx].subAgentIds.append(subAgent.id)
            }

            state.subTasks[i].agentId = subAgent.id
        }

        activeOrchestrations[commanderId] = state

        // Rebuild scene with new agents
        appState.rebuildScene()

        // Walk all sub-agents to their desks
        let subAgentIds = state.subTasks.compactMap(\.agentId)
        let walkGroup = DispatchGroup()

        for agentId in subAgentIds {
            walkGroup.enter()
            appState.sceneManager.walkAgentToDesk(agentId) {
                walkGroup.leave()
            }
        }

        walkGroup.notify(queue: .main) { [weak self] in
            Task { @MainActor in
                // Play wave animation
                for agentId in subAgentIds {
                    self?.appState?.sceneManager.playWaveForAgent(agentId)
                }

                // Start executing waves after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.executeNextWave(commanderId: commanderId, model: model)
                }
            }
        }
    }

    // MARK: - Phase 3: Wave Execution Engine

    private func executeNextWave(commanderId: UUID, model: ClaudeModel) {
        guard var state = activeOrchestrations[commanderId] else { return }

        // Find tasks whose dependencies are all satisfied
        var tasksToStart: [Int] = []

        for i in 0..<state.subTasks.count {
            guard state.subTasks[i].status == .pending else { continue }

            let depsCompleted = state.subTasks[i].dependencies.allSatisfy { depIdx in
                depIdx >= 0 && depIdx < state.subTasks.count &&
                state.subTasks[depIdx].status == .completed
            }

            if depsCompleted {
                tasksToStart.append(i)
            }
        }

        // If no tasks to start and none in progress, check if we're done
        if tasksToStart.isEmpty {
            let anyInProgress = state.subTasks.contains { $0.status == .inProgress }
            if !anyInProgress {
                // All waves done — start synthesis
                let allCompleted = state.subTasks.allSatisfy { $0.status == .completed || $0.status == .failed }
                if allCompleted {
                    startSynthesisPhase(commanderId: commanderId, model: model)
                }
            }
            return
        }

        state.currentWave += 1
        activeOrchestrations[commanderId] = state

        // Start CLI for each task in this wave
        for taskIndex in tasksToStart {
            startSubAgentCLI(commanderId: commanderId, taskIndex: taskIndex, model: model)
        }
    }

    private func startSubAgentCLI(commanderId: UUID, taskIndex: Int, model: ClaudeModel) {
        guard let appState = appState,
              var state = activeOrchestrations[commanderId] else { return }
        guard taskIndex < state.subTasks.count else { return }

        let subTask = state.subTasks[taskIndex]
        guard let agentId = subTask.agentId else { return }

        // Mark as in progress
        state.subTasks[taskIndex].status = .inProgress
        state.subTasks[taskIndex].startedAt = Date()
        activeOrchestrations[commanderId] = state

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

        // Try to execute next wave
        executeNextWave(commanderId: commanderId, model: model)
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

        // Continue with next wave (skip dependent tasks)
        executeNextWave(commanderId: commanderId, model: model)
    }

    // MARK: - Phase 4: Synthesis

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

        // Set commander to completed
        appState.handleAgentStatusChange(commanderId, to: .completed)

        // Schedule team disband
        appState.scheduleDisbandIfNeeded(commanderId: commanderId)
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

        appState.handleAgentStatusChange(commanderId, to: .error)
        appState.scheduleDisbandIfNeeded(commanderId: commanderId)
    }

    // MARK: - Fallback

    /// Fall back to direct execution when decomposition fails or produces <=1 subtask
    private func fallbackToDirectExecution(commanderId: UUID, prompt: String, model: ClaudeModel) {
        guard let appState = appState else { return }

        // Remove orchestration state
        activeOrchestrations.removeValue(forKey: commanderId)

        // Create default sub-agents like normal team
        let subAgentCount = 2
        for _ in 0..<subAgentCount {
            let roles: [AgentRole] = [.developer, .researcher, .reviewer, .tester, .designer]
            let role = roles.randomElement() ?? .developer
            let subAgent = AgentFactory.createSubAgent(parentId: commanderId, role: role, model: model)
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
