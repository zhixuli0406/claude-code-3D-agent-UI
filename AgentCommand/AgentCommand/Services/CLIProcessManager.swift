import Foundation

/// Manages a single Claude Code CLI process
@MainActor
class CLIProcess: ObservableObject, Identifiable {
    let id: UUID
    let taskId: UUID
    let agentId: UUID
    let prompt: String
    let workingDirectory: String

    let resumeSessionId: String?

    @Published var isRunning = false
    @Published var outputEntries: [CLIOutputEntry] = []
    @Published var toolCallCount: Int = 0
    @Published var sessionId: String?

    private var process: Process?
    private var hasPendingQuestion = false
    private var hasPendingPlanReview = false
    private var isInPlanMode = false
    private var hasReportedResult = false

    // Callbacks
    var onStatusChange: ((AgentStatus) -> Void)?
    var onProgressEstimate: ((Double) -> Void)?
    var onCompleted: ((String) -> Void)?
    var onFailed: ((String) -> Void)?
    var onDangerousCommand: ((String, String, String) -> Void)?  // (tool, input, reason)
    var onAskUserQuestion: ((String, String) -> Void)?  // (sessionId, inputJSON)
    var onPlanReview: ((String, String) -> Void)?  // (sessionId, inputJSON)
    var onOutput: ((CLIOutputEntry) -> Void)?

    private static let maxOutputEntries = 500

    // Buffers for incremental line assembly (accessed from readabilityHandler queues)
    private let stdoutBuffer = LineBuffer()
    private let stderrBuffer = LineBuffer()

    init(id: UUID = UUID(), taskId: UUID, agentId: UUID, prompt: String, workingDirectory: String, resumeSessionId: String? = nil) {
        self.id = id
        self.taskId = taskId
        self.agentId = agentId
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.resumeSessionId = resumeSessionId
    }

    func start() {
        guard !isRunning else { return }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let (execURL, extraArgs) = Self.resolveExecutable()
        process.executableURL = execURL

        var args = extraArgs + ["-p", prompt, "--output-format", "stream-json", "--verbose", "--dangerously-skip-permissions"]
        if let resumeId = resumeSessionId {
            args.append(contentsOf: ["--resume", resumeId])
        }
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Inherit PATH for tool execution
        var env = ProcessInfo.processInfo.environment
        var additionalPaths = ["/usr/local/bin", "/opt/homebrew/bin",
                               "\(NSHomeDirectory())/.local/bin",
                               "\(NSHomeDirectory())/.claude/bin"]

        // Resolve nvm node path (glob doesn't expand in PATH)
        let nvmBase = "\(NSHomeDirectory())/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmBase) {
            if let latest = versions.sorted().last {
                additionalPaths.append("\(nvmBase)/\(latest)/bin")
            }
        }

        if let existingPath = env["PATH"] {
            env["PATH"] = (additionalPaths + [existingPath]).joined(separator: ":")
        }
        process.environment = env

        self.process = process

        isRunning = true
        onStatusChange?(.working)
        appendEntry(.systemInfo, "CLI: \(execURL.path) \(extraArgs.joined(separator: " "))")
        appendEntry(.systemInfo, "Working dir: \(workingDirectory)")
        appendEntry(.systemInfo, "Process started: \(prompt)")

        // Non-blocking stdout reading via readabilityHandler
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else {
                // EOF — clean up handler
                handle.readabilityHandler = nil
                return
            }

