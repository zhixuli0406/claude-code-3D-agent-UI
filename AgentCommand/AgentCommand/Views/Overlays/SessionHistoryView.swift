import SwiftUI

/// Main sheet for session history browsing, search, and replay controls (D4)
struct SessionHistoryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SessionHistoryTab = .history
    @State private var searchText: String = ""
    @State private var deleteConfirmId: UUID?

    enum SessionHistoryTab: String, CaseIterable {
        case history, search, replay

        var icon: String {
            switch self {
            case .history: return "clock.arrow.circlepath"
            case .search: return "magnifyingglass"
            case .replay: return "play.circle"
            }
        }

        var title: String {
            switch self {
            case .history: return "History"
            case .search: return "Search"
            case .replay: return "Replay"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            tabBar
            Divider().background(Color.white.opacity(0.1))

            switch selectedTab {
            case .history:
                historyTab
            case .search:
                searchTab
            case .replay:
                replayTab
            }
        }
        .frame(width: 520, height: 600)
        .background(Color(hex: "#0D1117"))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(Color(hex: "#00BCD4"))
                .font(.title2)

            Text(localization.localized(.sessionHistory))
                .font(.headline)
                .foregroundColor(.white)

            if appState.sessionHistoryManager.isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text(localization.localized(.sessionRecording))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .cornerRadius(4)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SessionHistoryTab.allCases, id: \.self) { tab in
                // Hide replay tab unless actively replaying
                if tab != .replay || appState.sessionHistoryManager.replayState != .idle {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? Color(hex: "#00BCD4") : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color(hex: "#00BCD4").opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()

            Text("\(appState.sessionHistoryManager.sessionIndex.count) sessions")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - History Tab

    private var historyTab: some View {
        Group {
            if appState.sessionHistoryManager.sessionIndex.isEmpty {
                emptyState(icon: "tray", text: localization.localized(.noSessions))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.sessionHistoryManager.sessionIndex) { summary in
                            SessionRowView(
                                summary: summary,
                                onReplay: {
                                    startReplay(sessionId: summary.id)
                                },
                                onExport: {
                                    exportSession(sessionId: summary.id)
                                },
                                onDelete: {
                                    deleteConfirmId = summary.id
                                }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .alert(localization.localized(.confirmDeleteSession), isPresented: Binding(
            get: { deleteConfirmId != nil },
            set: { if !$0 { deleteConfirmId = nil } }
        )) {
            Button(localization.localized(.deleteSession), role: .destructive) {
                if let id = deleteConfirmId {
                    appState.sessionHistoryManager.deleteSession(id)
                }
                deleteConfirmId = nil
            }
            Button(localization.localized(.cancel), role: .cancel) {
                deleteConfirmId = nil
            }
        }
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(localization.localized(.searchPlaceholder), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .onSubmit {
                        appState.sessionHistoryManager.search(searchText)
                    }
                    .onChange(of: searchText) { _, newValue in
                        appState.sessionHistoryManager.search(newValue)
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        appState.sessionHistoryManager.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)
            .padding(12)

            // Results
            if appState.sessionHistoryManager.searchResults.isEmpty && !searchText.isEmpty {
                emptyState(icon: "doc.text.magnifyingglass", text: localization.localized(.noSearchResults))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.sessionHistoryManager.searchResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                SessionRowView(
                                    summary: result.sessionSummary,
                                    onReplay: {
                                        startReplay(sessionId: result.sessionSummary.id)
                                    },
                                    onExport: {
                                        exportSession(sessionId: result.sessionSummary.id)
                                    },
                                    onDelete: {
                                        appState.sessionHistoryManager.deleteSession(result.sessionSummary.id)
                                    }
                                )

                                // Match context
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.system(size: 9))
                                    Text(result.matchContext)
                                        .font(.system(size: 10, design: .monospaced))
                                        .lineLimit(1)
                                }
                                .foregroundColor(Color(hex: "#00BCD4").opacity(0.7))
                                .padding(.leading, 16)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Replay Tab

    private var replayTab: some View {
        VStack(spacing: 16) {
            if let session = appState.sessionHistoryManager.replaySession {
                // Session info
                VStack(alignment: .leading, spacing: 8) {
                    if let title = session.tasks.first?.title {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 16) {
                        Label(session.theme, systemImage: "paintpalette")
                        Label("\(session.agents.count) agents", systemImage: "person.2")
                        Label("\(session.timelineEvents.count) events", systemImage: "clock")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)

                // Controls
                VStack(spacing: 12) {
                    // Play/Pause + Stop
                    HStack(spacing: 16) {
                        Button(action: {
                            switch appState.sessionHistoryManager.replayState {
                            case .playing:
                                appState.sessionHistoryManager.pauseReplay()
                            case .paused, .finished:
                                if appState.sessionHistoryManager.replayState == .finished {
                                    appState.sessionHistoryManager.seekTo(progress: 0)
                                }
                                appState.sessionHistoryManager.resumeReplay()
                            default:
                                break
                            }
                        }) {
                            Image(systemName: appState.sessionHistoryManager.replayState == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "#00BCD4"))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            appState.stopSessionReplay()
                            selectedTab = .history
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }

                    // Progress bar
                    VStack(spacing: 4) {
                        ProgressView(value: appState.sessionHistoryManager.replayProgress)
                            .tint(Color(hex: "#00BCD4"))

                        HStack {
                            if let time = appState.sessionHistoryManager.replayCurrentTime {
                                Text(formatTime(time))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Text("\(appState.sessionHistoryManager.replayEventIndex)/\(session.timelineEvents.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Speed selector
                    HStack(spacing: 4) {
                        Text(localization.localized(.replaySpeed))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        ForEach([0.5, 1.0, 2.0, 4.0, 8.0], id: \.self) { speed in
                            Button(action: {
                                appState.sessionHistoryManager.setReplaySpeed(speed)
                            }) {
                                Text(speed == 1.0 ? "1x" : speed < 1 ? "\(String(format: "%.1f", speed))x" : "\(Int(speed))x")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(appState.sessionHistoryManager.replaySpeed == speed ? Color(hex: "#00BCD4") : .white.opacity(0.5))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(appState.sessionHistoryManager.replaySpeed == speed ? Color(hex: "#00BCD4").opacity(0.15) : Color.white.opacity(0.05))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                )

                // Recent events log
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Log")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            let visibleEvents = Array(session.timelineEvents.prefix(appState.sessionHistoryManager.replayEventIndex))
                            ForEach(visibleEvents.suffix(20)) { event in
                                HStack(spacing: 6) {
                                    Image(systemName: event.kind.icon)
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: event.kind.hexColor))
                                        .frame(width: 12)
                                    Text(formatTime(event.timestamp))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(event.title)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                )
            } else {
                emptyState(icon: "play.circle", text: "Select a session to replay")
            }

            Spacer()
        }
        .padding(12)
    }

    // MARK: - Helpers

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.15))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func startReplay(sessionId: UUID) {
        guard let session = appState.sessionHistoryManager.loadSession(sessionId) else { return }
        appState.startSessionReplay(session)
        selectedTab = .replay
    }

    private func exportSession(sessionId: UUID) {
        guard let session = appState.sessionHistoryManager.loadSession(sessionId) else { return }
        appState.sessionHistoryManager.exportSession(session)
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }
}
