import SwiftUI

struct TimelineFilterBar: View {
    @Binding var filter: TimelineFilter
    let agents: [Agent]
    let onExport: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Event type filters
                ForEach(TimelineEventKind.allCases, id: \.self) { kind in
                    FilterChip(
                        label: kind.displayName,
                        icon: kind.icon,
                        color: Color(hex: kind.hexColor),
                        isActive: filter.eventKinds.isEmpty || filter.eventKinds.contains(kind),
                        onToggle: { toggleKind(kind) }
                    )
                }

                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.2))

                // Agent filters
                ForEach(agents) { agent in
                    FilterChip(
                        label: agent.name,
                        icon: nil,
                        color: .white.opacity(0.6),
                        isActive: filter.agentIds.isEmpty || filter.agentIds.contains(agent.id),
                        onToggle: { toggleAgent(agent.id) }
                    )
                }

                Spacer()

                // Export button
                Button(action: onExport) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(height: 28)
        .background(Color(hex: "#0D1117").opacity(0.9))
    }

    private func toggleKind(_ kind: TimelineEventKind) {
        if filter.eventKinds.isEmpty {
            // Currently showing all — select only this one
            filter.eventKinds = Set(TimelineEventKind.allCases)
            filter.eventKinds.remove(kind)
        } else if filter.eventKinds.contains(kind) {
            filter.eventKinds.remove(kind)
            if filter.eventKinds.isEmpty {
                // All removed = show all
            }
        } else {
            filter.eventKinds.insert(kind)
            if filter.eventKinds.count == TimelineEventKind.allCases.count {
                filter.eventKinds.removeAll()
            }
        }
    }

    private func toggleAgent(_ agentId: UUID) {
        if filter.agentIds.contains(agentId) {
            filter.agentIds.remove(agentId)
        } else {
            filter.agentIds.insert(agentId)
        }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String?
    let color: Color
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 3) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 8))
                }
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundColor(isActive ? color : color.opacity(0.3))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? color.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isActive ? color.opacity(0.3) : color.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
