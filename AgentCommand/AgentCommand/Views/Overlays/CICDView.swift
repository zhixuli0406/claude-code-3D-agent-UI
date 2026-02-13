import SwiftUI

/// Modal sheet for CI/CD pipeline detail view (I1)
struct CICDView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .frame(width: 700, height: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#E91E63"))
            Text(localization.localized(.cicdPipeline))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.cicdManager.isMonitoring {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#4CAF50"))
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#4CAF50"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#4CAF50").opacity(0.1))
                .cornerRadius(4)
            }

            // Success rate badge
            let rate = appState.cicdManager.stats.successRate
            Text("\(Int(rate * 100))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: rate >= 0.8 ? "#4CAF50" : rate >= 0.5 ? "#FF9800" : "#F44336"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: rate >= 0.8 ? "#4CAF50" : rate >= 0.5 ? "#FF9800" : "#F44336").opacity(0.1))
                .cornerRadius(4)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: localization.localized(.cicdPipelines), icon: "arrow.triangle.branch", index: 0)
            tabButton(title: localization.localized(.cicdPRReview), icon: "arrow.triangle.pull", index: 1)
            tabButton(title: localization.localized(.cicdBuildHistory), icon: "clock.arrow.circlepath", index: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color(hex: "#E91E63") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#E91E63").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: pipelinesTab
        case 1: pullRequestsTab
        case 2: buildHistoryTab
        default: pipelinesTab
        }
    }

    // MARK: - Pipelines Tab

    private var pipelinesTab: some View {
        VStack(spacing: 0) {
            // Summary stats
            HStack(spacing: 16) {
                statBadge(icon: "play.circle.fill", value: "\(appState.cicdManager.stats.totalPipelines)", label: localization.localized(.cicdTotalRuns))
                statBadge(icon: "checkmark.circle.fill", value: "\(appState.cicdManager.stats.successCount)", label: localization.localized(.cicdSuccess))
                statBadge(icon: "xmark.circle.fill", value: "\(appState.cicdManager.stats.failureCount)", label: localization.localized(.cicdFailure))
                statBadge(icon: "percent", value: "\(Int(appState.cicdManager.stats.successRate * 100))%", label: localization.localized(.cicdSuccessRate))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Pipeline list
            if appState.cicdManager.pipelines.isEmpty {
                emptyState(icon: "arrow.triangle.branch", message: localization.localized(.cicdPipeline))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.cicdManager.pipelines) { pipeline in
                            pipelineCard(pipeline)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func pipelineCard(_ pipeline: CICDPipeline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: pipeline.status.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: pipeline.status.hexColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(pipeline.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Text(pipeline.branch)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#58A6FF"))
                        Text(pipeline.commitSHA)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()

                if let started = pipeline.startedAt {
                    Text(formatTimeAgo(started))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Stages
            HStack(spacing: 4) {
                Text(localization.localized(.cicdStages))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                ForEach(pipeline.stages) { stage in
                    HStack(spacing: 2) {
                        Image(systemName: stage.status.iconName)
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: stage.status.hexColor))
                        Text(stage.name)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: stage.status.hexColor).opacity(0.1))
                    .cornerRadius(3)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: pipeline.status.hexColor).opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Pull Requests Tab

    private var pullRequestsTab: some View {
        VStack(spacing: 0) {
            if appState.cicdManager.pullRequests.isEmpty {
                emptyState(icon: "arrow.triangle.pull", message: localization.localized(.cicdPRReview))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.cicdManager.pullRequests) { pr in
                            prCard(pr)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func prCard(_ pr: CICDPullRequest) -> some View {
        HStack(spacing: 10) {
            // PR status indicator
            Circle()
                .fill(Color(hex: pr.status.hexColor))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("#\(pr.number)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#E91E63"))
                    Text(pr.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "person")
                            .font(.system(size: 8))
                        Text(pr.author)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 8))
                        Text("\(pr.commentCount)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.4))

                    // Checks status
                    HStack(spacing: 3) {
                        Image(systemName: pr.checksStatus.iconName)
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: pr.checksStatus.hexColor))
                        Text(localization.localized(.cicdBuildResult))
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer()

                    Text(formatTimeAgo(pr.updatedAt))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            Spacer()

            // Review status badge
            Text(pr.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(hex: pr.status.hexColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: pr.status.hexColor).opacity(0.15))
                .cornerRadius(4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Build History Tab

    private var buildHistoryTab: some View {
        VStack(spacing: 0) {
            // Stats row
            HStack(spacing: 16) {
                statBadge(icon: "checkmark.circle.fill", value: "\(appState.cicdManager.stats.successCount)", label: localization.localized(.cicdSuccess))
                statBadge(icon: "xmark.circle.fill", value: "\(appState.cicdManager.stats.failureCount)", label: localization.localized(.cicdFailure))
                statBadge(icon: "chart.line.uptrend.xyaxis", value: "\(Int(appState.cicdManager.stats.successRate * 100))%", label: localization.localized(.cicdSuccessRate))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Build history list
            let completedPipelines = appState.cicdManager.pipelines.filter { !$0.isRunning }
            if completedPipelines.isEmpty {
                emptyState(icon: "clock.arrow.circlepath", message: localization.localized(.cicdBuildHistory))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(completedPipelines) { pipeline in
                            HStack(spacing: 8) {
                                Image(systemName: pipeline.status.iconName)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: pipeline.status.hexColor))
                                    .frame(width: 16)

                                Text(pipeline.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))

                                Text(pipeline.branch)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "#58A6FF").opacity(0.7))

                                Spacer()

                                Text(pipeline.commitSHA)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))

                                if let completed = pipeline.completedAt {
                                    Text(formatTimeAgo(completed))
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#E91E63"))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.15))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
        }
    }

    // MARK: - Formatters

    private func formatTimeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86400))d ago"
    }
}
