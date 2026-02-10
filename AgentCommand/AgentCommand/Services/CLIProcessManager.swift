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
    private var outputPipe: Pipe?
    private var readTask: Task<Void, Never>?

    // Callbacks
    var onStatusChange: ((AgentStatus) -> Void)?
    var onProgressEstimate: ((Double) -> Void)?
    var onCompleted: ((String) -> Void)?
    var onFailed: ((String) -> Void)?

    private static let maxOutputEntries = 500

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
        process.arguments = extraArgs + ["-p", "--output-format", "stream-json", prompt]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Inherit PATH for tool execution
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = ["/usr/local/bin", "/opt/homebrew/bin",
                               "\(NSHomeDirectory())/.local/bin",
                               "\(NSHomeDirectory())/.nvm/versions/node/*/bin"]
        if let existingPath = env["PATH"] {
            env["PATH"] = (additionalPaths + [existingPath]).joined(separator: ":")
        }
        process.environment = env

        self.process = process
        self.outputPipe = outputPipe

        isRunning = true
        onStatusChange?(.working)
        appendEntry(.systemInfo, "Process started: \(prompt)")

        // Read stdout in background
        readTask = Task.detached { [weak self] in
            await self?.readOutputStream(pipe: outputPipe)
        }

        // Handle termination
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.handleTermination(exitCode: proc.terminationStatus)
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
        readTask?.cancel()
        appendEntry(.systemInfo, "Process cancelled by user")
    }

    // MARK: - Private

    private func readOutputStream(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        var buffer = Data()

        while !Task.isCancelled {
            let data = handle.availableData
            if data.isEmpty { break } // EOF

            buffer.append(data)

            // Split by newlines to get complete JSON lines
            while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                guard !lineData.isEmpty else { continue }

                await MainActor.run {
                    self.processLine(lineData)
                }
            }
        }

        // Process remaining buffer
        if !buffer.isEmpty {
            await MainActor.run {
                self.processLine(buffer)
            }
        }
    }

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

        case .assistantToolUse(let tool, _):
            toolCallCount += 1
            appendEntry(.toolInvocation, "Using tool: \(tool)")
            onStatusChange?(.working)
            let estimatedProgress = min(Double(toolCallCount) / 20.0, 0.9)
            onProgressEstimate?(estimatedProgress)

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
        // Trim old entries
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
        // Fallback: use /usr/bin/env to resolve from PATH
        return (URL(fileURLWithPath: "/usr/bin/env"), ["claude"])
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
        onFailed: @escaping (UUID, String) -> Void
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
