import SwiftUI

/// Reusable row for displaying a SessionSummary in lists
struct SessionRowView: View {
    let summary: SessionSummary
    let onReplay: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top: title + date
            HStack {
                Image(systemName: themeIcon(summary.theme))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .font(.system(size: 14))

                if let title = summary.primaryTaskTitle {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text("Session")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                if summary.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#4CAF50"))
                        .font(.system(size: 11))
                } else {
                    Image(systemName: "circle.dashed")
                        .foregroundColor(Color(hex: "#FF9800"))
                        .font(.system(size: 11))
                }
            }

            // Middle: stats
            HStack(spacing: 12) {
                Text(dateFmt.string(from: summary.startedAt))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Label("\(summary.agentCount)", systemImage: "person.2")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                Label("\(summary.taskCount)", systemImage: "checklist")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                Label("\(summary.eventCount)", systemImage: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                if let dur = summary.duration {
                    Text(formatDuration(dur))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }

            // Bottom: action buttons
            HStack(spacing: 8) {
                Button(action: onReplay) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                        Text("Replay")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#00BCD4").opacity(0.15))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: onExport) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func themeIcon(_ theme: String) -> String {
        switch theme {
        case "commandCenter": return "desktopcomputer"
        case "floatingIslands": return "cloud"
        case "dungeon": return "flame"
        case "spaceStation": return "sparkles"
        case "cyberpunkCity": return "building.2"
        case "medievalCastle": return "building.columns"
        case "underwaterLab": return "drop"
        case "japaneseGarden": return "leaf"
        case "minecraftOverworld": return "square.grid.3x3.fill"
        default: return "cube"
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
}
