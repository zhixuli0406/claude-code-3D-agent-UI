import Foundation
import Combine
import AppKit

/// Manages session recording, persistence, search, replay, and export (D4)
@MainActor
class SessionHistoryManager: ObservableObject {
    // MARK: - Published State

    @Published var sessionIndex: [SessionSummary] = []
    @Published var currentSessionId: UUID?
    @Published var isRecording: Bool = false

    // Replay state
    @Published var replaySession: SessionRecord?
    @Published var replayState: ReplayState = .idle
    @Published var replayProgress: Double = 0.0
    @Published var replaySpeed: Double = 1.0
    @Published var replayCurrentTime: Date?
    @Published var replayEventIndex: Int = 0

    // Search
    @Published var searchQuery: String = ""
    @Published var searchResults: [SessionSearchResult] = []

    private var currentRecord: SessionRecord?
    private var replayTimer: Timer?
    private var onReplayEvent: ((TimelineEvent) -> Void)?

    private static let maxSessions = 100
    private static let maxCLIEntriesPerTask = 200

    enum ReplayState: Equatable {
        case idle
        case playing
        case paused
        case finished
    }

    // MARK: - File Paths

    private var sessionsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("AgentCommand/Sessions", isDirectory: true)
    }

    private var indexFileURL: URL {
        sessionsDirectory.appendingPathComponent("index.json")
    }

    private func sessionFileURL(_ id: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("session-\(id.uuidString).json")
    }

    // MARK: - Init

    init() {
        ensureDirectoryExists()
        loadIndex()
    }

    // MARK: - Recording API

    func startSession(theme: String, agents: [Agent], sceneConfig: SceneConfiguration?) {
        let sessionId = UUID()
        currentSessionId = sessionId
        isRecording = true

        let record = SessionRecord(
            id: sessionId,
            startedAt: Date(),
            endedAt: nil,
            theme: theme,
            agents: agents,
            tasks: [],
            timelineEvents: [],
            cliOutputs: [:],
            sceneConfig: sceneConfig
        )
        currentRecord = record

        let summary = SessionSummary(
            id: sessionId,
            startedAt: Date(),
            endedAt: nil,
            theme: theme,
            taskCount: 0,
            agentCount: agents.count,
            eventCount: 0,
            primaryTaskTitle: nil,
            isComplete: false
        )
        sessionIndex.insert(summary, at: 0)
        saveIndex()
    }

    func updateSession(agents: [Agent], tasks: [AgentTask], timelineEvents: [TimelineEvent], cliOutputs: [UUID: [CLIOutputEntry]]) {
        guard var record = currentRecord else { return }

        record.agents = agents
        record.tasks = tasks
        record.timelineEvents = timelineEvents

        // Cap CLI entries per task
        var capped: [UUID: [CLIOutputEntry]] = [:]
        for (taskId, entries) in cliOutputs {
            capped[taskId] = Array(entries.suffix(Self.maxCLIEntriesPerTask))
        }
        record.setCLIOutputs(capped)

        currentRecord = record

        // Update index summary
        if let idx = sessionIndex.firstIndex(where: { $0.id == record.id }) {
            sessionIndex[idx].taskCount = tasks.count
            sessionIndex[idx].agentCount = agents.count
            sessionIndex[idx].eventCount = timelineEvents.count
            if sessionIndex[idx].primaryTaskTitle == nil, let first = tasks.first {
                sessionIndex[idx].primaryTaskTitle = first.title
            }
        }

        // Auto-save to disk
        saveSessionRecord(record)
        saveIndex()
    }

    func endSession(agents: [Agent], tasks: [AgentTask], timelineEvents: [TimelineEvent], cliOutputs: [UUID: [CLIOutputEntry]]) {
        guard var record = currentRecord else { return }

        record.endedAt = Date()
        record.agents = agents
        record.tasks = tasks
        record.timelineEvents = timelineEvents

        var capped: [UUID: [CLIOutputEntry]] = [:]
        for (taskId, entries) in cliOutputs {
            capped[taskId] = Array(entries.suffix(Self.maxCLIEntriesPerTask))
        }
        record.setCLIOutputs(capped)

        currentRecord = nil
        currentSessionId = nil
        isRecording = false

        // Update index
        if let idx = sessionIndex.firstIndex(where: { $0.id == record.id }) {
            sessionIndex[idx].endedAt = record.endedAt
            sessionIndex[idx].isComplete = true
            sessionIndex[idx].taskCount = tasks.count
            sessionIndex[idx].agentCount = agents.count
            sessionIndex[idx].eventCount = timelineEvents.count
        }

        saveSessionRecord(record)
        saveIndex()
        pruneOldSessions()
    }

    // MARK: - Session List & Loading

    func loadSession(_ id: UUID) -> SessionRecord? {
        loadSessionRecord(id)
    }

    func deleteSession(_ id: UUID) {
        sessionIndex.removeAll { $0.id == id }
        let fileURL = sessionFileURL(id)
        try? FileManager.default.removeItem(at: fileURL)
        saveIndex()
    }

    // MARK: - Search

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        var results: [SessionSearchResult] = []

        for summary in sessionIndex {
            // Check summary fields first
            if let title = summary.primaryTaskTitle, title.lowercased().contains(trimmed) {
                results.append(SessionSearchResult(
                    sessionSummary: summary,
                    matchingEvents: [],
                    matchContext: "Task: \(title)"
                ))
                continue
            }

            // Load full session and search deeper
            guard let session = loadSessionRecord(summary.id) else { continue }

            var matchEvents: [TimelineEvent] = []
            var context = ""

            // Search task titles
            for task in session.tasks {
                if task.title.lowercased().contains(trimmed) {
                    context = "Task: \(task.title)"
                    break
                }
            }

            // Search timeline events
            if context.isEmpty {
                for event in session.timelineEvents {
                    if event.title.lowercased().contains(trimmed) || (event.detail?.lowercased().contains(trimmed) ?? false) {
                        matchEvents.append(event)
                        if context.isEmpty {
                            context = "Event: \(event.title)"
                        }
                    }
                }
            }

            // Search CLI output
            if context.isEmpty {
                outer: for (_, entries) in session.cliOutputs {
                    for entry in entries {
                        if entry.text.lowercased().contains(trimmed) {
                            context = "CLI: \(String(entry.text.prefix(80)))"
                            break outer
                        }
                    }
                }
            }

            if !context.isEmpty {
                results.append(SessionSearchResult(
                    sessionSummary: summary,
                    matchingEvents: Array(matchEvents.prefix(5)),
                    matchContext: context
                ))
            }
        }

        searchResults = results
    }

    // MARK: - Replay

    func startReplay(session: SessionRecord, onEvent: @escaping (TimelineEvent) -> Void) {
        stopReplay()

        replaySession = session
        replayState = .playing
        replayProgress = 0.0
        replayEventIndex = 0
        replayCurrentTime = session.timelineEvents.first?.timestamp ?? session.startedAt
        onReplayEvent = onEvent

        scheduleNextEvent()
    }

    func pauseReplay() {
        replayState = .paused
        replayTimer?.invalidate()
        replayTimer = nil
    }

    func resumeReplay() {
        guard replayState == .paused else { return }
        replayState = .playing
        scheduleNextEvent()
    }

    func stopReplay() {
        replayTimer?.invalidate()
        replayTimer = nil
        replayState = .idle
        replaySession = nil
        replayProgress = 0.0
        replayEventIndex = 0
        replayCurrentTime = nil
        onReplayEvent = nil
    }

    func seekTo(progress: Double) {
        guard let session = replaySession else { return }
        let totalEvents = session.timelineEvents.count
        guard totalEvents > 0 else { return }

        let targetIndex = min(Int(progress * Double(totalEvents)), totalEvents - 1)

        // Apply all events up to target instantly
        for i in 0...targetIndex {
            onReplayEvent?(session.timelineEvents[i])
        }

        replayEventIndex = targetIndex + 1
        replayProgress = Double(replayEventIndex) / Double(totalEvents)
        replayCurrentTime = session.timelineEvents[targetIndex].timestamp

        if replayState == .playing {
            replayTimer?.invalidate()
            scheduleNextEvent()
        }
    }

    func setReplaySpeed(_ speed: Double) {
        replaySpeed = speed
        if replayState == .playing {
            replayTimer?.invalidate()
            scheduleNextEvent()
        }
    }

    private func scheduleNextEvent() {
        guard replayState == .playing,
              let session = replaySession,
              replayEventIndex < session.timelineEvents.count else {
            if replayEventIndex >= (replaySession?.timelineEvents.count ?? 0), replaySession != nil {
                replayState = .finished
            }
            return
        }

        let currentIndex = replayEventIndex
        let currentEvent = session.timelineEvents[currentIndex]

        // Emit current event
        onReplayEvent?(currentEvent)
        replayCurrentTime = currentEvent.timestamp

        let nextIndex = currentIndex + 1
        replayEventIndex = nextIndex
        replayProgress = Double(nextIndex) / Double(session.timelineEvents.count)

        guard nextIndex < session.timelineEvents.count else {
            replayState = .finished
            return
        }

        // Calculate delay to next event
        let nextEvent = session.timelineEvents[nextIndex]
        let rawDelay = nextEvent.timestamp.timeIntervalSince(currentEvent.timestamp)
        let delay = max(rawDelay / replaySpeed, 0.016) // minimum 1 frame at 60fps

        replayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleNextEvent()
            }
        }
    }

    // MARK: - Export

    func exportMarkdown(session: SessionRecord) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .long
        dateFmt.timeStyle = .medium

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss"

        var md = "# Agent Command Session Report\n\n"

        md += "**Session ID:** \(session.id.uuidString)\n"
        md += "**Started:** \(dateFmt.string(from: session.startedAt))\n"
        if let ended = session.endedAt {
            md += "**Ended:** \(dateFmt.string(from: ended))\n"
            let dur = ended.timeIntervalSince(session.startedAt)
            md += "**Duration:** \(formatDuration(dur))\n"
        }
        md += "**Theme:** \(session.theme)\n"
        md += "**Agents:** \(session.agents.count)\n"
        md += "**Tasks:** \(session.tasks.count)\n\n"

        // Agents
        md += "## Agents\n\n"
        for agent in session.agents {
            md += "- **\(agent.name)** (\(agent.role.rawValue)) - \(agent.status.rawValue)\n"
        }
        md += "\n"

        // Tasks
        md += "## Tasks\n\n"
        for task in session.tasks {
            md += "### \(task.title)\n"
            md += "- Status: \(task.status.rawValue)\n"
            md += "- Priority: \(task.priority.rawValue)\n"
            if let result = task.cliResult {
                md += "- Result: \(String(result.prefix(200)))\n"
            }
            md += "\n"
        }

        // Timeline
        md += "## Timeline Events (\(session.timelineEvents.count))\n\n"
        md += "| Time | Event | Agent | Task | Detail |\n"
        md += "|------|-------|-------|------|--------|\n"

        for event in session.timelineEvents {
            let time = timeFmt.string(from: event.timestamp)
            let agentName = event.agentId.flatMap { id in session.agents.first { $0.id == id }?.name } ?? "-"
            let taskTitle = event.taskId.flatMap { id in session.tasks.first { $0.id == id }?.title } ?? "-"
            let detail = event.detail ?? "-"
            md += "| \(time) | \(event.kind.displayName) | \(agentName) | \(taskTitle) | \(detail) |\n"
        }

        // CLI Output
        let outputs = session.getCLIOutputs()
        if !outputs.isEmpty {
            md += "\n## CLI Output\n\n"
            for (taskId, entries) in outputs {
                let taskTitle = session.tasks.first { $0.id == taskId }?.title ?? taskId.uuidString
                md += "### Task: \(taskTitle)\n\n"
                md += "```\n"
                for entry in entries.prefix(200) {
                    md += "[\(timeFmt.string(from: entry.timestamp))] [\(entry.kind.rawValue)] \(entry.text)\n"
                }
                if entries.count > 200 {
                    md += "... (\(entries.count - 200) more entries truncated)\n"
                }
                md += "```\n\n"
            }
        }

        return md
    }

    func exportSession(_ session: SessionRecord) {
        let markdown = exportMarkdown(session: session)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "session-report-\(session.id.uuidString.prefix(8)).md"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }

    // MARK: - Persistence Helpers

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexFileURL),
              let decoded = try? JSONDecoder().decode([SessionSummary].self, from: data) else {
            sessionIndex = []
            return
        }
        sessionIndex = decoded
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(sessionIndex) else { return }
        try? data.write(to: indexFileURL, options: .atomic)
    }

    private func saveSessionRecord(_ record: SessionRecord) {
        let url = sessionFileURL(record.id)
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadSessionRecord(_ id: UUID) -> SessionRecord? {
        let url = sessionFileURL(id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SessionRecord.self, from: data)
    }

    private func pruneOldSessions() {
        guard sessionIndex.count > Self.maxSessions else { return }
        let sorted = sessionIndex.sorted { $0.startedAt > $1.startedAt }
        let toRemove = sorted.suffix(from: Self.maxSessions)
        for summary in toRemove {
            try? FileManager.default.removeItem(at: sessionFileURL(summary.id))
        }
        sessionIndex = Array(sorted.prefix(Self.maxSessions))
        saveIndex()
    }
}
