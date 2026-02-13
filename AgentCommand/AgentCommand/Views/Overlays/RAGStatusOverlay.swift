import SwiftUI

/// Floating RAG index status panel (H1)
struct RAGStatusOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            indexStats
            if appState.ragManager.isIndexing {
                indexProgressSection
            }
            actionButtons
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#9C27B0").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#9C27B0"))
            Text(localization.localized(.ragKnowledgeBase).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Circle()
                .fill(appState.ragManager.isIndexing ? Color.orange : Color(hex: "#9C27B0"))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    // MARK: - Index Stats

    private var indexStats: some View {
        VStack(spacing: 6) {
            metricRow(
                icon: "doc.text",
                label: localization.localized(.ragDocuments),
                value: "\(appState.ragManager.indexStats.totalDocuments)",
                color: Color(hex: "#9C27B0")
            )

            metricRow(
                icon: "text.alignleft",
                label: localization.localized(.ragTotalLines),
                value: formatNumber(appState.ragManager.indexStats.totalLines),
                color: .cyan
            )

            metricRow(
                icon: "internaldrive",
                label: localization.localized(.ragDatabaseSize),
                value: appState.ragManager.indexStats.formattedSize,
                color: .blue
            )

            metricRow(
                icon: "arrow.triangle.branch",
                label: localization.localized(.ragRelationships),
                value: "\(appState.ragManager.relationships.count)",
                color: .orange
            )

            if let lastUpdated = appState.ragManager.indexStats.lastIndexedAt {
                metricRow(
                    icon: "clock",
                    label: localization.localized(.ragLastUpdated),
                    value: formatTimeAgo(lastUpdated),
                    color: .white.opacity(0.5)
                )
            }
        }
        .padding(8)
    }

    // MARK: - Index Progress

    private var indexProgressSection: some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text(localization.localized(.ragIndexing).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
                Text("\(Int(appState.ragManager.indexProgress * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 8)

            ProgressView(value: appState.ragManager.indexProgress)
                .tint(Color(hex: "#9C27B0"))
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 6) {
                Button(action: {
                    appState.startRAGIndexing()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                        Text(localization.localized(.ragReindex))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(appState.ragManager.isIndexing)

                Button(action: {
                    appState.ragManager.clearIndex()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 8))
                        Text(localization.localized(.ragClearIndex))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                // Auto-index toggle
                Toggle(isOn: $appState.ragManager.isAutoIndexEnabled) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .scaleEffect(0.6)
                .frame(width: 36)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Helpers

    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n < 1_000_000 { return String(format: "%.1fK", Double(n) / 1000.0) }
        return String(format: "%.1fM", Double(n) / 1_000_000.0)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86400))d ago"
    }
}
