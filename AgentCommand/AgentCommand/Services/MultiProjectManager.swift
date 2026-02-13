import Foundation
import Combine

// MARK: - I4: Multi-Project Workspace Manager

@MainActor
class MultiProjectManager: ObservableObject {
    @Published var projects: [ProjectWorkspace] = []
    @Published var activeProjectId: UUID?
    @Published var crossProjectTasks: [CrossProjectTask] = []
    @Published var comparison: ProjectComparison?

    private let projectColors = ["#2196F3", "#4CAF50", "#FF9800", "#9C27B0", "#F44336", "#00BCD4", "#E91E63", "#607D8B"]

    func addProject(name: String, path: String) {
        let colorIndex = projects.count % projectColors.count
        let project = ProjectWorkspace(
            id: UUID(),
            name: name,
            path: path,
            isActive: projects.isEmpty,
            activeAgentCount: 0,
            totalTasks: 0,
            completedTasks: 0,
            failedTasks: 0,
            lastActivityAt: nil,
            iconColor: projectColors[colorIndex]
        )
        projects.append(project)
        if projects.count == 1 {
            activeProjectId = project.id
        }
    }

    func removeProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        if activeProjectId == id {
            activeProjectId = projects.first?.id
        }
    }

    func switchToProject(_ id: UUID) {
        for i in projects.indices {
            projects[i].isActive = (projects[i].id == id)
        }
        activeProjectId = id
    }

    func updateProjectStats(projectId: UUID, agentCount: Int, totalTasks: Int, completedTasks: Int, failedTasks: Int) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[idx].activeAgentCount = agentCount
        projects[idx].totalTasks = totalTasks
        projects[idx].completedTasks = completedTasks
        projects[idx].failedTasks = failedTasks
        projects[idx].lastActivityAt = Date()
    }

    func searchTasks(query: String) -> [CrossProjectTask] {
        let lowered = query.lowercased()
        return crossProjectTasks.filter {
            $0.taskTitle.lowercased().contains(lowered) ||
            $0.projectName.lowercased().contains(lowered) ||
            $0.agentName.lowercased().contains(lowered)
        }
    }

    /// Back-reference to AppState for reading live agent/task data
    weak var appState: AppState?

    func generateComparison() {
        guard let appState = appState else {
            // Fallback: generate comparison from stored project stats
            let metrics = projects.map { project in
                ProjectMetrics(
                    id: UUID(),
                    projectName: project.name,
                    totalTasks: project.totalTasks,
                    completedTasks: project.completedTasks,
                    avgDuration: project.totalTasks > 0 ? 120.0 : 0,
                    totalCost: 0,
                    tokenUsage: 0,
                    agentCount: project.activeAgentCount
                )
            }
            comparison = ProjectComparison(id: UUID(), projects: metrics)
            return
        }

        // Use real task data from AppState
        let metrics = projects.map { project in
            let projectTasks = appState.tasks.filter { task in
                task.assignedAgentId != nil
            }
            let completedDurations = projectTasks.compactMap { task -> TimeInterval? in
                guard task.status == .completed, let completedAt = task.completedAt else { return nil }
                return completedAt.timeIntervalSince(task.createdAt)
            }
            let avgDuration = completedDurations.isEmpty ? 0 : completedDurations.reduce(0, +) / Double(completedDurations.count)

            return ProjectMetrics(
                id: UUID(),
                projectName: project.name,
                totalTasks: project.totalTasks,
                completedTasks: project.completedTasks,
                avgDuration: avgDuration,
                totalCost: 0,
                tokenUsage: 0,
                agentCount: project.activeAgentCount
            )
        }
        comparison = ProjectComparison(id: UUID(), projects: metrics)
    }

    /// Scan a directory to detect project metadata (git info, file counts)
    func scanProjectDirectory(_ projectId: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let path = projects[idx].path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var fileCount = 0
            let fm = FileManager.default

            // Count files
            if let enumerator = fm.enumerator(atPath: path) {
                while enumerator.nextObject() != nil {
                    fileCount += 1
                }
            }

            // Check if it's a git repo
            let isGitRepo = fm.fileExists(atPath: (path as NSString).appendingPathComponent(".git"))

            Task { @MainActor in
                guard let self = self,
                      let idx = self.projects.firstIndex(where: { $0.id == projectId }) else { return }
                self.projects[idx].lastActivityAt = Date()
                // Use file count as a rough metric
                if self.projects[idx].totalTasks == 0 {
                    self.projects[idx].totalTasks = isGitRepo ? fileCount / 10 : 0
                }
            }
        }
    }

    func loadSampleProjects() {
        guard projects.isEmpty else { return }

        // Try to add current workspace directory as the first project
        if let appState = appState {
            let dir = appState.workspaceManager.activeDirectory
            let name = URL(fileURLWithPath: dir).lastPathComponent
            addProject(name: name, path: dir)
            scanProjectDirectory(projects[0].id)
        }
    }
}
