import Foundation

/// Coordinates task delegation from parent agents to sub-agents
struct AgentCoordinator {

    /// Build connection pairs for visual rendering
    static func buildConnectionPairs(agents: [Agent]) -> [(parent: UUID, child: UUID)] {
        agents.compactMap { agent in
            guard let parentId = agent.parentAgentId else { return nil }
            return (parent: parentId, child: agent.id)
        }
    }

    /// Get all agents in the hierarchy under a given agent
    static func allDescendants(of agentId: UUID, in agents: [Agent]) -> [Agent] {
        let directChildren = agents.filter { $0.parentAgentId == agentId }
        var result = directChildren
        for child in directChildren {
            result.append(contentsOf: allDescendants(of: child.id, in: agents))
        }
        return result
    }

    /// Calculate aggregate progress for a parent agent based on sub-agents' tasks
    static func aggregateProgress(for agentId: UUID, agents: [Agent], tasks: [AgentTask]) -> Double {
        let descendants = allDescendants(of: agentId, in: agents)
        let allAgentIds = [agentId] + descendants.map(\.id)

        let relevantTasks = tasks.filter { task in
            guard let assignedId = task.assignedAgentId else { return false }
            return allAgentIds.contains(assignedId)
        }

        guard !relevantTasks.isEmpty else { return 0 }
        return relevantTasks.map(\.progress).reduce(0, +) / Double(relevantTasks.count)
    }
}
