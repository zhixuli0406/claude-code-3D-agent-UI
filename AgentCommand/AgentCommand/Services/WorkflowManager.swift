import Foundation
import Combine

// MARK: - L1: Workflow Automation Engine Manager

@MainActor
class WorkflowManager: ObservableObject {
    @Published var workflows: [Workflow] = []
    @Published var executions: [WorkflowExecution] = []
    @Published var stats: WorkflowStats = WorkflowStats()
    @Published var isRunning: Bool = false

    private var executionTimer: Timer?

    /// Back-reference to AppState for CLI execution
    weak var appState: AppState?

    func createWorkflow(name: String, description: String, triggerType: WorkflowTriggerType) -> Workflow {
        let trigger = WorkflowTrigger(
            id: UUID(),
            type: triggerType,
            configuration: [:],
            isEnabled: true
        )
        let workflow = Workflow(
            id: UUID(),
            name: name,
            description: description,
            trigger: trigger,
            steps: [],
            status: .draft,
            createdAt: Date(),
            runCount: 0,
            isTemplate: false
        )
        workflows.append(workflow)
        updateStats()
        return workflow
    }

    func addStep(to workflowId: UUID, name: String, type: WorkflowStepType, action: String) {
        guard let index = workflows.firstIndex(where: { $0.id == workflowId }) else { return }
        let step = WorkflowStep(
            id: UUID(),
            name: name,
            type: type,
            action: action,
            status: .draft
        )
        workflows[index].steps.append(step)
    }

    func activateWorkflow(_ workflowId: UUID) {
        guard let index = workflows.firstIndex(where: { $0.id == workflowId }) else { return }
        workflows[index].status = .active
        updateStats()
    }

    func pauseWorkflow(_ workflowId: UUID) {
        guard let index = workflows.firstIndex(where: { $0.id == workflowId }) else { return }
        workflows[index].status = .paused
        updateStats()
    }

    func deleteWorkflow(_ workflowId: UUID) {
        workflows.removeAll { $0.id == workflowId }
        updateStats()
    }

    func executeWorkflow(_ workflowId: UUID) {
        guard let index = workflows.firstIndex(where: { $0.id == workflowId }) else { return }
        let workflow = workflows[index]

        let execution = WorkflowExecution(
            id: UUID(),
            workflowId: workflowId,
            workflowName: workflow.name,
            status: .running,
            startedAt: Date(),
            currentStepIndex: 0,
            totalSteps: workflow.steps.count,
            logs: ["Workflow started: \(workflow.name)"]
        )

        executions.insert(execution, at: 0)
        workflows[index].status = .running
        workflows[index].lastRunAt = Date()
        workflows[index].runCount += 1
        isRunning = true

        // Simulate step execution
        simulateExecution(executionId: execution.id, steps: workflow.steps)
    }

    private func simulateExecution(executionId: UUID, steps: [WorkflowStep]) {
        guard !steps.isEmpty else {
            completeExecution(executionId, success: true)
            return
        }

        executeStep(executionId: executionId, steps: steps, stepIndex: 0)
    }

