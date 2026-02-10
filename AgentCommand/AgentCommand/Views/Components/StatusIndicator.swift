import SwiftUI

struct StatusIndicator: View {
    let status: AgentStatus
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(Color(hex: status.hexColor))
            .frame(width: size, height: size)
            .shadow(color: Color(hex: status.hexColor).opacity(0.5), radius: 3)
    }
}

struct TaskStatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: status.hexColor).opacity(0.2))
            .foregroundColor(Color(hex: status.hexColor))
            .cornerRadius(4)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<priority.sortOrder + 1, id: \.self) { _ in
                Image(systemName: "exclamationmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundColor(priorityColor)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(priorityColor.opacity(0.15))
        .cornerRadius(3)
    }

    private var priorityColor: Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}