            // Assemble complete lines from chunks
            let lines = self.stdoutBuffer.append(data)
            for lineData in lines {
                Task { @MainActor in
                    self.processLine(lineData)
                }
            }
        }

        // Non-blocking stderr reading via readabilityHandler
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else {
                handle.readabilityHandler = nil
                return
            }

            let lines = self.stderrBuffer.append(data)
            for lineData in lines {
                if let text = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty {
                    // Filter out verbose debug noise from --verbose flag
                    let lower = text.lowercased()
                    let isDebugNoise = lower.hasPrefix("debug:")
                        || lower.hasPrefix("[debug]")
                        || lower.hasPrefix("trace:")
                        || lower.contains("loading config")
                        || lower.contains("resolving")
                    let kind: CLIOutputEntry.Kind = isDebugNoise ? .systemInfo : .error
                    Task { @MainActor in
                        self.appendEntry(kind, text)
                    }
                }
            }
        }

        // Handle termination
        process.terminationHandler = { [weak self] proc in
            // Flush remaining buffer content
            if let self = self {
                let remainingStdout = self.stdoutBuffer.flush()
                let remainingStderr = self.stderrBuffer.flush()

                Task { @MainActor in
                    for lineData in remainingStdout {
                        self.processLine(lineData)
                    }
                    for lineData in remainingStderr {
                        if let text = String(data: lineData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !text.isEmpty {
                            self.appendEntry(.error, text)
                        }
                    }
                    self.handleTermination(exitCode: proc.terminationStatus)
                }
            }
        }

        do {
            try process.run()
        } catch {
            appendEntry(.error, "Failed to start: \(error.localizedDescription)")
            isRunning = false
            onFailed?("Failed to start: \(error.localizedDescription)")
        }
    }

    func cancel() {
        process?.terminate()
        appendEntry(.systemInfo, "Process cancelled by user")
    }

    // MARK: - Private

    private func processLine(_ data: Data) {
        if let event = CLIStreamEvent.parse(from: data) {
            handleEvent(event)
        } else if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty {
            // Log unparsed JSON for debugging
            if text.hasPrefix("{") {
                print("[CLIProcess] Unparsed JSON line: \(String(text.prefix(500)))")
            }
            appendEntry(.systemInfo, text)
        }
    }

    private func handleEvent(_ event: CLIStreamEvent) {
        switch event {
        case .system(let sid):
            if let sid = sid, sessionId == nil {
                sessionId = sid
                appendEntry(.systemInfo, "Session: \(sid)")
            }

        case .assistantText(let text):
            let preview = String(text.prefix(300))
            appendEntry(.assistantThinking, preview)
            onStatusChange?(.thinking)

        case .assistantToolUse(let tool, let input):
            toolCallCount += 1
            appendEntry(.toolInvocation, "Using tool: \(tool)")
            onStatusChange?(.working)
            let estimatedProgress = min(Double(toolCallCount) / 20.0, 0.9)
            onProgressEstimate?(estimatedProgress)

            // Check for AskUserQuestion
            if tool == "AskUserQuestion" {
                appendEntry(.askQuestion, "Agent is asking a question...")
                if let sid = sessionId {
                    hasPendingQuestion = true
                    onAskUserQuestion?(sid, input)
                } else {
                    appendEntry(.error, "Cannot show question: no session ID available")
                }
            }

            // Check for plan mode
            if tool == "EnterPlanMode" {
                isInPlanMode = true
                appendEntry(.planMode, "Entering plan mode...")
                onStatusChange?(.thinking)
            }
            if tool == "ExitPlanMode" {
                isInPlanMode = false
                appendEntry(.planMode, "Plan ready for review")
                if let sid = sessionId {
                    hasPendingPlanReview = true
                    onPlanReview?(sid, input)
                } else {
                    appendEntry(.error, "Cannot show plan: no session ID available")
                }
            }

            // Check for dangerous commands
            let level = DangerousCommandClassifier.classify(tool: tool, input: input)
            if case .dangerous(let reason) = level {
                appendEntry(.dangerousWarning, "WARNING: \(reason)")
                onDangerousCommand?(tool, input, reason)
            }

        case .toolResult(_, let output):
            let preview = String(output.prefix(200))
            appendEntry(.toolOutput, preview)

        case .resultSuccess(let result, let costUSD, let durationMs, let sid):
            if let sid = sid, sessionId == nil {
                sessionId = sid
            }
            let preview = String(result.prefix(500))
            appendEntry(.finalResult, preview)
            if let cost = costUSD {
                appendEntry(.systemInfo, String(format: "Cost: $%.4f", cost))
            }
            if let duration = durationMs {
                appendEntry(.systemInfo, "Duration: \(duration)ms")
            }
            hasReportedResult = true
            onProgressEstimate?(1.0)
            onCompleted?(result)

        case .resultError(let error):
            print("[CLIProcess] Result error for agent \(agentId): \(error)")
            appendEntry(.error, error)
            hasReportedResult = true
            onFailed?(error)

        case .unknown(let unknownType):
            print("[CLIProcess] Unhandled event type: \(unknownType)")
            break
        }
    }

    private func handleTermination(exitCode: Int32) {
        isRunning = false
        if exitCode == 0 {
            appendEntry(.systemInfo, "Process exited successfully")
            // Only set completed if we haven't already reported a result
            if !hasReportedResult {
                onStatusChange?(.completed)
            }
        } else if exitCode == 15 || exitCode == 9 {
            appendEntry(.systemInfo, "Process was cancelled")
            onStatusChange?(.idle)
        } else if hasPendingQuestion {
            // Process ended because AskUserQuestion can't get input in -p mode
            appendEntry(.systemInfo, "Process paused for user question")
        } else if hasPendingPlanReview {
            // Process ended because ExitPlanMode can't get approval in -p mode
            appendEntry(.systemInfo, "Process paused for plan review")
        } else if hasReportedResult {
            // Already reported error via resultError event, don't duplicate
            appendEntry(.systemInfo, "Process exited with code: \(exitCode)")
        } else {
            // Collect any stderr content to provide a more meaningful error message
            let stderrErrors = outputEntries
                .filter { $0.kind == .error }
                .map(\.text)
                .suffix(3)
                .joined(separator: "; ")
            let errorMsg = stderrErrors.isEmpty
                ? "Process exited with code: \(exitCode)"
                : "Process exited with code \(exitCode): \(stderrErrors)"
            appendEntry(.error, errorMsg)
            onStatusChange?(.error)
            onFailed?(errorMsg)
        }
    }

    private func appendEntry(_ kind: CLIOutputEntry.Kind, _ text: String) {
        let entry = CLIOutputEntry(timestamp: Date(), kind: kind, text: text)
        outputEntries.append(entry)
        if outputEntries.count > Self.maxOutputEntries {
            outputEntries.removeFirst(outputEntries.count - Self.maxOutputEntries)
        }
        onOutput?(entry)
    }

    private static func resolveExecutable() -> (url: URL, extraArgs: [String]) {
        let directPaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "\(NSHomeDirectory())/.claude/bin/claude",
        ]
        for path in directPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return (URL(fileURLWithPath: path), [])
            }
        }
        return (URL(fileURLWithPath: "/usr/bin/env"), ["claude"])
    }
}

