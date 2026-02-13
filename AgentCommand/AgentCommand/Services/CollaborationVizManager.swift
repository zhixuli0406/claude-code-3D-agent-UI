import Foundation
import Combine

// MARK: - J2: Real-time Collaboration Visualization Manager

@MainActor
class CollaborationVizManager: ObservableObject {
    @Published var collaborationPaths: [AgentCollaborationPath] = []
    @Published var sharedResources: [SharedResourceAccess] = []
    @Published var taskHandoffs: [TaskHandoff] = []
    @Published var efficiencyMetrics: [TeamEfficiencyMetric] = []
    @Published var stats: CollaborationStats = CollaborationStats()
    @Published var isMonitoring: Bool = false

    // Memory optimization: cap collection sizes
    private static let maxPaths = 200
    private static let maxHandoffs = 100
    private static let maxSharedResources = 100

    private var monitorTimer: Timer?

    /// Back-reference to AppState for reading live agent/task data
    weak var appState: AppState?

    deinit {
        monitorTimer?.invalidate()
    }

    func startMonitoring() {
        isMonitoring = true
        refreshFromLiveData()
        // Poll every 5 seconds to refresh from live agent data
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromLiveData()
            }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    func recordCollaborationPath(from sourceId: UUID, to targetId: UUID, dataType: String) {
        // Increment transfer count if path already exists
        if let idx = collaborationPaths.firstIndex(where: {
            $0.sourceAgentId == sourceId && $0.targetAgentId == targetId && $0.dataType == dataType
        }) {
            collaborationPaths[idx].transferCount += 1
            collaborationPaths[idx].isActive = true
            collaborationPaths[idx].timestamp = Date()
        } else {
            let path = AgentCollaborationPath(
                id: UUID(),
                sourceAgentId: sourceId,
                targetAgentId: targetId,
                direction: .agentToAgent,
                dataType: dataType,
                transferCount: 1,
                timestamp: Date()
            )
            collaborationPaths.append(path)

            // Evict oldest inactive paths when exceeding cap
            if collaborationPaths.count > Self.maxPaths {
                collaborationPaths.removeAll { !$0.isActive && Date().timeIntervalSince($0.timestamp) > 60 }
            }
        }
        updateStats()
    }

    func recordSharedResourceAccess(path: String, agentId: UUID, type: ResourceAccessType) {
        if let idx = sharedResources.firstIndex(where: { $0.resourcePath == path }) {
            if !sharedResources[idx].accessingAgentIds.contains(agentId) {
                sharedResources[idx].accessingAgentIds.append(agentId)
            }
            sharedResources[idx].hasConflict = sharedResources[idx].accessingAgentIds.count > 1 && type == .write
            sharedResources[idx].lastAccessedAt = Date()
            sharedResources[idx].accessType = type
        } else {
            let resource = SharedResourceAccess(
                id: UUID(),
                resourcePath: path,
                accessingAgentIds: [agentId],
                hasConflict: false,
                lastAccessedAt: Date(),
                accessType: type
            )
            sharedResources.append(resource)

            // Evict stale resources (no access in last 5 min) when exceeding cap
            if sharedResources.count > Self.maxSharedResources {
                let cutoff = Date().addingTimeInterval(-300)
                sharedResources.removeAll { !$0.hasConflict && $0.lastAccessedAt < cutoff }
            }
        }
        updateStats()
    }

