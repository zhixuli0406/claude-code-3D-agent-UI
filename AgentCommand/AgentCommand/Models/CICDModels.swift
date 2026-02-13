import Foundation

// MARK: - I1: CI/CD Pipeline Models

enum CICDProvider: String, CaseIterable, Identifiable {
    case githubActions = "github_actions"
    case gitlabCI = "gitlab_ci"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .githubActions: return "GitHub Actions"
        case .gitlabCI: return "GitLab CI"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .githubActions: return "arrow.triangle.branch"
        case .gitlabCI: return "gear.badge"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum PipelineStatus: String, CaseIterable {
    case queued = "queued"
    case inProgress = "in_progress"
    case success = "success"
    case failure = "failure"
    case cancelled = "cancelled"
    case skipped = "skipped"

    var hexColor: String {
        switch self {
        case .queued: return "#9E9E9E"
        case .inProgress: return "#2196F3"
        case .success: return "#4CAF50"
        case .failure: return "#F44336"
        case .cancelled: return "#FF9800"
        case .skipped: return "#607D8B"
        }
    }

    var iconName: String {
        switch self {
        case .queued: return "clock"
        case .inProgress: return "arrow.clockwise"
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        case .skipped: return "forward.fill"
        }
    }
}

struct CICDPipeline: Identifiable {
    let id: UUID
    var name: String
    var provider: CICDProvider
    var status: PipelineStatus
    var branch: String
    var commitSHA: String
    var commitMessage: String
    var author: String
    var stages: [PipelineStage]
    var startedAt: Date?
    var completedAt: Date?
    var duration: TimeInterval?
    var url: String?

    var isRunning: Bool {
        status == .inProgress || status == .queued
    }
}

struct PipelineStage: Identifiable {
    let id: UUID
    var name: String
    var status: PipelineStatus
    var jobs: [PipelineJob]
    var startedAt: Date?
    var completedAt: Date?
}

struct PipelineJob: Identifiable {
    let id: UUID
    var name: String
    var status: PipelineStatus
    var logOutput: String?
    var duration: TimeInterval?
}

enum PRReviewStatus: String, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case changesRequested = "changes_requested"
    case commented = "commented"

    var hexColor: String {
        switch self {
        case .pending: return "#FF9800"
        case .approved: return "#4CAF50"
        case .changesRequested: return "#F44336"
        case .commented: return "#2196F3"
        }
    }
}

struct CICDPullRequest: Identifiable {
    let id: UUID
    var number: Int
    var title: String
    var author: String
    var status: PRReviewStatus
    var reviewers: [PRReviewer]
    var checksStatus: PipelineStatus
    var commentCount: Int
    var createdAt: Date
    var updatedAt: Date
}

struct PRReviewer: Identifiable {
    let id: UUID
    var name: String
    var status: PRReviewStatus
    var avatarURL: String?
}

struct CICDStats {
    var totalPipelines: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var avgDuration: TimeInterval = 0
    var successRate: Double { totalPipelines > 0 ? Double(successCount) / Double(totalPipelines) : 0 }
}
