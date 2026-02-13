import Foundation
import Combine

// MARK: - H2: Agent Memory System Manager

@MainActor
class AgentMemorySystemManager: ObservableObject {

    // MARK: - Published State

    @Published var memories: [AgentMemory] = []
    @Published var memoryStats: MemoryStats = .empty
    @Published var isProcessing: Bool = false
    @Published var searchResults: [AgentMemory] = []
    @Published var searchQuery: String = ""
    @Published var selectedAgentFilter: String?

    let dbManager = AgentMemoryDatabaseManager()

    // MARK: - Initialization

    func initialize() {
        dbManager.openDatabase()
        refreshFromDatabase()
    }

    func shutdown() {
        dbManager.closeDatabase()
    }

    // MARK: - Memory Recording

    /// Record a task completion as a memory
    func recordTaskCompletion(agentName: String, taskTitle: String, result: String, relatedFiles: [String] = []) {
        let summary = generateTaskSummary(taskTitle: taskTitle, result: result)
        let tags = extractTags(from: taskTitle + " " + result)

        let memory = AgentMemory(
            agentName: agentName,
            taskTitle: taskTitle,
            summary: summary,
            category: .taskSummary,
            relevanceScore: 1.0,
            relatedFilesPaths: relatedFiles,
            tags: tags
        )

        dbManager.insertMemory(memory)
        refreshFromDatabase()
    }

    /// Record an error pattern for future reference
    func recordErrorPattern(agentName: String, taskTitle: String, error: String) {
        let memory = AgentMemory(
            agentName: agentName,
            taskTitle: taskTitle,
            summary: "Error: \(String(error.prefix(500)))",
            category: .errorPattern,
            relevanceScore: 0.8,
            tags: extractTags(from: error)
        )

        dbManager.insertMemory(memory)
        refreshFromDatabase()
    }

    /// Record code knowledge (e.g., learned about a specific file or pattern)
    func recordCodeKnowledge(agentName: String, taskTitle: String, knowledge: String, relatedFiles: [String]) {
        let memory = AgentMemory(
            agentName: agentName,
            taskTitle: taskTitle,
            summary: knowledge,
            category: .codeKnowledge,
            relevanceScore: 0.9,
            relatedFilesPaths: relatedFiles,
            tags: extractTags(from: knowledge)
        )

        dbManager.insertMemory(memory)
        refreshFromDatabase()
    }

    /// Record project context (e.g., project structure, conventions)
    func recordProjectContext(agentName: String, context: String) {
        let memory = AgentMemory(
            agentName: agentName,
            taskTitle: "Project Context",
            summary: context,
            category: .projectContext,
            relevanceScore: 0.7,
            tags: extractTags(from: context)
        )

        dbManager.insertMemory(memory)
        refreshFromDatabase()
    }

    // MARK: - Memory Recall

    /// Recall relevant memories for a new task
    func recallForTask(agentName: String, taskPrompt: String) -> [AgentMemory] {
        return dbManager.recallRelevant(query: taskPrompt, agentName: agentName, limit: 5)
    }

    /// Format recalled memories for prompt context injection
    func getContextForPrompt(agentName: String, taskPrompt: String, maxMemories: Int = 3) -> String {
        let recalled = recallForTask(agentName: agentName, taskPrompt: taskPrompt)
        guard !recalled.isEmpty else { return "" }

        var context = "--- Agent Memory: Relevant Past Experiences ---\n"
        for (i, memory) in recalled.prefix(maxMemories).enumerated() {
            context += "\n[\(i + 1)] [\(memory.category.displayName)] \(memory.taskTitle)\n"
            context += "   \(memory.summary)\n"
            if !memory.relatedFilesPaths.isEmpty {
                context += "   Files: \(memory.relatedFilesPaths.prefix(3).joined(separator: ", "))\n"
            }
        }
        context += "--- End of Agent Memory ---\n"
        return context
    }

    // MARK: - Memory Sharing

    /// Share a specific memory between agents
    func shareMemory(memoryId: String, fromAgent: String, toAgent: String) {
        dbManager.shareMemory(from: fromAgent, to: toAgent, memoryId: memoryId)
    }

    /// Share all relevant memories between team members
    func shareTeamKnowledge(teamAgentNames: [String]) {
        guard teamAgentNames.count >= 2 else { return }

        for agentName in teamAgentNames {
            let agentMemories = dbManager.fetchMemories(forAgent: agentName, limit: 10)
            let projectMemories = agentMemories.filter { $0.category == .projectContext || $0.category == .codeKnowledge }

            for otherAgent in teamAgentNames where otherAgent != agentName {
                for memory in projectMemories.prefix(3) {
                    shareMemory(memoryId: memory.id, fromAgent: agentName, toAgent: otherAgent)
                }
            }
        }
    }

    // MARK: - Search

    func search(query: String) {
        searchQuery = query
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchResults = dbManager.search(query: query, agentName: selectedAgentFilter)
    }

    // MARK: - Memory Management

    func deleteMemory(id: String) {
        dbManager.deleteMemory(id: id)
        refreshFromDatabase()
    }

    func clearAllMemories() {
        dbManager.clearAll()
        refreshFromDatabase()
    }

    /// Get all unique agent names that have memories
    func agentNames() -> [String] {
        return dbManager.agentNames()
    }

    /// Get memories filtered by agent name
    func memoriesForAgent(_ agentName: String) -> [AgentMemory] {
        return dbManager.fetchMemories(forAgent: agentName)
    }

    // MARK: - Memory Priority

    /// Re-rank memories based on relevance and time decay
    func updateMemoryPriorities() {
        isProcessing = true

        // Fetch all memories and sort by decayed score
        let allMemories = dbManager.fetchAllMemories(limit: 1000)

        // Update is done at query time via decayedScore computed property
        // This method triggers a refresh for the UI
        memories = allMemories.sorted { $0.decayedScore > $1.decayedScore }

        isProcessing = false
    }

    // MARK: - Private Helpers

    private func refreshFromDatabase() {
        memories = dbManager.fetchAllMemories()
        memoryStats = dbManager.getStats()
    }

    /// Generate a concise summary from task title and result
    private func generateTaskSummary(taskTitle: String, result: String) -> String {
        let maxLength = 300
        let combined = "Task: \(taskTitle). Result: \(String(result.prefix(maxLength - taskTitle.count - 20)))"
        return String(combined.prefix(maxLength))
    }

    /// Extract tags from text for searchability
    private func extractTags(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && $0.count <= 30 }

        // Keep unique, meaningful words as tags (max 10)
        let stopWords: Set<String> = ["the", "and", "for", "are", "but", "not", "you", "all", "can", "her", "was", "one", "our", "out", "has", "have", "from", "with", "this", "that", "will", "been", "they", "then", "than", "each", "which", "their", "said"]
        var seen = Set<String>()
        return words.filter { word in
            guard !stopWords.contains(word), !seen.contains(word) else { return false }
            seen.insert(word)
            return true
        }.prefix(10).map { $0 }
    }
}
