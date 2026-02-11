import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var timelineManager: TimelineManager

    private let pixelsPerSecond: CGFloat = 8.0
    private let barHeight: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            TimelineFilterBar(
                filter: $timelineManager.filter,
                agents: appState.agents,
                onExport: { appState.exportTimeline() }
            )

            // Timeline bar
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .leading) {
                        // Time axis line
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 1)
                            .frame(width: max(totalWidth, 300))
                            .offset(y: barHeight / 2 - 5)

                        // Time markers
                        timeMarkers

                        // Event dots
                        ForEach(timelineManager.filteredEvents) { event in
                            TimelineEventDot(
                                event: event,
                                isSelected: event.id == timelineManager.selectedEventId,
                                onTap: { handleEventTap(event) }
                            )
                            .offset(x: xPosition(for: event.timestamp), y: 0)
                            .id(event.id)
                        }
                    }
                    .frame(height: barHeight)
                    .padding(.horizontal, 16)
                }
                .onChange(of: timelineManager.events.count) { _, _ in
                    if let last = timelineManager.filteredEvents.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .trailing)
                        }
                    }
                }
            }
            .frame(height: barHeight)
            .background(Color(hex: "#0D1117").opacity(0.95))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#00BCD4").opacity(0.15)),
                alignment: .top
            )
        }
    }

    private func handleEventTap(_ event: TimelineEvent) {
        timelineManager.selectedEventId = event.id

        if let taskId = event.taskId {
            appState.selectTask(taskId)
        }
        if let agentId = event.agentId {
            appState.selectAgent(agentId)
        }
        timelineManager.scrollToEntryId = event.cliEntryId
    }

    private var totalWidth: CGFloat {
        guard let range = timelineManager.timeRange else { return 300 }
        return CGFloat(range.upperBound.timeIntervalSince(range.lowerBound)) * pixelsPerSecond + 32
    }

    private func xPosition(for date: Date) -> CGFloat {
        guard let start = timelineManager.timeRange?.lowerBound else { return 0 }
        return CGFloat(date.timeIntervalSince(start)) * pixelsPerSecond
    }

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt
    }()

    @ViewBuilder
    private var timeMarkers: some View {
        if let range = timelineManager.timeRange {
            let duration = range.upperBound.timeIntervalSince(range.lowerBound)
            let interval = markerInterval(for: duration)
            let startTime = range.lowerBound
            let count = Int(duration / interval) + 1

            ForEach(0..<count, id: \.self) { i in
                let date = startTime.addingTimeInterval(Double(i) * interval)
                let x = CGFloat(Double(i) * interval) * pixelsPerSecond

                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 8)
                    Text(Self.timeFormatter.string(from: date))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                .offset(x: x, y: barHeight / 2 + 2)
            }
        }
    }

    private func markerInterval(for duration: TimeInterval) -> TimeInterval {
        if duration < 60 { return 10 }
        if duration < 300 { return 30 }
        if duration < 600 { return 60 }
        if duration < 3600 { return 300 }
        return 600
    }
}
