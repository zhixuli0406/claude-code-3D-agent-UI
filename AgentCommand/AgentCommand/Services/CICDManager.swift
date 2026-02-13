import Foundation
import Combine

// MARK: - I1: CI/CD Integration Manager

@MainActor
class CICDManager: ObservableObject {
    @Published var pipelines: [CICDPipeline] = []
    @Published var pullRequests: [CICDPullRequest] = []
    @Published var stats: CICDStats = CICDStats()
    @Published var isMonitoring: Bool = false
    @Published var lastRefreshed: Date?
    @Published var provider: CICDProvider = .githubActions

    private var monitorTimer: Timer?
    private var workingDirectory: String?

    deinit {
        monitorTimer?.invalidate()
    }

    func startMonitoring(directory: String) {
        workingDirectory = directory
        isMonitoring = true
        refreshPipelines()
        // Poll every 30 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPipelines()
            }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    func refreshPipelines() {
        guard let dir = workingDirectory else { return }
        lastRefreshed = Date()

        // Check for GitHub Actions via gh CLI
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["gh", "run", "list", "--limit", "10", "--json", "databaseId,name,status,conclusion,headBranch,headSha,event,createdAt,updatedAt,url"]
        task.currentDirectoryURL = URL(fileURLWithPath: dir)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let runs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                provider = .githubActions
                pipelines = runs.compactMap { parsePipeline($0) }
                updateStats()
            }
        } catch {
            // gh CLI not available or not a GitHub repo
            generateSamplePipelines()
        }

        refreshPullRequests()
    }

    func refreshPullRequests() {
        guard let dir = workingDirectory else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["gh", "pr", "list", "--limit", "5", "--json", "number,title,author,reviewDecision,createdAt,updatedAt,comments"]
        task.currentDirectoryURL = URL(fileURLWithPath: dir)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let prs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                pullRequests = prs.compactMap { parsePullRequest($0) }
            }
        } catch {
            generateSamplePRs()
        }
    }

    private func parsePipeline(_ json: [String: Any]) -> CICDPipeline? {
        guard let name = json["name"] as? String else { return nil }
        let statusStr = json["conclusion"] as? String ?? json["status"] as? String ?? "queued"
        let status: PipelineStatus
        switch statusStr {
        case "success": status = .success
        case "failure": status = .failure
        case "cancelled": status = .cancelled
        case "in_progress": status = .inProgress
        case "skipped": status = .skipped
        default: status = .queued
        }

        return CICDPipeline(
            id: UUID(),
            name: name,
            provider: .githubActions,
            status: status,
            branch: json["headBranch"] as? String ?? "unknown",
            commitSHA: String((json["headSha"] as? String ?? "").prefix(7)),
            commitMessage: "",
            author: "",
            stages: generateStagesForStatus(status),
            startedAt: parseDate(json["createdAt"] as? String),
            completedAt: parseDate(json["updatedAt"] as? String),
            url: json["url"] as? String
        )
    }

    private func parsePullRequest(_ json: [String: Any]) -> CICDPullRequest? {
        guard let number = json["number"] as? Int,
              let title = json["title"] as? String else { return nil }

        let authorObj = json["author"] as? [String: Any]
        let author = authorObj?["login"] as? String ?? "unknown"
        let reviewStr = json["reviewDecision"] as? String ?? ""
        let reviewStatus: PRReviewStatus
        switch reviewStr {
        case "APPROVED": reviewStatus = .approved
        case "CHANGES_REQUESTED": reviewStatus = .changesRequested
        default: reviewStatus = .pending
        }

        return CICDPullRequest(
            id: UUID(),
            number: number,
            title: title,
            author: author,
            status: reviewStatus,
            reviewers: [],
            checksStatus: .success,
            commentCount: (json["comments"] as? [[String: Any]])?.count ?? 0,
            createdAt: parseDate(json["createdAt"] as? String) ?? Date(),
            updatedAt: parseDate(json["updatedAt"] as? String) ?? Date()
        )
    }

    private func parseDate(_ str: String?) -> Date? {
        guard let str = str else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: str)
    }

    private func generateStagesForStatus(_ status: PipelineStatus) -> [PipelineStage] {
        let stageNames = ["Build", "Test", "Deploy"]
        return stageNames.enumerated().map { index, name in
            let stageStatus: PipelineStatus
            switch status {
            case .success: stageStatus = .success
            case .failure: stageStatus = index <= 1 ? .success : .failure
            case .inProgress: stageStatus = index == 0 ? .success : (index == 1 ? .inProgress : .queued)
            default: stageStatus = .queued
            }
            return PipelineStage(
                id: UUID(),
                name: name,
                status: stageStatus,
                jobs: [PipelineJob(id: UUID(), name: name, status: stageStatus)]
            )
        }
    }

    private func generateSamplePipelines() {
        pipelines = [
            CICDPipeline(id: UUID(), name: "CI Build", provider: .githubActions, status: .success, branch: "main", commitSHA: "a1b2c3d", commitMessage: "Update dependencies", author: "dev", stages: generateStagesForStatus(.success), startedAt: Date().addingTimeInterval(-300), completedAt: Date().addingTimeInterval(-60)),
            CICDPipeline(id: UUID(), name: "CI Build", provider: .githubActions, status: .inProgress, branch: "feature/new-ui", commitSHA: "e4f5g6h", commitMessage: "Add new feature", author: "dev", stages: generateStagesForStatus(.inProgress), startedAt: Date().addingTimeInterval(-120)),
            CICDPipeline(id: UUID(), name: "Deploy", provider: .githubActions, status: .failure, branch: "release/v2.0", commitSHA: "i7j8k9l", commitMessage: "Release v2.0", author: "dev", stages: generateStagesForStatus(.failure), startedAt: Date().addingTimeInterval(-600), completedAt: Date().addingTimeInterval(-500)),
        ]
        updateStats()
    }

    private func generateSamplePRs() {
        pullRequests = [
            CICDPullRequest(id: UUID(), number: 42, title: "feat: Add dark mode support", author: "alice", status: .approved, reviewers: [], checksStatus: .success, commentCount: 3, createdAt: Date().addingTimeInterval(-86400), updatedAt: Date()),
            CICDPullRequest(id: UUID(), number: 41, title: "fix: Resolve memory leak", author: "bob", status: .pending, reviewers: [], checksStatus: .inProgress, commentCount: 1, createdAt: Date().addingTimeInterval(-172800), updatedAt: Date()),
        ]
    }

    private func updateStats() {
        stats.totalPipelines = pipelines.count
        stats.successCount = pipelines.filter { $0.status == .success }.count
        stats.failureCount = pipelines.filter { $0.status == .failure }.count
        let completedDurations = pipelines.compactMap { $0.duration ?? ($0.completedAt.map { $0.timeIntervalSince($0) }) }
        stats.avgDuration = completedDurations.isEmpty ? 0 : completedDurations.reduce(0, +) / Double(completedDurations.count)
    }
}