    func recordTaskHandoff(from: UUID, to: UUID, taskTitle: String, reason: String) {
        let handoff = TaskHandoff(
            id: UUID(),
            fromAgentId: from,
            toAgentId: to,
            taskTitle: taskTitle,
            handoffReason: reason,
            timestamp: Date(),
            isAnimating: true
        )
        taskHandoffs.append(handoff)

        // Evict oldest handoffs when exceeding cap
        if taskHandoffs.count > Self.maxHandoffs {
            taskHandoffs.removeFirst(taskHandoffs.count - Self.maxHandoffs)
        }

        // Stop animation after 3 seconds
        let handoffId = handoff.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if let idx = self?.taskHandoffs.firstIndex(where: { $0.id == handoffId }) {
                self?.taskHandoffs[idx].isAnimating = false
            }
        }
        updateStats()
    }

    // MARK: - Live Data Refresh

    /// Refresh collaboration data from live agent/task state
    private func refreshFromLiveData() {
        guard let appState = appState else { return }

        let agents = appState.agents
        let tasks = appState.tasks

        // Mark old paths as inactive based on age
        for i in collaborationPaths.indices {
            let age = Date().timeIntervalSince(collaborationPaths[i].timestamp)
            collaborationPaths[i].isActive = age < 30
        }

        // Build collaboration paths from agents sharing tasks (commander -> sub-agent)
        for agent in agents where agent.role == .commander {
            for subAgentId in agent.subAgentIds {
                recordCollaborationPath(from: agent.id, to: subAgentId, dataType: "Task Delegation")
            }
        }

        // Detect shared resource access from tasks assigned to different agents
        var fileAccessMap: [String: [UUID]] = [:]
        for task in tasks where task.status == .inProgress || task.status == .completed {
            if let agentId = task.assignedAgentId {
                let resourceKey = task.title
                fileAccessMap[resourceKey, default: []].append(agentId)
            }
        }
        for (resource, agentIds) in fileAccessMap where agentIds.count > 1 {
            let uniqueAgents = Array(Set(agentIds))
            if uniqueAgents.count > 1 {
                for agentId in uniqueAgents {
                    recordSharedResourceAccess(path: resource, agentId: agentId, type: .readWrite)
                }
            }
        }

        // Calculate real efficiency metrics based on task completion data
        updateEfficiencyMetrics(agents: agents, tasks: tasks)
        updateStats()
    }

    private func updateEfficiencyMetrics(agents: [Agent], tasks: [AgentTask]) {
        let completedTasks = tasks.filter { $0.status == .completed }
        let totalTasks = tasks.filter { $0.status != .pending }

        // Speed: ratio of completed tasks to total active tasks
        let speedValue = totalTasks.isEmpty ? 0.5 : min(1.0, Double(completedTasks.count) / max(1.0, Double(totalTasks.count)))

        // Quality: ratio of tasks without errors
        let failedTasks = tasks.filter { $0.status == .failed }
        let qualityValue = totalTasks.isEmpty ? 0.5 : 1.0 - (Double(failedTasks.count) / max(1.0, Double(totalTasks.count)))

        // Collaboration: ratio of agents actively working together (with sub-agents)
        let commanderCount = agents.filter { $0.role == .commander && !$0.subAgentIds.isEmpty }.count
        let collaborationValue = agents.isEmpty ? 0.5 : min(1.0, Double(commanderCount * 2) / max(1.0, Double(agents.count)))

        // Coverage: ratio of agents that have at least one assigned task
        let busyAgents = agents.filter { !$0.assignedTaskIds.isEmpty }.count
        let coverageValue = agents.isEmpty ? 0.5 : Double(busyAgents) / max(1.0, Double(agents.count))

        // Communication: based on collaboration paths activity
        let activePaths = collaborationPaths.filter { $0.isActive }.count
        let communicationValue = collaborationPaths.isEmpty ? 0.5 : min(1.0, Double(activePaths) / max(1.0, Double(collaborationPaths.count)))

        efficiencyMetrics = [
            TeamEfficiencyMetric(id: UUID(), dimension: "Speed", value: speedValue, label: "Speed"),
            TeamEfficiencyMetric(id: UUID(), dimension: "Quality", value: qualityValue, label: "Quality"),
            TeamEfficiencyMetric(id: UUID(), dimension: "Collaboration", value: collaborationValue, label: "Collaboration"),
            TeamEfficiencyMetric(id: UUID(), dimension: "Coverage", value: coverageValue, label: "Coverage"),
            TeamEfficiencyMetric(id: UUID(), dimension: "Communication", value: communicationValue, label: "Communication"),
        ]
    }

    private func updateStats() {
        stats.totalPaths = collaborationPaths.count
        stats.activeConflicts = sharedResources.filter { $0.hasConflict }.count
        stats.handoffCount = taskHandoffs.count
        stats.avgEfficiency = efficiencyMetrics.isEmpty ? 0 : efficiencyMetrics.map(\.value).reduce(0, +) / Double(efficiencyMetrics.count)
    }
}
