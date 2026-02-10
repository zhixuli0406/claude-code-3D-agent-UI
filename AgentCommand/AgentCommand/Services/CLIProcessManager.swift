import Foundation

/// Manages a single Claude Code CLI process
@MainActor
class CLIProcess: ObservableObject, Identifiable {
    let id: UUID
    let taskId: UUID
    let agentId: UUID
    let prompt: String
    let workingDirectory: String

    @Published var isRunning = false
    @Published var outputEntries: [CLIOutputEntry] = []
    @Published var toolCallCount: Int = 0

    private var process: Process?

    // Callbacks
    var onStatusChange: ((AgentStatus) -> Void)?
    var onProgressEstimate: ((Double) -> Void)?
    var onCompleted: ((String) -> Void)?
    var onFailed: ((String) -> Void)?
    var onDangerousCommand: ((String, String, String) -> Void)?  // (tool, input, reason)

    private static let maxOutputEntries = 500

    // Buffers for incremental line assembly (accessed from readabilityHandler queues)
    private let stdoutBuffer = LineBuffer()
    private let stderrBuffer = LineBuffer()

    init(id: UUID = UUID(), taskId: UUID, agentId: UUID, prompt: String, workingDirectory: String) {
        self.id = id
        self.taskId = taskId
        self.agentId = agentId
        self.prompt = prompt
        self.workingDirectory = workingDirectory
    }

    func start() {
        guard !isRunning else { return }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let (execURL, extraArgs) = Self.resolveExecutable()
        process.executableURL = execURL
        process.arguments = extraArgs + ["-p", prompt, "--output-format", "stream-json", "--verbose", "--dangerously-skip-permissions"]
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
                    Task { @MainActor in
                        self.appendEntry(.error, text)
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
            appendEntry(.systemInfo, text)
        }
    }

    private func handleEvent(_ event: CLIStreamEvent) {
        switch event {
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

            // Check for dangerous commands
            let level = DangerousCommandClassifier.classify(tool: tool, input: input)
            if case .dangerous(let reason) = level {
                appendEntry(.dangerousWarning, "WARNING: \(reason)")
                onDangerousCommand?(tool, input, reason)
            }

        case .toolResult(_, let output):
            let preview = String(output.prefix(200))
            appendEntry(.toolOutput, preview)

        case .resultSuccess(let result, let costUSD, let durationMs, _):
            let preview = String(result.prefix(500))
            appendEntry(.finalResult, preview)
            if let cost = costUSD {
                appendEntry(.systemInfo, String(format: "Cost: $%.4f", cost))
            }
            if let duration = durationMs {
                appendEntry(.systemInfo, "Duration: \(duration)ms")
            }
            onProgressEstimate?(1.0)
            onCompleted?(result)

        case .resultError(let error):
            appendEntry(.error, error)
            onFailed?(error)

        case .unknown:
            break
        }
    }

    private func handleTermination(exitCode: Int32) {
        isRunning = false
        if exitCode == 0 {
            appendEntry(.systemInfo, "Process exited successfully")
            onStatusChange?(.completed)
        } else if exitCode == 15 || exitCode == 9 {
            appendEntry(.systemInfo, "Process was cancelled")
            onStatusChange?(.idle)
        } else {
            appendEntry(.error, "Process exited with code: \(exitCode)")
            onStatusChange?(.error)
            onFailed?("Process exited with code: \(exitCode)")
        }
    }

    private func appendEntry(_ kind: CLIOutputEntry.Kind, _ text: String) {
        outputEntries.append(CLIOutputEntry(timestamp: Date(), kind: kind, text: text))
        if outputEntries.count > Self.maxOutputEntries {
            outputEntries.removeFirst(outputEntries.count - Self.maxOutputEntries)
        }
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
        onStatusChange: @escaping (UUID, AgentStatus) -> Void,
        onProgress: @escaping (UUID, Double) -> Void,
        onCompleted: @escaping (UUID, String) -> Void,
        onFailed: @escaping (UUID, String) -> Void,
        onDangerousCommand: ((UUID, UUID, String, String, String) -> Void)? = nil
    ) -> CLIProcess {
        let cliProcess = CLIProcess(
            taskId: taskId,
            agentId: agentId,
            prompt: prompt,
            workingDirectory: workingDirectory
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
