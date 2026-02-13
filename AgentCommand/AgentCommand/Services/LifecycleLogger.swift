import Foundation

/// Records lifecycle events for debugging, analytics, and auditing.
@MainActor
class LifecycleLogger: ObservableObject {

    // MARK: - Log Entry

    struct LogEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let agentId: UUID
        let agentName: String?
        let fromState: AgentLifecycleState?
        let toState: AgentLifecycleState
        let event: LifecycleEvent
        let message: String?

        init(
            agentId: UUID,
            agentName: String? = nil,
            fromState: AgentLifecycleState? = nil,
            toState: AgentLifecycleState,
            event: LifecycleEvent,
            message: String? = nil
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.agentId = agentId
            self.agentName = agentName
            self.fromState = fromState
            self.toState = toState
            self.event = event
            self.message = message
        }
    }

    // MARK: - Properties

    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries: Int

    // MARK: - Metrics

    struct Metrics {
        var totalTransitions: Int = 0
        var invalidTransitions: Int = 0
        var emergencyCleanups: Int = 0
        var transitionsPerState: [AgentLifecycleState: Int] = [:]
    }

    @Published private(set) var metrics = Metrics()

    // MARK: - Init

    init(maxEntries: Int = 500) {
        self.maxEntries = maxEntries
    }

    // MARK: - Logging

    func logTransition(
        agentId: UUID,
        agentName: String? = nil,
        from fromState: AgentLifecycleState,
        to toState: AgentLifecycleState,
        event: LifecycleEvent,
        message: String? = nil
    ) {
        let entry = LogEntry(
            agentId: agentId,
            agentName: agentName,
            fromState: fromState,
            toState: toState,
            event: event,
            message: message
        )

        appendEntry(entry)

        metrics.totalTransitions += 1
        metrics.transitionsPerState[toState, default: 0] += 1

        #if DEBUG
        let name = agentName ?? agentId.uuidString.prefix(8).description
        print("[Lifecycle] \(name): \(fromState.rawValue) --[\(event.rawValue)]--> \(toState.rawValue)\(message.map { " | \($0)" } ?? "")")
        #endif
    }

    func logInvalidTransition(
        agentId: UUID,
        agentName: String? = nil,
        currentState: AgentLifecycleState,
        event: LifecycleEvent,
        reason: String? = nil
    ) {
        let msg = reason ?? "No valid transition"
        let entry = LogEntry(
            agentId: agentId,
            agentName: agentName,
            fromState: currentState,
            toState: currentState,
            event: event,
            message: "INVALID: \(msg)"
        )

        appendEntry(entry)
        metrics.invalidTransitions += 1

        #if DEBUG
        let name = agentName ?? agentId.uuidString.prefix(8).description
        print("[Lifecycle] INVALID \(name): \(currentState.rawValue) + \(event.rawValue) | \(msg)")
        #endif
    }

    func logEmergencyCleanup(agentCount: Int, reason: String) {
        metrics.emergencyCleanups += 1

        #if DEBUG
        print("[Lifecycle] EMERGENCY CLEANUP: \(agentCount) agents | \(reason)")
        #endif
    }

    func logResourcePressureChange(from: ResourcePressure, to: ResourcePressure) {
        #if DEBUG
        print("[Lifecycle] Resource pressure: \(from.rawValue) -> \(to.rawValue)")
        #endif
    }

    // MARK: - Query

    func entries(for agentId: UUID) -> [LogEntry] {
        entries.filter { $0.agentId == agentId }
    }

    func recentEntries(count: Int = 50) -> [LogEntry] {
        Array(entries.suffix(count))
    }

    // MARK: - Cleanup

    func clear() {
        entries.removeAll()
        metrics = Metrics()
    }

    // MARK: - Private

    private func appendEntry(_ entry: LogEntry) {
        entries.append(entry)
        // Batch eviction: remove 20% extra to amortize removeFirst cost
        let overflow = entries.count - maxEntries
        if overflow > 0 {
            let batchSize = overflow + max(1, maxEntries / 5)
            entries.removeFirst(min(batchSize, entries.count))
        }
    }
}
