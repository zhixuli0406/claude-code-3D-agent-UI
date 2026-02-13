import Foundation

/// Manages persistence of agent state, resume contexts, and task queues to disk.
/// Storage location: ~/Library/Application Support/AgentCommand/AgentState/
@MainActor
class AgentPersistenceManager: ObservableObject {

    private let baseDir: URL
    private let snapshotURL: URL
    private let pendingResumesDir: URL
    private let taskQueueDir: URL

    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 30.0

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("AgentCommand")

        baseDir = appSupport.appendingPathComponent("AgentState")
        snapshotURL = baseDir.appendingPathComponent("snapshot.json")
        pendingResumesDir = baseDir.appendingPathComponent("pending-resumes")
        taskQueueDir = baseDir.appendingPathComponent("task-queue")

        createDirectories()
    }

    private func createDirectories() {
        let fm = FileManager.default
        for dir in [baseDir, pendingResumesDir, taskQueueDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Resume Context

    func saveResumeContext(_ context: ResumeContext) {
        let url = pendingResumesDir.appendingPathComponent("\(context.agentId.uuidString).json")
        do {
            let data = try encoder.encode(context)
            try data.write(to: url, options: .atomic)
            print("[Persistence] Saved resume context for agent \(context.agentName) (\(context.agentId))")
        } catch {
            print("[Persistence] Failed to save resume context: \(error)")
        }
    }

    func loadResumeContext(agentId: UUID) -> ResumeContext? {
        let url = pendingResumesDir.appendingPathComponent("\(agentId.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ResumeContext.self, from: data)
    }

    func removeResumeContext(agentId: UUID) {
        let url = pendingResumesDir.appendingPathComponent("\(agentId.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        print("[Persistence] Removed resume context for agent \(agentId)")
    }

    func allPendingResumes() -> [ResumeContext] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: pendingResumesDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let contexts = files.compactMap { url -> ResumeContext? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(ResumeContext.self, from: data)
        }

        return contexts.sorted { $0.suspendedAt > $1.suspendedAt }
    }

    func clearAllResumeContexts() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: pendingResumesDir,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - State Snapshot

    func saveSnapshot(_ snapshot: AgentStateSnapshot) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: .atomic)
            print("[Persistence] Saved state snapshot (\(snapshot.agents.count) agents, \(snapshot.tasks.count) tasks)")
        } catch {
            print("[Persistence] Failed to save snapshot: \(error)")
        }
    }

    func loadSnapshot() -> AgentStateSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        do {
            let snapshot = try decoder.decode(AgentStateSnapshot.self, from: data)
            print("[Persistence] Loaded snapshot from \(snapshot.savedAt)")
            return snapshot
        } catch {
            print("[Persistence] Failed to decode snapshot: \(error)")
            return nil
        }
    }

    func removeSnapshot() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }

    // MARK: - Task Queue

    func saveTaskQueue(commanderId: UUID, items: [SubAgentTaskQueueItem]) {
        let url = taskQueueDir.appendingPathComponent("\(commanderId.uuidString).json")
        do {
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[Persistence] Failed to save task queue: \(error)")
        }
    }

    func loadTaskQueue(commanderId: UUID) -> [SubAgentTaskQueueItem] {
        let url = taskQueueDir.appendingPathComponent("\(commanderId.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([SubAgentTaskQueueItem].self, from: data)) ?? []
    }

    func removeTaskQueue(commanderId: UUID) {
        let url = taskQueueDir.appendingPathComponent("\(commanderId.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    func allTaskQueues() -> [UUID: [SubAgentTaskQueueItem]] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: taskQueueDir,
            includingPropertiesForKeys: nil
        ) else { return [:] }

        var result: [UUID: [SubAgentTaskQueueItem]] = [:]
        for file in files where file.pathExtension == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            guard let uuid = UUID(uuidString: name),
                  let data = try? Data(contentsOf: file),
                  let items = try? decoder.decode([SubAgentTaskQueueItem].self, from: data) else { continue }
            result[uuid] = items
        }
        return result
    }

    // MARK: - Auto-Save

    func startAutoSave(snapshotProvider: @escaping () -> AgentStateSnapshot?) {
        stopAutoSave()
        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: autoSaveInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let snapshot = snapshotProvider() else { return }
                self?.saveSnapshot(snapshot)
            }
        }
        print("[Persistence] Auto-save started (interval: \(autoSaveInterval)s)")
    }

    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
}