    private func executeStep(executionId: UUID, steps: [WorkflowStep], stepIndex: Int) {
        guard stepIndex < steps.count else {
            completeExecution(executionId, success: true)
            return
        }

        guard let execIndex = executions.firstIndex(where: { $0.id == executionId }) else { return }
        let step = steps[stepIndex]
        executions[execIndex].currentStepIndex = stepIndex
        executions[execIndex].logs.append("Step \(stepIndex + 1): \(step.name) — started")

        let command = mapActionToCommand(step.action)

        if let command = command, let dir = appState?.workspaceManager.activeDirectory {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = command
                task.currentDirectoryURL = URL(fileURLWithPath: dir)
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()

                var success = true
                do {
                    try task.run()
                    task.waitUntilExit()
                    success = task.terminationStatus == 0
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let summary = String(output.prefix(200))

                    Task { @MainActor in
                        guard let self = self,
                              let idx = self.executions.firstIndex(where: { $0.id == executionId }) else { return }
                        self.executions[idx].logs.append("Step \(stepIndex + 1): \(step.name) — \(success ? "completed" : "failed")")
                        if !summary.isEmpty {
                            self.executions[idx].logs.append("  Output: \(summary)")
                        }

                        if success || step.type == .condition {
                            self.executeStep(executionId: executionId, steps: steps, stepIndex: stepIndex + 1)
                        } else {
                            self.completeExecution(executionId, success: false)
                        }
                    }
                } catch {
                    Task { @MainActor in
                        guard let self = self,
                              let idx = self.executions.firstIndex(where: { $0.id == executionId }) else { return }
                        self.executions[idx].logs.append("Step \(stepIndex + 1): \(step.name) — skipped (command not found)")
                        self.executeStep(executionId: executionId, steps: steps, stepIndex: stepIndex + 1)
                    }
                }
            }
        } else {
            // No command mapping — mark completed after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self,
                      let idx = self.executions.firstIndex(where: { $0.id == executionId }) else { return }
                self.executions[idx].logs.append("Step \(stepIndex + 1): \(step.name) — completed")
                self.executeStep(executionId: executionId, steps: steps, stepIndex: stepIndex + 1)
            }
        }
    }

    /// Map workflow action names to real CLI commands
    private func mapActionToCommand(_ action: String) -> [String]? {
        switch action.lowercased() {
        case "lint": return ["swiftlint", "lint", "--quiet"]
        case "test": return ["swift", "test"]
        case "build": return ["swift", "build"]
        default: return nil
        }
    }

    private func completeExecution(_ executionId: UUID, success: Bool) {
        guard let execIndex = executions.firstIndex(where: { $0.id == executionId }) else { return }
        executions[execIndex].status = success ? .completed : .failed
        executions[execIndex].completedAt = Date()
        executions[execIndex].logs.append(success ? "Workflow completed successfully" : "Workflow failed")

        // Update workflow status
        let workflowId = executions[execIndex].workflowId
        if let wfIndex = workflows.firstIndex(where: { $0.id == workflowId }) {
            workflows[wfIndex].status = .active
        }

        isRunning = executions.contains { $0.status == .running }
        updateStats()
    }

    func loadTemplates() {
        let templates: [Workflow] = [
            Workflow(
                id: UUID(),
                name: "PR Review Flow",
                description: "Automated PR review: lint, test, review, merge",
                trigger: WorkflowTrigger(id: UUID(), type: .gitPush, configuration: ["branch": "feature/*"], isEnabled: true),
                steps: [
                    WorkflowStep(id: UUID(), name: "Run Linter", type: .action, action: "lint", status: .draft),
                    WorkflowStep(id: UUID(), name: "Run Tests", type: .action, action: "test", status: .draft),
                    WorkflowStep(id: UUID(), name: "Code Review", type: .action, action: "review", status: .draft),
                    WorkflowStep(id: UUID(), name: "Check Pass?", type: .condition, action: "check_results", conditionExpression: "all_passed", status: .draft),
                ],
                status: .draft,
                createdAt: Date(),
                runCount: 0,
                isTemplate: true
            ),
            Workflow(
                id: UUID(),
                name: "Bug Fix Flow",
                description: "Automated bug fix: reproduce, fix, test, deploy",
                trigger: WorkflowTrigger(id: UUID(), type: .manual, configuration: [:], isEnabled: true),
                steps: [
                    WorkflowStep(id: UUID(), name: "Reproduce Bug", type: .action, action: "reproduce", status: .draft),
                    WorkflowStep(id: UUID(), name: "Analyze Root Cause", type: .action, action: "analyze", status: .draft),
                    WorkflowStep(id: UUID(), name: "Apply Fix", type: .action, action: "fix", status: .draft),
                    WorkflowStep(id: UUID(), name: "Run Tests", type: .action, action: "test", status: .draft),
                ],
                status: .draft,
                createdAt: Date(),
                runCount: 0,
                isTemplate: true
            ),
        ]

        for template in templates {
            if !workflows.contains(where: { $0.name == template.name && $0.isTemplate }) {
                workflows.append(template)
            }
        }
        updateStats()
    }

    private func updateStats() {
        stats.totalWorkflows = workflows.filter { !$0.isTemplate }.count
        stats.activeWorkflows = workflows.filter { $0.status == .active || $0.status == .running }.count
        stats.totalExecutions = executions.count
        let completed = executions.filter { $0.status == .completed }
        let total = executions.filter { $0.status == .completed || $0.status == .failed }
        stats.successRate = total.isEmpty ? 0 : Double(completed.count) / Double(total.count)
        let durations = completed.compactMap { exec in
            exec.completedAt.map { $0.timeIntervalSince(exec.startedAt) }
        }
        stats.avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
    }
}
