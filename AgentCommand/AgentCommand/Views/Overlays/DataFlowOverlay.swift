import SwiftUI

// MARK: - J4: Data Flow Status Overlay (right-side floating panel)

struct DataFlowOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#00BCD4").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#00BCD4").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform.path")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00BCD4"))
            Text(localization.localized(.dataFlowAnimation))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.dataFlowAnimationManager.isAnimating {
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
            let stats = appState.dataFlowAnimationManager.stats

            HStack {
                Text(localization.localized(.dfTokensIn))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalTokensIn)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
            }

            HStack {
                Text(localization.localized(.dfTokensOut))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalTokensOut)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF9800"))
            }

            HStack {
                Text(localization.localized(.dfToolCalls))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalToolCalls)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.dfActiveFlows))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.activeFlows)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: stats.activeFlows > 0 ? "#00BCD4" : "#9E9E9E"))
            }

            // Recent tool calls
            ForEach(appState.dataFlowAnimationManager.toolCallChain.suffix(3)) { call in
                toolCallRow(call)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func toolCallRow(_ call: ToolCallChainEntry) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "#E91E63"))
            Text(call.toolName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            if let dur = call.duration {
                Text(String(format: "%.1fs", dur))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
