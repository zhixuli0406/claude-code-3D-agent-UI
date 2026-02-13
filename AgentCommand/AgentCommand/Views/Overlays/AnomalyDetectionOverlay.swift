import SwiftUI

// MARK: - L3: Anomaly Detection Status Overlay (right-side floating panel)

struct AnomalyDetectionOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#FF5722").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF5722").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.adAnomalyDetection))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.anomalyDetectionManager.isMonitoring {
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
            let stats = appState.anomalyDetectionManager.stats

            HStack {
                Text(localization.localized(.adActiveAlerts))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.activeAlerts)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: stats.activeAlerts > 0 ? "#FF5722" : "#4CAF50"))
            }

            HStack {
                Text(localization.localized(.adResolved))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.resolvedAlerts)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.adRetrySuccess))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(stats.retrySuccessRate * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
            }

            // Recent active alerts
            ForEach(appState.anomalyDetectionManager.alerts.filter { !$0.isResolved }.prefix(3)) { alert in
                alertRow(alert)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func alertRow(_ alert: AnomalyAlert) -> some View {
        HStack(spacing: 4) {
            Image(systemName: alert.severity.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: alert.severity.hexColor))
            Text(alert.type.displayName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text(alert.detectedAt, style: .relative)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
