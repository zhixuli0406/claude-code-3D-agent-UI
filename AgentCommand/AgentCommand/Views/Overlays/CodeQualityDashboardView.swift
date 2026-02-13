import SwiftUI

/// Modal sheet for code quality dashboard (I3)
struct CodeQualityDashboardView: View {
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
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#FF5722"))
            Text(localization.localized(.codeQuality))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.codeQualityManager.isAnalyzing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(localization.localized(.cqAnalyze))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            } else {
                let stats = appState.codeQualityManager.stats
                HStack(spacing: 6) {
                    issueBadge(count: stats.errorCount, color: "#F44336")
                    issueBadge(count: stats.warningCount, color: "#FF9800")
                    issueBadge(count: stats.infoCount, color: "#2196F3")
                }
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    private func issueBadge(count: Int, color: String) -> some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: color).opacity(0.15))
            .cornerRadius(3)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: localization.localized(.cqLintIssues), icon: "exclamationmark.triangle", index: 0)
            tabButton(title: localization.localized(.cqComplexity), icon: "chart.bar.xaxis", index: 1)
            tabButton(title: localization.localized(.cqTechDebt), icon: "hourglass", index: 2)
            tabButton(title: localization.localized(.cqRefactorSuggestions), icon: "arrow.triangle.2.circlepath", index: 3)
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
            .foregroundColor(selectedTab == index ? Color(hex: "#FF5722") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#FF5722").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: issuesTab
        case 1: complexityTab
        case 2: techDebtTab
        case 3: refactorTab
        default: issuesTab
        }
    }

    // MARK: - Issues Tab

    private var issuesTab: some View {
        VStack(spacing: 0) {
            // Summary stats
            let stats = appState.codeQualityManager.stats
            HStack(spacing: 16) {
                statBadge(icon: "xmark.octagon.fill", value: "\(stats.errorCount)", label: localization.localized(.cqErrors), valueColor: "#F44336")
                statBadge(icon: "exclamationmark.triangle.fill", value: "\(stats.warningCount)", label: localization.localized(.cqWarnings), valueColor: "#FF9800")
                statBadge(icon: "info.circle.fill", value: "\(stats.infoCount)", label: localization.localized(.cqInfo), valueColor: "#2196F3")

                Spacer()

                // Analyze button
                Button(action: { appState.codeQualityManager.analyzeProject() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                        Text(localization.localized(.cqAnalyze))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#FF5722").opacity(0.5))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(appState.codeQualityManager.isAnalyzing)
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Lint issues list
            if appState.codeQualityManager.lintIssues.isEmpty {
                emptyState(icon: "checkmark.seal", message: localization.localized(.cqLintIssues))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.codeQualityManager.lintIssues) { issue in
                            lintIssueRow(issue)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func lintIssueRow(_ issue: LintIssue) -> some View {
        HStack(spacing: 8) {
            Image(systemName: issue.severity.iconName)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: issue.severity.hexColor))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(issue.filePath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#58A6FF").opacity(0.7))

                    Text("L\(issue.line)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))

                    Text(issue.rule)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(2)

                    Text(issue.toolName)
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "#FF5722").opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: issue.severity.hexColor).opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: issue.severity.hexColor).opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Complexity Tab

    private var complexityTab: some View {
        VStack(spacing: 0) {
            // Average complexity header
            HStack {
                Text(localization.localized(.cqComplexity))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                let avg = appState.codeQualityManager.stats.avgComplexity
                Text(String(format: "%.1f avg", avg))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: avg <= 10 ? "#4CAF50" : avg <= 20 ? "#FF9800" : "#F44336"))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            if appState.codeQualityManager.complexities.isEmpty {
                emptyState(icon: "chart.bar.xaxis", message: localization.localized(.cqComplexity))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.codeQualityManager.complexities) { complexity in
                            complexityCard(complexity)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func complexityCard(_ complexity: CodeComplexity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(complexity.moduleName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Cyclomatic complexity
                HStack(spacing: 3) {
                    Text("CC")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(complexity.cyclomaticComplexity)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: complexity.complexityColor))
                }

                // Maintainability index
                HStack(spacing: 3) {
                    Text(localization.localized(.cqMaintainability))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Text(String(format: "%.0f", complexity.maintainabilityIndex))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: complexity.maintainabilityColor))
                }
            }

            HStack(spacing: 12) {
                Text(complexity.filePath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#58A6FF").opacity(0.6))

                Text("\(complexity.linesOfCode) LOC")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))

                Text("Cognitive: \(complexity.cognitiveComplexity)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Complexity bar
            GeometryReader { geo in
                let normalized = min(Double(complexity.cyclomaticComplexity) / 40.0, 1.0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: complexity.complexityColor))
                        .frame(width: geo.size.width * normalized)
                }
            }
            .frame(height: 4)
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

    // MARK: - Tech Debt Tab

    private var techDebtTab: some View {
        VStack(spacing: 0) {
            // Total tech debt summary
            HStack(spacing: 16) {
                let stats = appState.codeQualityManager.stats
                statBadge(icon: "hourglass", value: String(format: "%.0fh", stats.totalTechDebt), label: localization.localized(.cqTechDebt), valueColor: "#FF5722")
                statBadge(icon: "list.number", value: "\(appState.codeQualityManager.techDebtItems.filter { !$0.isResolved }.count)", label: localization.localized(.cqTotalIssues), valueColor: "#FF9800")
                Spacer()
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            if appState.codeQualityManager.techDebtItems.isEmpty {
                emptyState(icon: "hourglass", message: localization.localized(.cqTechDebt))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.codeQualityManager.techDebtItems) { item in
                            techDebtRow(item)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func techDebtRow(_ item: TechDebtItem) -> some View {
        HStack(spacing: 10) {
            // Priority indicator
            Circle()
                .fill(Color(hex: item.priority.hexColor))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.isResolved ? .white.opacity(0.4) : .white)
                        .strikethrough(item.isResolved)
                        .lineLimit(1)

                    Text(item.category.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }

                Text(item.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.filePath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#58A6FF").opacity(0.5))

                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 7))
                        Text(String(format: "%.0fh", item.estimatedHours))
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.3))
                }
            }

            Spacer()

            if !item.isResolved {
                Button(action: { appState.codeQualityManager.resolveDebtItem(item.id) }) {
                    Text(localization.localized(.cqResolve))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FF5722").opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#4CAF50").opacity(0.5))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(item.isResolved ? 0.01 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: item.priority.hexColor).opacity(item.isResolved ? 0.05 : 0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Refactor Tab

    private var refactorTab: some View {
        VStack(spacing: 0) {
            if appState.codeQualityManager.refactorSuggestions.isEmpty {
                emptyState(icon: "arrow.triangle.2.circlepath", message: localization.localized(.cqRefactorSuggestions))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.codeQualityManager.refactorSuggestions) { suggestion in
                            refactorCard(suggestion)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func refactorCard(_ suggestion: RefactorSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#FF5722"))

                Text(suggestion.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(suggestion.description)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(3)

            HStack(spacing: 12) {
                Text(suggestion.filePath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#58A6FF").opacity(0.6))

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text(suggestion.impact)
                        .font(.system(size: 9))
                }
                .foregroundColor(Color(hex: "#4CAF50").opacity(0.7))

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(suggestion.estimatedEffort)
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#FF5722").opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Shared Components

    private func statBadge(icon: String, value: String, label: String, valueColor: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: valueColor))
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
}
