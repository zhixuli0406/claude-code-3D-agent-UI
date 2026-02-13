import Foundation

@MainActor
class GitIntegrationManager: ObservableObject {
    @Published var repositoryState: GitRepositoryState?
    @Published var isGitRepository: Bool = false
    @Published var prPreview: PRPreviewData?
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private var pollingTimer: Timer?
    private var workingDirectory: String = NSHomeDirectory()
    /// The original directory passed to startMonitoring (before resolving to git root)
    private var resolvedFromDirectory: String?
    private let pollInterval: TimeInterval = 5.0

    // Compile-time source path — always inside the project git repo
    private static let compileTimeSourcePath: String = #filePath

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Lifecycle

    func startMonitoring(directory: String) {
        // If already monitoring the same directory (or its resolved git root), skip re-init
        if isGitRepository,
           repositoryState != nil,
           (directory == workingDirectory || resolvedFromDirectory == directory) {
            // Already monitoring — just ensure polling is running
            if pollingTimer == nil { startPolling() }
            return
        }

        stopMonitoring()
        resolvedFromDirectory = directory
        workingDirectory = directory

        // Synchronous filesystem check for immediate UI feedback.
        // This prevents the "not a git repo" flash while the async Task resolves.
        let quickRoot = findGitRootByFilesystem(from: directory)
            ?? findGitRootByFilesystem(from: URL(fileURLWithPath: Self.compileTimeSourcePath).deletingLastPathComponent().path)
        if let root = quickRoot {
            workingDirectory = root
            isGitRepository = true
            lastError = nil
        }

        Task {
            // Full async resolution (tries git command for accuracy, then fetches state)
            var resolved: String?
            if FileManager.default.fileExists(atPath: directory) {
                resolved = await resolveGitRoot(directory)
            }

            // If the given directory is not a git repo (e.g. home dir fallback),
            // try multiple strategies to find a git repo
            if resolved == nil {
                var candidates: [String] = []

                // Strategy 1: Use compile-time source path (most reliable for dev builds).
                // This works even when the executable is in Xcode DerivedData.
                var sourcePath = URL(fileURLWithPath: Self.compileTimeSourcePath)
                for _ in 0..<15 {
                    sourcePath = sourcePath.deletingLastPathComponent()
                    let path = sourcePath.path
                    if path == "/" { break }
                    candidates.append(path)
                }

                // Strategy 2: Walk up from the bundle's executable location.
                // For .app bundles this starts inside Contents/MacOS/, which is fine —
                // we just keep walking up past the .app, dist/, etc.
                var bundlePath = Bundle.main.executableURL ?? Bundle.main.bundleURL
                for _ in 0..<15 {
                    bundlePath = bundlePath.deletingLastPathComponent()
                    let path = bundlePath.path
                    if path == "/" { break }
                    candidates.append(path)
                }

                // Strategy 3: Also try the current directory and walk up from it
                let cwd = FileManager.default.currentDirectoryPath
                if cwd != "/" {
                    candidates.append(cwd)
                    var cwdURL = URL(fileURLWithPath: cwd)
                    for _ in 0..<10 {
                        cwdURL = cwdURL.deletingLastPathComponent()
                        let path = cwdURL.path
                        if path == "/" { break }
                        candidates.append(path)
                    }
                }

                // Deduplicate while preserving order, and skip paths inside .app bundles
                var seen = Set<String>()
                var uniqueCandidates: [String] = []
                for candidate in candidates {
                    // Skip directories inside .app bundle (they are not real filesystem dirs for git)
                    if candidate.contains(".app/") { continue }
                    if seen.insert(candidate).inserted,
                       FileManager.default.fileExists(atPath: candidate) {
                        uniqueCandidates.append(candidate)
                    }
                }

                for candidate in uniqueCandidates {
                    if let root = await resolveGitRoot(candidate) {
                        resolved = root
                        break
                    }
                }
            }

            if let gitRoot = resolved {
                workingDirectory = gitRoot
                isGitRepository = true
                lastError = nil
                await refreshState()
                startPolling()
            } else if quickRoot != nil {
                // Filesystem found .git but git commands failed — still usable
                await refreshState()
                startPolling()
            } else {
                isGitRepository = false
                repositoryState = nil
                lastError = "No git repository found. Set an active workspace that points to a git project."
            }
        }
    }

