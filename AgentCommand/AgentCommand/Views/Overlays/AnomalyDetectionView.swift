import SwiftUI

// MARK: - L3: Anomaly Detection Detail View (Sheet)

struct AnomalyDetectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#FF5722").opacity(0.3))

            TabView(selection: $selectedTab) {
                alertsTab.tag(0)
                patternsTab.tag(1)
                retryTab.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 650, minHeight: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if appState.anomalyDetectionManager.alerts.isEmpty {
                appState.anomalyDetectionManager.loadSampleData()
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "shield.checkered")
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.adAnomalyDetection))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Toggle(localization.localized(.adMonitoring), isOn: Binding(
                get: { appState.anomalyDetectionManager.isMonitoring },
                set: { $0 ? appState.anomalyDetectionManager.startMonitoring() : appState.anomalyDetectionManager.stopMonitoring() }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.7))

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.adAlerts)).tag(0)
                Text(localization.localized(.adPatterns)).tag(1)
                Text(localization.localized(.adRetryConfig)).tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Alerts

    private var alertsTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(localization.localized(.adResolveAll)) {
                    appState.anomalyDetectionManager.resolveAllAlerts()
                }
                .buttonStyle(.bordered)
                .disabled(appState.anomalyDetectionManager.alerts.filter { !$0.isResolved }.isEmpty)
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(appState.anomalyDetectionManager.alerts) { alert in
                        alertCard(alert)
                    }
                }
                .padding()
            }

            if appState.anomalyDetectionManager.alerts.isEmpty {
                emptyState(localization.localized(.adNoAlerts), icon: "shield.checkered")
            }
        }
    }

    private func alertCard(_ alert: AnomalyAlert) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: alert.severity.iconName)
                    .foregroundColor(Color(hex: alert.severity.hexColor))
                Image(systemName: alert.type.iconName)
                    .foregroundColor(Color(hex: alert.type.hexColor))
                Text(alert.type.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if alert.isResolved {
                    Text(localization.localized(.adResolved))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#4CAF50"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#4CAF50").opacity(0.15))
                        .cornerRadius(4)
                }
                Text(alert.detectedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            Text(alert.message)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))

            HStack {
                if let agent = alert.agentName {
                    Label(agent, systemImage: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                if let action = alert.autoAction {
                    Text(action)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#FF9800"))
                }
                if !alert.isResolved {
                    Button(localization.localized(.adResolve)) {
                        appState.anomalyDetectionManager.resolveAlert(alert.id)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(alert.isResolved ? 0.02 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: alert.severity.hexColor).opacity(alert.isResolved ? 0.1 : 0.3), lineWidth: 1)
                )
        )
        .opacity(alert.isResolved ? 0.6 : 1.0)
    }

    // MARK: - Patterns

    private var patternsTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(appState.anomalyDetectionManager.errorPatterns) { pattern in
                    HStack {
                        Image(systemName: pattern.category.iconName)
                            .foregroundColor(Color(hex: pattern.category.hexColor))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pattern.pattern)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            HStack {
                                Text("\(pattern.occurrenceCount)x")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#FF5722"))
                                Text("Last: \(pattern.lastSeen, style: .relative)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        Spacer()
                        if let fix = pattern.suggestedFix {
                            Text(fix)
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "#00BCD4"))
                                .lineLimit(2)
                                .frame(maxWidth: 150, alignment: .trailing)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                }
            }
            .padding()
        }
    }

    // MARK: - Retry Config

    private var retryTab: some View {
        VStack(spacing: 12) {
            ForEach(appState.anomalyDetectionManager.retryConfigs) { config in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.strategy.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Max retries: \(config.maxRetries), Delay: \(Int(config.delaySeconds))s")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { config.isActive },
                        set: { _ in appState.anomalyDetectionManager.toggleRetryConfig(config.id) }
                    ))
                    .toggleStyle(.switch)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
            }
            Spacer()
        }
        .padding()
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
