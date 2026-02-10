import SwiftUI

struct ProgressOverlay: View {
    let tasks: [AgentTask]
    let isSimulationRunning: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Simulation status
            HStack(spacing: 6) {
                Circle()
                    .fill(isSimulationRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(isSimulationRunning ? "RUNNING" : "IDLE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isSimulationRunning ? .green : .gray)
            }

            // Overall progress
            HStack(spacing: 6) {
                Text("PROGRESS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                TaskProgressBar(progress: overallProgress, height: 6)
                    .frame(width: 100)

                Text("\(Int(overallProgress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }

            // Task counts
            HStack(spacing: 8) {
                taskCountBadge(count: pendingCount, label: "PND", color: "#9E9E9E")
                taskCountBadge(count: inProgressCount, label: "WRK", color: "#FF9800")
                taskCountBadge(count: completedCount, label: "DON", color: "#4CAF50")
                taskCountBadge(count: failedCount, label: "ERR", color: "#F44336")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
    }

    private func taskCountBadge(count: Int, label: String, color: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private var overallProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        return tasks.map(\.progress).reduce(0, +) / Double(tasks.count)
    }

    private var pendingCount: Int { tasks.filter { $0.status == .pending }.count }
    private var inProgressCount: Int { tasks.filter { $0.status == .inProgress }.count }
    private var completedCount: Int { tasks.filter { $0.status == .completed }.count }
    private var failedCount: Int { tasks.filter { $0.status == .failed }.count }
}