    /// Resolve the git root directory from a given path, or nil if not inside a git repo.
    private func resolveGitRoot(_ directory: String) async -> String? {
        // Try git command first
        let (output, exitCode) = await runGitCommand(
            ["rev-parse", "--show-toplevel"],
            directory: directory
        )
        if exitCode == 0 {
            let root = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !root.isEmpty { return root }
        }

        // Fallback: walk up the directory tree looking for a .git folder.
        // This works even when Process() cannot execute (sandbox, missing git, etc.).
        return findGitRootByFilesystem(from: directory)
    }

    /// Walk up from `directory` looking for a `.git` folder on the filesystem.
    private func findGitRootByFilesystem(from directory: String) -> String? {
        var url = URL(fileURLWithPath: directory).standardized
        for _ in 0..<30 {
            let gitDir = url.appendingPathComponent(".git").path
            if FileManager.default.fileExists(atPath: gitDir) {
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break } // reached root
            url = parent
        }
        return nil
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        resolvedFromDirectory = nil
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshState()
            }
        }
    }

    // MARK: - Git Command Execution

    func runGitCommand(_ args: [String], directory: String? = nil) async -> (output: String, exitCode: Int32) {
        let dir = directory ?? workingDirectory

        // Verify the directory exists before trying to run git there
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            return ("Directory does not exist: \(dir)", -1)
        }

        // Run the process on a background thread to avoid blocking the main actor
        return await Task.detached {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            // Try multiple git paths
            let gitPaths = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
            var gitURL: URL?
            for path in gitPaths {
                if FileManager.default.isExecutableFile(atPath: path) {
                    gitURL = URL(fileURLWithPath: path)
                    break
                }
            }
            guard let execURL = gitURL else {
                return ("git executable not found", Int32(-1))
            }

            process.executableURL = execURL
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Inherit environment so git can find its config
            var env = ProcessInfo.processInfo.environment
            // Ensure PATH includes common locations
            let existingPath = env["PATH"] ?? ""
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:" + existingPath
            process.environment = env

            do {
                try process.run()
                // Read stdout BEFORE waitUntilExit to prevent pipe buffer deadlock
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(data: data, encoding: .utf8) ?? ""
                return (output, process.terminationStatus)
            } catch {
                return ("Failed to launch git: \(error.localizedDescription)", Int32(-1))
            }
        }.value
    }

    // MARK: - Data Fetching

    func refreshState() async {
        guard isGitRepository else { return }

        let currentBranch = await fetchCurrentBranch()
        let branches = await fetchBranches()
        let commits = await fetchRecentCommits(count: 50)
        let staged = await fetchDiff(staged: true)
        let unstaged = await fetchDiff(staged: false)
        let remoteURL = await fetchRemoteURL()

        let isClean = staged.isEmpty && unstaged.isEmpty

        repositoryState = GitRepositoryState(
            currentBranch: currentBranch,
            branches: branches,
            recentCommits: commits,
            stagedFiles: staged,
            unstagedFiles: unstaged,
            isClean: isClean,
            remoteURL: remoteURL,
            lastFetchDate: Date()
        )
    }

    private func fetchCurrentBranch() async -> String {
        let (output, _) = await runGitCommand(["branch", "--show-current"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchBranches() async -> [GitBranch] {
        let (output, exitCode) = await runGitCommand([
            "branch", "-a",
            "--format=%(refname:short)|%(HEAD)|%(objectname:short)|%(creatordate:iso8601-strict)"
        ])
        guard exitCode == 0 else { return [] }
        return parseBranchOutput(output)
    }

    func fetchRecentCommits(count: Int) async -> [GitCommit] {
        let (output, exitCode) = await runGitCommand([
            "log",
            "--format=%h|%H|%s|%an|%aI|%D|%P",
            "-n", "\(count)",
            "--all"
        ])
        guard exitCode == 0 else { return [] }

        let commits = parseLogOutput(output)

        // Fetch --numstat for file change counts
        let (statOutput, statExit) = await runGitCommand([
            "log",
            "--format=%h",
            "--numstat",
            "-n", "\(count)",
            "--all"
        ])

        if statExit == 0 {
            return enrichCommitsWithStats(commits: commits, statOutput: statOutput)
        }
        return commits
    }

    func fetchDiff(staged: Bool) async -> [GitDiffFile] {
        var args = ["diff", "--numstat"]
        if staged { args.append("--cached") }
        let (numstatOutput, exitCode) = await runGitCommand(args)
        guard exitCode == 0 else { return [] }

        var diffArgs = ["diff"]
        if staged { diffArgs.append("--cached") }
        let (diffOutput, _) = await runGitCommand(diffArgs)

        return parseDiffOutput(numstatOutput: numstatOutput, diffOutput: diffOutput)
    }

    private func fetchRemoteURL() async -> String? {
        let (output, exitCode) = await runGitCommand(["remote", "get-url", "origin"])
        guard exitCode == 0 else { return nil }
        let url = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    // MARK: - PR Preview

    func preparePRPreview(source: String, target: String) async {
        isLoading = true
        defer { isLoading = false }

        let (logOutput, _) = await runGitCommand([
            "log", "--format=%h|%H|%s|%an|%aI|%D|%P",
            "\(target)..\(source)"
        ])
        let commits = parseLogOutput(logOutput)

        let (numstatOutput, _) = await runGitCommand(["diff", "--numstat", "\(target)...\(source)"])
        let (diffOutput, _) = await runGitCommand(["diff", "\(target)...\(source)"])
        let diffFiles = parseDiffOutput(numstatOutput: numstatOutput, diffOutput: diffOutput)

        let totalAdd = diffFiles.reduce(0) { $0 + $1.additions }
        let totalDel = diffFiles.reduce(0) { $0 + $1.deletions }

        let title = commits.first?.message ?? "PR from \(source)"

        prPreview = PRPreviewData(
            sourceBranch: source,
            targetBranch: target,
            title: title,
            commits: commits,
            diffFiles: diffFiles,
            totalAdditions: totalAdd,
            totalDeletions: totalDel
        )
    }

    func createPR(title: String, body: String, source: String, target: String) async -> Bool {
        // Use gh CLI
        let ghPath = findExecutable("gh")
        guard let ghPath else {
            lastError = "gh CLI not found. Install it from https://cli.github.com"
            return false
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: ghPath)
            process.arguments = ["pr", "create", "--title", title, "--body", body, "--base", target, "--head", source]
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private func findExecutable(_ name: String) -> String? {
        let paths = [
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Stage, Commit & Push

    /// Stage all changed files (tracked + untracked).
    func stageAll() async -> Bool {
        let (_, exitCode) = await runGitCommand(["add", "-A"])
        if exitCode == 0 {
            await refreshState()
        }
        return exitCode == 0
    }

    /// Commit staged changes with the given message.
    func commit(message: String) async -> (success: Bool, error: String?) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, "Commit message is empty")
        }
        let (output, exitCode) = await runGitCommand(["commit", "-m", message])
        if exitCode == 0 {
            await refreshState()
            return (true, nil)
        }
        let errMsg = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return (false, errMsg.isEmpty ? "Commit failed" : errMsg)
    }

    /// Push current branch to origin.
    func push() async -> (success: Bool, error: String?) {
        let branch = repositoryState?.currentBranch ?? ""
        let args = branch.isEmpty ? ["push"] : ["push", "-u", "origin", branch]
        let (output, exitCode) = await runGitCommand(args)
        if exitCode == 0 {
            await refreshState()
            return (true, nil)
        }
        let errMsg = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return (false, errMsg.isEmpty ? "Push failed" : errMsg)
    }

    /// Generate a commit message by analysing the current staged diff using a local AI summarisation approach.
    /// This uses `git diff --cached --stat` and `git diff --cached` to build a summary prompt,
    /// then constructs a conventional-commit-style message from the diff metadata.
    func generateCommitMessage() async -> String {
        // Gather staged diff summary
        let (statOutput, statExit) = await runGitCommand(["diff", "--cached", "--stat"])
        guard statExit == 0, !statOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // If nothing staged, try unstaged
            let (unstagedStat, uExit) = await runGitCommand(["diff", "--stat"])
            if uExit == 0, !unstagedStat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return buildMessageFromStat(unstagedStat)
            }
            // Check for untracked files
            let (untrackedOutput, _) = await runGitCommand(["ls-files", "--others", "--exclude-standard"])
            let untrackedFiles = untrackedOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
            if !untrackedFiles.isEmpty {
                return buildMessageForNewFiles(untrackedFiles)
            }
            return "chore: update files"
        }

        // Also get a short patch for more context
        let (patchOutput, _) = await runGitCommand(["diff", "--cached", "-p", "--no-color"])

        return buildSmartMessage(stat: statOutput, patch: patchOutput)
    }

    /// Build a smart commit message by analyzing the diff stat and patch content.
    private func buildSmartMessage(stat: String, patch: String) -> String {
        let lines = stat.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Parse stat summary line (last line): " N files changed, N insertions(+), N deletions(-)"
        var totalFiles = 0
        var totalInsertions = 0
        var totalDeletions = 0
        var fileNames: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("file") && trimmed.contains("changed") {
                // Summary line
                let numbers = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if numbers.count >= 1 { totalFiles = Int(numbers[0]) ?? 0 }
                if numbers.count >= 2 { totalInsertions = Int(numbers[1]) ?? 0 }
                if numbers.count >= 3 { totalDeletions = Int(numbers[2]) ?? 0 }
            } else if trimmed.contains("|") {
                // File line: " path/to/file | N +++---"
                let parts = trimmed.components(separatedBy: "|")
                if let fileName = parts.first?.trimmingCharacters(in: .whitespaces) {
                    fileNames.append(fileName)
                }
            }
        }

        // Determine the type of change
        let commitType = detectCommitType(fileNames: fileNames, patch: patch, insertions: totalInsertions, deletions: totalDeletions)

        // Build scope from common directory
        let scope = detectScope(fileNames: fileNames)

        // Build description
        let description = buildDescription(
            fileNames: fileNames,
            totalFiles: totalFiles,
            insertions: totalInsertions,
            deletions: totalDeletions,
            patch: patch
        )

        if scope.isEmpty {
            return "\(commitType): \(description)"
        }
        return "\(commitType)(\(scope)): \(description)"
    }

    private func detectCommitType(fileNames: [String], patch: String, insertions: Int, deletions: Int) -> String {
        let allNames = fileNames.joined(separator: " ").lowercased()
        let patchLower = patch.lowercased()

        // Check for test files
        if fileNames.allSatisfy({ $0.lowercased().contains("test") || $0.lowercased().contains("spec") }) {
            return "test"
        }
        // Check for documentation
        if fileNames.allSatisfy({ $0.lowercased().hasSuffix(".md") || $0.lowercased().contains("doc") || $0.lowercased().contains("readme") }) {
            return "docs"
        }
        // Check for CI/config
        if allNames.contains("ci") || allNames.contains("github/workflows") || allNames.contains(".yml") || allNames.contains("package.json") || allNames.contains("podfile") || allNames.contains("xcodeproj") {
            return "chore"
        }
        // Check for style-only changes
        if allNames.contains(".css") || allNames.contains(".scss") || allNames.contains("style") {
            return "style"
        }
        // If only deletions significantly outweigh insertions, likely refactor
        if deletions > insertions * 2 && insertions > 0 {
            return "refactor"
        }
        // If patch contains "fix" related keywords
        if patchLower.contains("bug") || patchLower.contains("fix") || patchLower.contains("issue") || patchLower.contains("error") || patchLower.contains("crash") {
            return "fix"
        }
        // Default to feat for new additions
        if insertions > deletions {
            return "feat"
        }
        return "refactor"
    }

    private func detectScope(fileNames: [String]) -> String {
        guard !fileNames.isEmpty else { return "" }

        // Find common path prefix
        let pathComponents = fileNames.map { $0.components(separatedBy: "/") }
        guard let first = pathComponents.first else { return "" }

        var commonDepth = 0
        for i in 0..<first.count {
            let component = first[i]
            if pathComponents.allSatisfy({ $0.count > i && $0[i] == component }) {
                commonDepth = i + 1
            } else {
                break
            }
        }

        if commonDepth > 0 {
            let commonPath = first.prefix(commonDepth)
            // Use the deepest meaningful directory name
            if let last = commonPath.last, !last.contains(".") {
                return last
            }
        }

        // Fallback: use first file's parent directory
        if let firstComponents = pathComponents.first, firstComponents.count > 1 {
            return firstComponents[firstComponents.count - 2]
        }

        return ""
    }

    private func buildDescription(fileNames: [String], totalFiles: Int, insertions: Int, deletions: Int, patch: String) -> String {
        // Try to extract meaningful function/struct names from patch
        let newSymbols = extractNewSymbols(from: patch)
        if !newSymbols.isEmpty {
            let symbolList = newSymbols.prefix(3).joined(separator: ", ")
            if deletions == 0 {
                return "add \(symbolList)"
            }
            return "update \(symbolList)"
        }

        // Describe by file names
        if totalFiles == 1 {
            let fileName = fileNames.first?.components(separatedBy: "/").last ?? "file"
            let baseName = fileName.components(separatedBy: ".").first ?? fileName
            if insertions > 0 && deletions == 0 {
                return "add \(baseName)"
            } else if deletions > 0 && insertions == 0 {
                return "remove \(baseName)"
            }
            return "update \(baseName)"
        }

        // Multiple files
        if insertions > 0 && deletions == 0 {
            return "add \(totalFiles) files"
        } else if deletions > insertions * 3 {
            return "clean up \(totalFiles) files"
        }
        return "update \(totalFiles) files"
    }

    private func extractNewSymbols(from patch: String) -> [String] {
        var symbols: [String] = []
        let lines = patch.components(separatedBy: "\n")

        for line in lines {
            guard line.hasPrefix("+") && !line.hasPrefix("+++") else { continue }
            let content = String(line.dropFirst())

            // Swift patterns
            let swiftPatterns: [(String, String)] = [
                (#"func\s+(\w+)"#, "func"),
                (#"class\s+(\w+)"#, "class"),
                (#"struct\s+(\w+)"#, "struct"),
                (#"enum\s+(\w+)"#, "enum"),
                (#"protocol\s+(\w+)"#, "protocol"),
            ]

            for (pattern, _) in swiftPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: content) {
                    let name = String(content[range])
                    if !symbols.contains(name) {
                        symbols.append(name)
                    }
                }
            }

            if symbols.count >= 3 { break }
        }

        return symbols
    }

    private func buildMessageFromStat(_ stat: String) -> String {
        let lines = stat.components(separatedBy: "\n").filter { !$0.isEmpty }
        let fileCount = lines.count - 1 // last line is summary
        if fileCount <= 0 { return "chore: update files" }
        if fileCount == 1 {
            if let fileName = lines.first?.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) {
                let baseName = fileName.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? "file"
                return "feat: update \(baseName)"
            }
        }
        return "feat: update \(fileCount) files"
    }

    private func buildMessageForNewFiles(_ files: [String]) -> String {
        if files.count == 1 {
            let baseName = files[0].components(separatedBy: "/").last?.components(separatedBy: ".").first ?? "file"
            return "feat: add \(baseName)"
        }
        return "feat: add \(files.count) new files"
    }

    // MARK: - Parsing

    private func parseBranchOutput(_ output: String) -> [GitBranch] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        var branches: [GitBranch] = []

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { continue }

            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let isCurrent = parts[1].trimmingCharacters(in: .whitespaces) == "*"
            let commitHash = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
            let dateStr = parts.count > 3 ? parts[3].trimmingCharacters(in: .whitespaces) : ""

            // Skip HEAD pointer references
            if name.contains("HEAD") { continue }

            let isRemote = name.hasPrefix("origin/")
            var date: Date? = nil
            if !dateStr.isEmpty {
                date = dateFormatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
            }

            branches.append(GitBranch(
                name: name,
                isCurrent: isCurrent,
                isRemote: isRemote,
                lastCommitHash: commitHash,
                lastCommitDate: date
            ))
        }
        return branches
    }

    private func parseLogOutput(_ output: String) -> [GitCommit] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        var commits: [GitCommit] = []

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 5 else { continue }

            let hash = parts[0]
            let fullHash = parts[1]
            let message = parts[2]
            let author = parts[3]
            let dateStr = parts[4]
            let refs = parts.count > 5 ? parts[5] : ""
            let parentStr = parts.count > 6 ? parts[6] : ""

            let date = dateFormatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr) ?? Date()
            let parentHashes = parentStr.components(separatedBy: " ").filter { !$0.isEmpty }

            // Extract branch name from refs like "HEAD -> main, origin/main"
            var branchName: String? = nil
            if !refs.isEmpty {
                let refParts = refs.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for ref in refParts {
                    if ref.contains("->") {
                        branchName = ref.components(separatedBy: "->").last?.trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                if branchName == nil {
                    branchName = refParts.first { !$0.contains("origin/") }
                }
            }

            commits.append(GitCommit(
                hash: hash,
                fullHash: fullHash,
                message: message,
                author: author,
                date: date,
                branchName: branchName,
                parentHashes: parentHashes
            ))
        }
        return commits
    }

    private func parseDiffOutput(numstatOutput: String, diffOutput: String) -> [GitDiffFile] {
        let numstatLines = numstatOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
        var files: [GitDiffFile] = []

        // Parse the full diff output into hunks per file
        let filePatches = splitDiffByFile(diffOutput)

        for line in numstatLines {
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count >= 3 else { continue }

            let addStr = String(parts[0])
            let delStr = String(parts[1])
            let filePath = String(parts[2])

            let additions = Int(addStr) ?? 0
            let deletions = Int(delStr) ?? 0

            let status: GitFileStatus
            if additions > 0 && deletions == 0 {
                status = .added
            } else if additions == 0 && deletions > 0 {
                status = .deleted
            } else {
                status = .modified
            }

            let hunks = filePatches[filePath] ?? []

            files.append(GitDiffFile(
                filePath: filePath,
                status: status,
                additions: additions,
                deletions: deletions,
                hunks: hunks
            ))
        }
        return files
    }

    private func splitDiffByFile(_ diffOutput: String) -> [String: [GitDiffHunk]] {
        var result: [String: [GitDiffHunk]] = [:]
        let lines = diffOutput.components(separatedBy: "\n")
        var currentFile: String?
        var currentHunkLines: [GitDiffLine] = []
        var currentHunkHeader = ""
        var currentOldStart = 0
        var currentNewStart = 0
        var hunksForFile: [GitDiffHunk] = []
        var oldLine = 0
        var newLine = 0

        for line in lines {
            if line.hasPrefix("diff --git") {
                // Save previous file
                if let file = currentFile {
                    if !currentHunkLines.isEmpty {
                        hunksForFile.append(GitDiffHunk(header: currentHunkHeader, oldStart: currentOldStart, newStart: currentNewStart, lines: currentHunkLines))
                    }
                    result[file] = hunksForFile
                }
                // Extract file path: "diff --git a/path b/path"
                let parts = line.components(separatedBy: " b/")
                currentFile = parts.count > 1 ? String(parts.last!) : nil
                hunksForFile = []
                currentHunkLines = []
                currentHunkHeader = ""
            } else if line.hasPrefix("@@") {
                // New hunk
                if !currentHunkLines.isEmpty {
                    hunksForFile.append(GitDiffHunk(header: currentHunkHeader, oldStart: currentOldStart, newStart: currentNewStart, lines: currentHunkLines))
                }
                currentHunkHeader = line
                currentHunkLines = []

                // Parse hunk header: "@@ -10,7 +10,8 @@"
                let hunkPattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
                if let match = line.range(of: hunkPattern, options: .regularExpression) {
                    let matched = String(line[match])
                    let numbers = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                    if numbers.count >= 2 {
                        currentOldStart = Int(numbers[0]) ?? 0
                        currentNewStart = Int(numbers[1]) ?? 0
                    }
                }
                oldLine = currentOldStart
                newLine = currentNewStart
            } else if currentFile != nil && !line.hasPrefix("---") && !line.hasPrefix("+++") && !line.hasPrefix("index ") && !line.hasPrefix("new file") && !line.hasPrefix("deleted file") {
                if line.hasPrefix("+") {
                    currentHunkLines.append(GitDiffLine(type: .addition, content: String(line.dropFirst()), newLineNumber: newLine))
                    newLine += 1
                } else if line.hasPrefix("-") {
                    currentHunkLines.append(GitDiffLine(type: .deletion, content: String(line.dropFirst()), oldLineNumber: oldLine))
                    oldLine += 1
                } else if line.hasPrefix(" ") || (!line.hasPrefix("\\") && !line.isEmpty) {
                    let content = line.hasPrefix(" ") ? String(line.dropFirst()) : line
                    currentHunkLines.append(GitDiffLine(type: .context, content: content, oldLineNumber: oldLine, newLineNumber: newLine))
                    oldLine += 1
                    newLine += 1
                }
            }
        }

        // Save last file
        if let file = currentFile {
            if !currentHunkLines.isEmpty {
                hunksForFile.append(GitDiffHunk(header: currentHunkHeader, oldStart: currentOldStart, newStart: currentNewStart, lines: currentHunkLines))
            }
            result[file] = hunksForFile
        }

        return result
    }

    private func enrichCommitsWithStats(commits: [GitCommit], statOutput: String) -> [GitCommit] {
        var statsMap: [String: (files: Int, adds: Int, dels: Int)] = [:]
        let lines = statOutput.components(separatedBy: "\n")
        var currentHash: String?
        var files = 0, adds = 0, dels = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if let hash = currentHash {
                    statsMap[hash] = (files, adds, dels)
                }
                currentHash = nil
                files = 0; adds = 0; dels = 0
                continue
            }

            let parts = trimmed.split(separator: "\t", maxSplits: 2)
            if parts.count >= 3 {
                // numstat line: adds\tdels\tfilename
                adds += Int(parts[0]) ?? 0
                dels += Int(parts[1]) ?? 0
                files += 1
            } else if parts.count == 1 && trimmed.count <= 12 && !trimmed.contains(" ") {
                // Likely a commit hash line
                if let hash = currentHash {
                    statsMap[hash] = (files, adds, dels)
                }
                currentHash = trimmed
                files = 0; adds = 0; dels = 0
            }
        }
        if let hash = currentHash {
            statsMap[hash] = (files, adds, dels)
        }

        return commits.map { commit in
            if let stats = statsMap[commit.hash] {
                return GitCommit(
                    id: commit.id,
                    hash: commit.hash,
                    fullHash: commit.fullHash,
                    message: commit.message,
                    author: commit.author,
                    date: commit.date,
                    branchName: commit.branchName,
                    agentId: commit.agentId,
                    parentHashes: commit.parentHashes,
                    filesChanged: stats.files,
                    additions: stats.adds,
                    deletions: stats.dels
                )
            }
            return commit
        }
    }
}