/// Thread-safe line buffer for assembling complete lines from chunked pipe data
private class LineBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    /// Append new data, return any complete lines (split by newline)
    func append(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        var lines: [Data] = []

        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
            if !lineData.isEmpty {
                lines.append(lineData)
            }
        }

        return lines
    }

    /// Flush any remaining data as a final line
    func flush() -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        if buffer.isEmpty { return [] }
        let remaining = buffer
        buffer = Data()
        return [remaining]
    }
}

/// Manages multiple concurrent CLI processes
@MainActor
class CLIProcessManager: ObservableObject {
    @Published var processes: [UUID: CLIProcess] = [:]

    func startProcess(
        taskId: UUID,
        agentId: UUID,
        prompt: String,
        workingDirectory: String,
        resumeSessionId: String? = nil,
        onStatusChange: @escaping (UUID, AgentStatus) -> Void,
        onProgress: @escaping (UUID, Double) -> Void,
        onCompleted: @escaping (UUID, String) -> Void,
        onFailed: @escaping (UUID, String) -> Void,
        onDangerousCommand: ((UUID, UUID, String, String, String) -> Void)? = nil,
        onAskUserQuestion: ((UUID, UUID, String, String) -> Void)? = nil,
        onPlanReview: ((UUID, UUID, String, String) -> Void)? = nil,
        onOutput: ((UUID, CLIOutputEntry) -> Void)? = nil
    ) -> CLIProcess {
        let cliProcess = CLIProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: prompt,
            workingDirectory: workingDirectory,
            resumeSessionId: resumeSessionId
        )

        cliProcess.onStatusChange = { status in
            onStatusChange(agentId, status)
        }
        cliProcess.onProgressEstimate = { progress in
            onProgress(taskId, progress)
        }
        cliProcess.onCompleted = { result in
            onCompleted(taskId, result)
        }
        cliProcess.onFailed = { error in
            onFailed(taskId, error)
        }
        cliProcess.onDangerousCommand = { tool, input, reason in
            onDangerousCommand?(taskId, agentId, tool, input, reason)
        }
        cliProcess.onAskUserQuestion = { sessionId, inputJSON in
            onAskUserQuestion?(taskId, agentId, sessionId, inputJSON)
        }
        cliProcess.onPlanReview = { sessionId, inputJSON in
            onPlanReview?(taskId, agentId, sessionId, inputJSON)
        }
        cliProcess.onOutput = { entry in
            onOutput?(agentId, entry)
        }

        processes[taskId] = cliProcess
        cliProcess.start()
        return cliProcess
    }

    func cancelProcess(taskId: UUID) {
        processes[taskId]?.cancel()
    }

    func cancelAll() {
        for process in processes.values {
            process.cancel()
        }
    }

    func removeProcess(taskId: UUID) {
        processes.removeValue(forKey: taskId)
    }

    func outputEntries(for taskId: UUID) -> [CLIOutputEntry] {
        processes[taskId]?.outputEntries ?? []
    }
}
