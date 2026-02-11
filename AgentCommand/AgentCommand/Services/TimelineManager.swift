import Foundation

@MainActor
class TimelineManager: ObservableObject {
    @Published var events: [TimelineEvent] = []
    @Published var filter: TimelineFilter = TimelineFilter()
    @Published var scrollToEntryId: UUID?
    @Published var selectedEventId: UUID?

    private let maxEvents = 5000

    func recordEvent(
        kind: TimelineEventKind,
        taskId: UUID? = nil,
        agentId: UUID? = nil,
        title: String,
        detail: String? = nil,
        cliEntryId: UUID? = nil
    ) {
        let event = TimelineEvent(
            id: UUID(),
            timestamp: Date(),
            kind: kind,
            taskId: taskId,
            agentId: agentId,
            title: title,
            detail: detail,
            cliEntryId: cliEntryId
        )
        events.append(event)

        // Cap event count
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    var filteredEvents: [TimelineEvent] {
        events.filter { event in
            let passAgent = filter.agentIds.isEmpty || (event.agentId.map { filter.agentIds.contains($0) } ?? true)
            let passKind = filter.eventKinds.isEmpty || filter.eventKinds.contains(event.kind)
            return passAgent && passKind
        }
    }

    var timeRange: ClosedRange<Date>? {
        guard let first = events.first?.timestamp,
              let last = events.last?.timestamp else { return nil }
        return first...max(last, first.addingTimeInterval(60))
    }

    func exportMarkdown(agents: [Agent], tasks: [AgentTask]) -> String {
        var md = "# Agent Command Timeline Report\n\n"
        md += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        md += "## Events (\(filteredEvents.count))\n\n"
        md += "| Time | Event | Agent | Task | Detail |\n"
        md += "|------|-------|-------|------|--------|\n"

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"

        for event in filteredEvents {
            let time = fmt.string(from: event.timestamp)
            let agentName = event.agentId.flatMap { id in agents.first { $0.id == id }?.name } ?? "-"
            let taskTitle = event.taskId.flatMap { id in tasks.first { $0.id == id }?.title } ?? "-"
            let detail = event.detail ?? "-"
            md += "| \(time) | \(event.kind.displayName) | \(agentName) | \(taskTitle) | \(detail) |\n"
        }

        return md
    }
}
