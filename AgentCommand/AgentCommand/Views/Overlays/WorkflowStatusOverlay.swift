import SwiftUI

// MARK: - L1: Workflow Status Overlay (right-side floating panel)

struct WorkflowStatusOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#7C4DFF").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#7C4DFF").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#7C4DFF"))
            Text(localization.localized(.wfWorkflowEngine))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.workflowManager.isRunning {
                Circle()
                    .fill(Color(hex: "#4CAF50"))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let stats = appState.workflowManager.stats

            HStack {
                Text(localization.localized(.wfActiveWorkflows))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.activeWorkflows)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#7C4DFF"))
            }

            HStack {
                Text(localization.localized(.wfTotalExecutions))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalExecutions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.wfSuccessRate))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(stats.successRate * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.successRate >= 0.8 ? "#4CAF50" : "#FF9800"))
            }

            // Recent executions
            ForEach(appState.workflowManager.executions.prefix(3)) { exec in
                executionRow(exec)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func executionRow(_ exec: WorkflowExecution) -> some View {
        HStack(spacing: 4) {
            Image(systemName: exec.status.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: exec.status.hexColor))
            Text(exec.workflowName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text("\(exec.currentStepIndex)/\(exec.totalSteps)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
