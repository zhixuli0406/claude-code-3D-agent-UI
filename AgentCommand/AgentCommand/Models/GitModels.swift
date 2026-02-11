import Foundation

// MARK: - Git Diff

struct GitDiffFile: Identifiable, Codable, Hashable {
    let id: UUID
    let filePath: String
    let status: GitFileStatus
    let additions: Int
    let deletions: Int
    let hunks: [GitDiffHunk]

    init(id: UUID = UUID(), filePath: String, status: GitFileStatus, additions: Int, deletions: Int, hunks: [GitDiffHunk] = []) {
        self.id = id
        self.filePath = filePath
        self.status = status
        self.additions = additions
        self.deletions = deletions
        self.hunks = hunks
    }
}

enum GitFileStatus: String, Codable {
    case added, modified, deleted, renamed, untracked

    var icon: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .untracked: return "questionmark.circle.fill"
        }
    }

    var hexColor: String {
        switch self {
        case .added: return "#4CAF50"
        case .modified: return "#FF9800"
        case .deleted: return "#F44336"
        case .renamed: return "#2196F3"
        case .untracked: return "#9E9E9E"
        }
    }
}

struct GitDiffHunk: Identifiable, Codable, Hashable {
    let id: UUID
    let header: String
    let oldStart: Int
    let newStart: Int
    let lines: [GitDiffLine]

    init(id: UUID = UUID(), header: String, oldStart: Int, newStart: Int, lines: [GitDiffLine]) {
        self.id = id
        self.header = header
        self.oldStart = oldStart
        self.newStart = newStart
        self.lines = lines
    }
}

struct GitDiffLine: Identifiable, Codable, Hashable {
    let id: UUID
    let type: GitLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?

    init(id: UUID = UUID(), type: GitLineType, content: String, oldLineNumber: Int? = nil, newLineNumber: Int? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

enum GitLineType: String, Codable {
    case context, addition, deletion
}

// MARK: - Git Branch

struct GitBranch: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
    let lastCommitHash: String
    let lastCommitDate: Date?
    let aheadCount: Int
    let behindCount: Int

    init(id: UUID = UUID(), name: String, isCurrent: Bool = false, isRemote: Bool = false, lastCommitHash: String = "", lastCommitDate: Date? = nil, aheadCount: Int = 0, behindCount: Int = 0) {
        self.id = id
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.lastCommitHash = lastCommitHash
        self.lastCommitDate = lastCommitDate
        self.aheadCount = aheadCount
        self.behindCount = behindCount
    }
}

// MARK: - Git Commit

struct GitCommit: Identifiable, Codable, Hashable {
    let id: UUID
    let hash: String
    let fullHash: String
    let message: String
    let author: String
    let date: Date
    let branchName: String?
    let agentId: UUID?
    let parentHashes: [String]
    let filesChanged: Int
    let additions: Int
    let deletions: Int

    init(id: UUID = UUID(), hash: String, fullHash: String, message: String, author: String, date: Date, branchName: String? = nil, agentId: UUID? = nil, parentHashes: [String] = [], filesChanged: Int = 0, additions: Int = 0, deletions: Int = 0) {
        self.id = id
        self.hash = hash
        self.fullHash = fullHash
        self.message = message
        self.author = author
        self.date = date
        self.branchName = branchName
        self.agentId = agentId
        self.parentHashes = parentHashes
        self.filesChanged = filesChanged
        self.additions = additions
        self.deletions = deletions
    }
}

// MARK: - Git Repository State

struct GitRepositoryState: Codable {
    var currentBranch: String
    var branches: [GitBranch]
    var recentCommits: [GitCommit]
    var stagedFiles: [GitDiffFile]
    var unstagedFiles: [GitDiffFile]
    var isClean: Bool
    var remoteURL: String?
    var lastFetchDate: Date?
}

// MARK: - PR Preview

struct PRPreviewData: Identifiable {
    let id: UUID
    let sourceBranch: String
    let targetBranch: String
    var title: String
    var body: String
    let commits: [GitCommit]
    let diffFiles: [GitDiffFile]
    let totalAdditions: Int
    let totalDeletions: Int

    init(id: UUID = UUID(), sourceBranch: String, targetBranch: String, title: String, body: String = "", commits: [GitCommit] = [], diffFiles: [GitDiffFile] = [], totalAdditions: Int = 0, totalDeletions: Int = 0) {
        self.id = id
        self.sourceBranch = sourceBranch
        self.targetBranch = targetBranch
        self.title = title
        self.body = body
        self.commits = commits
        self.diffFiles = diffFiles
        self.totalAdditions = totalAdditions
        self.totalDeletions = totalDeletions
    }
}
