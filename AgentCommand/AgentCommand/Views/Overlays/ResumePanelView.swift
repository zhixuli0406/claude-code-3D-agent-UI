import SwiftUI

/// Panel shown at app launch when there are suspended agents from a previous session.
/// Allows users to resume or discard each suspended agent.
struct ResumePanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Suspended Agents")
                    .font(.headline)
                Spacer()
                Text("\(appState.pendingResumes.count) pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    appState.showResumePanel = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))

            Divider()

            // List of pending resumes
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.pendingResumes) { context in
                        ResumeContextRow(context: context)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 300)

            Divider()

            // Footer actions
            HStack {
                Button("Discard All") {
                    for context in appState.pendingResumes {
                        appState.discardSuspendedAgent(context)
                    }
                }
                .foregroundColor(.red)

                Spacer()

                Button("Resume All") {
                    for context in appState.pendingResumes {
                        appState.resumeSuspendedAgent(context)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.2))
        }
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

struct ResumeContextRow: View {
    let context: ResumeContext
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Role icon
            VStack {
                Text(context.agentRole.emoji)
                    .font(.title2)
                Circle()
                    .fill(Color(hex: "#FFC107") ?? .yellow)
                    .frame(width: 8, height: 8)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.agentName)
                    .font(.system(.body, design: .monospaced, weight: .semibold))

                Text(context.taskTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(context.suspensionReason.displayName, systemImage: context.suspensionReason.icon)
                        .font(.caption2)
                        .foregroundColor(.orange)

                    Text(context.suspendedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 6) {
                Button {
                    appState.resumeSuspendedAgent(context)
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)

                Button {
                    appState.discardSuspendedAgent(context)
                } label: {
                    Label("Discard", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SuspensionReason UI Helpers

extension SuspensionReason {
    var displayName: String {
        switch self {
        case .userQuestion: return "User Question"
        case .planReview: return "Plan Review"
        case .permissionDenied: return "Permission Denied"
        case .userPaused: return "Paused"
        case .appTerminated: return "App Terminated"
        case .processTimeout: return "Timeout"
        }
    }

    var icon: String {
        switch self {
        case .userQuestion: return "questionmark.circle"
        case .planReview: return "doc.text.magnifyingglass"
        case .permissionDenied: return "hand.raised"
        case .userPaused: return "pause.circle"
        case .appTerminated: return "power"
        case .processTimeout: return "clock.badge.exclamationmark"
        }
    }
}
