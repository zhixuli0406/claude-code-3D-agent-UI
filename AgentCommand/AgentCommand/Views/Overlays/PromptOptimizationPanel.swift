import SwiftUI

/// Full-screen panel for prompt optimization features (H4)
/// Includes: Quality Analysis, History, Patterns, A/B Tests, Versions
struct PromptOptimizationPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var analyzeText = ""
    @State private var abTaskDesc = ""
    @State private var abPromptA = ""
    @State private var abPromptB = ""
    @State private var showRewritePreview = false
    @State private var showStatsView = false
    @State private var expandedHistoryId: String? = nil
    @State private var expandedSuggestionId: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .frame(width: 720, height: 600)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#E040FB"))
            Text(localization.localized(.promptOptimization))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            if let score = appState.promptOptimizationManager.lastScore {
                HStack(spacing: 4) {
                    Text(localization.localized(.promptQuality))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Text(score.gradeLabel)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: score.gradeColorHex))
                }
            }
            Button(action: { appState.isPromptOptimizationPanelVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.4))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(localization.localized(.promptAnalyze), icon: "gauge.with.dots.needle.67percent", index: 0)
            tabButton(localization.localized(.promptHistory), icon: "clock.arrow.circlepath", index: 1)
            tabButton(localization.localized(.promptPatterns), icon: "chart.bar.xaxis", index: 2)
            tabButton(localization.localized(.promptABTest), icon: "arrow.left.arrow.right", index: 3)
            tabButton(localization.localized(.promptVersions), icon: "doc.on.doc", index: 4)
        }
        .background(Color.black.opacity(0.3))
    }

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color(hex: "#E040FB") : .white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#E040FB").opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: analyzeTab
        case 1: historyTab
        case 2: patternsTab
        case 3: abTestTab
        case 4: versionsTab
        default: analyzeTab
        }
    }

    // MARK: - Tab 0: Analyze

    private var analyzeTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Input area
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.localized(.promptAnalyzeInput))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    TextEditor(text: $analyzeText)
                        .font(.system(size: 13))
                        .frame(height: 80)
                        .padding(6)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "#E040FB").opacity(0.2), lineWidth: 1)
                        )

                    HStack {
                        Button(action: {
                            guard !analyzeText.isEmpty else { return }
                            _ = appState.promptOptimizationManager.analyzePrompt(analyzeText)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text(localization.localized(.promptAnalyze))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#E040FB"))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(analyzeText.isEmpty)

                        Spacer()

                        Text("\(estimateTokens(analyzeText)) tokens")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Score results
                if let score = appState.promptOptimizationManager.lastScore {
                    Divider().background(Color.white.opacity(0.1))
                    scoreDetailView(score)
                }

                // Anti-pattern issues
                let antiPatterns = appState.promptOptimizationManager.detectedAntiPatterns
                if !antiPatterns.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    antiPatternsSection(antiPatterns)
                }

                // Rewrite suggestion
                if let rewrite = appState.promptOptimizationManager.lastRewrite {
                    Divider().background(Color.white.opacity(0.1))
                    rewriteSection(rewrite)
                }

                // Suggestions
                let suggestions = appState.promptOptimizationManager.suggestions
                if !suggestions.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    suggestionsListView(suggestions)
                }
            }
            .padding(16)
        }
    }

    private func scoreDetailView(_ score: PromptQualityScore) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Grade circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: score.overallScore)
                        .stroke(Color(hex: score.gradeColorHex), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(score.gradeLabel)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: score.gradeColorHex))
                        Text("\(score.overallPercentage)%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Dimension bars
                VStack(spacing: 8) {
                    dimensionBar(label: localization.localized(.promptClarity), value: score.clarity, color: "#00BCD4")
                    dimensionBar(label: localization.localized(.promptSpecificity), value: score.specificity, color: "#4CAF50")
                    dimensionBar(label: localization.localized(.promptContext), value: score.context, color: "#FF9800")
                    dimensionBar(label: localization.localized(.promptActionability), value: score.actionability, color: "#E040FB")
                    dimensionBar(label: localization.localized(.promptTokenEfficiency), value: score.tokenEfficiency, color: "#03A9F4")
                }
            }

            // Meta info
            HStack(spacing: 16) {
                metaItem(icon: "number", label: localization.localized(.promptTokenCount), value: "\(score.estimatedTokens)")
                metaItem(icon: "dollarsign.circle", label: localization.localized(.promptEstimatedCost), value: String(format: "$%.4f", score.estimatedCostUSD))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private func dimensionBar(label: String, value: Double, color: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color))
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 6)
            Text("\(Int(value * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: color))
                .frame(width: 35, alignment: .trailing)
        }
    }

    private func metaItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#E040FB").opacity(0.6))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private func suggestionsListView(_ suggestions: [PromptSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.promptSuggestions))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 6) {
                ForEach(suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }

    private func suggestionCard(_ suggestion: PromptSuggestion) -> some View {
        let isExpanded = expandedSuggestionId == suggestion.id
        return VStack(spacing: 0) {
            Button(action: { expandedSuggestionId = isExpanded ? nil : suggestion.id }) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: suggestion.type.icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: suggestion.impact.colorHex))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Text(suggestion.description)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text(suggestion.impact.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: suggestion.impact.colorHex))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: suggestion.impact.colorHex).opacity(0.15))
                            .cornerRadius(3)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(Color.white.opacity(0.1))

                    // Original snippet
                    if !suggestion.originalSnippet.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Original:")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            Text(suggestion.originalSnippet)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "#F44336").opacity(0.05))
                                .cornerRadius(4)
                        }
                    }

                    // Suggested snippet
                    if !suggestion.suggestedSnippet.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggested:")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            Text(suggestion.suggestedSnippet)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "#4CAF50").opacity(0.05))
                                .cornerRadius(4)
                        }
                    }

                    // Apply button
                    if !suggestion.suggestedSnippet.isEmpty && !analyzeText.isEmpty {
                        Button(action: {
                            if analyzeText.lowercased().contains(suggestion.originalSnippet.lowercased()) && !suggestion.originalSnippet.isEmpty {
                                analyzeText = analyzeText.replacingOccurrences(
                                    of: suggestion.originalSnippet,
                                    with: suggestion.suggestedSnippet,
                                    options: .caseInsensitive
                                )
                            } else {
                                analyzeText += "\n" + suggestion.suggestedSnippet
                            }
                            _ = appState.promptOptimizationManager.analyzePrompt(analyzeText)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                Text(localization.localized(.promptApplySuggestion))
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "#4CAF50"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#4CAF50").opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white.opacity(isExpanded ? 0.05 : 0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isExpanded ? Color(hex: suggestion.impact.colorHex).opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Tab 1: History

    private var historyTab: some View {
        VStack(spacing: 0) {
            if appState.promptOptimizationManager.history.isEmpty {
                Spacer()
                Text(localization.localized(.promptNoHistory))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            } else {
                historyToolbar
                if showStatsView {
                    historyStatsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(appState.promptOptimizationManager.filteredHistory.prefix(50)) { record in
                                historyRow(record)
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
    }

    private var historyToolbar: some View {
        HStack(spacing: 8) {
            // Filter menu
            Menu {
                Button(action: {
                    appState.promptOptimizationManager.setFilterTag(nil)
                    appState.promptOptimizationManager.setFilterSuccess(nil)
                }) {
                    Label(localization.localized(.promptAllResults), systemImage: appState.promptOptimizationManager.historyFilterTag == nil && appState.promptOptimizationManager.historyFilterSuccess == nil ? "checkmark" : "")
                }
                Button(action: { appState.promptOptimizationManager.setFilterSuccess(true) }) {
                    Label(localization.localized(.promptSuccessOnly), systemImage: appState.promptOptimizationManager.historyFilterSuccess == true ? "checkmark" : "")
                }
                Button(action: { appState.promptOptimizationManager.setFilterSuccess(false) }) {
                    Label(localization.localized(.promptFailedOnly), systemImage: appState.promptOptimizationManager.historyFilterSuccess == false ? "checkmark" : "")
                }
                Divider()
                Menu(localization.localized(.promptFilterByTag)) {
                    ForEach(appState.promptOptimizationManager.getAllTags(), id: \.self) { tag in
                        Button(action: { appState.promptOptimizationManager.setFilterTag(tag) }) {
                            Label(tag, systemImage: appState.promptOptimizationManager.historyFilterTag == tag ? "checkmark" : "")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(localization.localized(.promptFilterByResult))
                    if appState.promptOptimizationManager.historyFilterTag != nil || appState.promptOptimizationManager.historyFilterSuccess != nil {
                        Circle()
                            .fill(Color(hex: "#E040FB"))
                            .frame(width: 6, height: 6)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Sort menu
            Menu {
                ForEach(PromptHistorySortOption.allCases, id: \.self) { option in
                    Button(action: { appState.promptOptimizationManager.setSortOption(option) }) {
                        Label(option.displayName, systemImage: appState.promptOptimizationManager.historySortOption == option ? "checkmark" : option.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(appState.promptOptimizationManager.historySortOption.displayName)
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Spacer()

            // Record count
            Text("\(appState.promptOptimizationManager.filteredHistory.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))

            // Stats toggle
            Button(action: {
                if !showStatsView {
                    appState.promptOptimizationManager.generateGroupedStats()
                }
                showStatsView.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showStatsView ? "list.bullet" : "chart.bar")
                    Text(showStatsView ? localization.localized(.promptHistory) : localization.localized(.promptStatistics))
                }
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#E040FB"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#E040FB").opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
    }

    private var historyStatsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Grouping selector
                HStack(spacing: 8) {
                    Text(localization.localized(.promptGroupBy))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(PromptHistoryTimeGrouping.allCases, id: \.self) { grouping in
                        Button(action: { appState.promptOptimizationManager.setGrouping(grouping) }) {
                            HStack(spacing: 4) {
                                Image(systemName: grouping.iconName)
                                Text(grouping.displayName)
                            }
                            .font(.system(size: 11))
                            .foregroundColor(appState.promptOptimizationManager.historyGrouping == grouping ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(appState.promptOptimizationManager.historyGrouping == grouping ? Color(hex: "#E040FB") : Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                // Overall summary card
                overallStatsSummary

                // Time-grouped stats
                if !appState.promptOptimizationManager.groupedStats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.promptStatistics))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))

                        ForEach(appState.promptOptimizationManager.groupedStats) { stat in
                            timeStatCard(stat)
                        }
                    }
                }

                // Category stats
                if !appState.promptOptimizationManager.categoryStats.isEmpty {
                    Divider().background(Color.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.promptCategoryBreakdown))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))

                        ForEach(appState.promptOptimizationManager.categoryStats) { stat in
                            categoryStatCard(stat)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var overallStatsSummary: some View {
        let manager = appState.promptOptimizationManager
        let history = manager.history
        let completedCount = history.filter { $0.isCompleted }.count
        let successCount = history.filter { $0.wasSuccessful == true }.count
        let successRate = completedCount > 0 ? Double(successCount) / Double(completedCount) : 0
        let totalTokens = history.compactMap(\.tokenCount).reduce(0, +)
        let totalCost = history.compactMap(\.costUSD).reduce(0, +)

        return HStack(spacing: 0) {
            summaryStatCard(
                icon: "number",
                value: "\(history.count)",
                label: localization.localized(.promptTotalAnalyzed),
                color: "#E040FB"
            )
            summaryStatCard(
                icon: "checkmark.circle",
                value: String(format: "%.0f%%", successRate * 100),
                label: localization.localized(.promptSuccessRate),
                color: "#4CAF50"
            )
            summaryStatCard(
                icon: "textformat.123",
                value: "\(totalTokens)",
                label: localization.localized(.promptTotalTokens),
                color: "#00BCD4"
            )
            summaryStatCard(
                icon: "dollarsign.circle",
                value: String(format: "$%.2f", totalCost),
                label: localization.localized(.promptTotalCost),
                color: "#FF9800"
            )
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private func summaryStatCard(icon: String, value: String, label: String, color: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func timeStatCard(_ stat: PromptHistoryStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.periodLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("\(stat.totalCount) prompts")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 12) {
                statMetric(icon: "checkmark.circle", value: String(format: "%.0f%%", stat.successRate * 100), color: "#4CAF50")
                statMetric(icon: "star", value: String(format: "%.0f%%", stat.avgQualityScore * 100), color: "#E040FB")
                statMetric(icon: "number", value: "\(stat.avgTokensPerPrompt)", color: "#00BCD4")
                statMetric(icon: "dollarsign.circle", value: String(format: "$%.3f", stat.totalCostUSD), color: "#FF9800")
            }

            if !stat.tagDistribution.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                    ForEach(stat.tagDistribution.sorted(by: { $0.value > $1.value }).prefix(3), id: \.key) { tag, count in
                        Text("\(tag)(\(count))")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#E040FB").opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#E040FB").opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    private func categoryStatCard(_ stat: PromptCategoryStats) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.categoryName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                HStack(spacing: 6) {
                    Text("\(stat.count)×")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(formatDate(stat.lastUsed))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            Spacer()

            statMetric(icon: "checkmark", value: String(format: "%.0f%%", stat.successRate * 100), color: "#4CAF50")
            statMetric(icon: "star", value: String(format: "%.0f%%", stat.avgQualityScore * 100), color: "#E040FB")
            statMetric(icon: "number", value: "\(stat.avgTokens)", color: "#00BCD4")
            statMetric(icon: "dollarsign.circle", value: String(format: "$%.3f", stat.totalCostUSD), color: "#FF9800")
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    private func statMetric(icon: String, value: String, color: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundColor(Color(hex: color))
    }

    private func historyRow(_ record: PromptHistoryRecord) -> some View {
        let isExpanded = expandedHistoryId == record.id
        return VStack(spacing: 0) {
            // Main row - clickable
            Button(action: { expandedHistoryId = isExpanded ? nil : record.id }) {
                HStack(spacing: 8) {
                    // Status indicator
                    Circle()
                        .fill(record.wasSuccessful == true ? Color.green : (record.wasSuccessful == false ? Color.red : Color.gray))
                        .frame(width: 6, height: 6)

                    // Prompt text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.prompt)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Text(formatDate(record.sentAt))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))

                            if let score = record.qualityScore {
                                Text(score.gradeLabel)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: score.gradeColorHex))
                            }

                            if let tokens = record.tokenCount {
                                Text("\(tokens) tok")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                            }

                            if !record.tags.isEmpty {
                                Text(record.tags.joined(separator: ", "))
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "#E040FB").opacity(0.6))
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let cost = record.costUSD {
                            Text(String(format: "$%.3f", cost))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(8)
            }
            .buttonStyle(.plain)

            // Expanded detail section
            if isExpanded {
                historyDetailSection(record)
            }
        }
        .background(Color.white.opacity(isExpanded ? 0.05 : 0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isExpanded ? Color(hex: "#E040FB").opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    private func historyDetailSection(_ record: PromptHistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().background(Color.white.opacity(0.1))

            // Quality score detail
            if let score = record.qualityScore {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.localized(.promptQuality))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 12) {
                        miniScoreBar(label: localization.localized(.promptClarity), value: score.clarity, color: "#00BCD4")
                        miniScoreBar(label: localization.localized(.promptSpecificity), value: score.specificity, color: "#4CAF50")
                        miniScoreBar(label: localization.localized(.promptContext), value: score.context, color: "#FF9800")
                        miniScoreBar(label: localization.localized(.promptActionability), value: score.actionability, color: "#E040FB")
                        miniScoreBar(label: localization.localized(.promptTokenEfficiency), value: score.tokenEfficiency, color: "#03A9F4")
                    }
                }
            }

            // Duration
            if let duration = record.taskDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    Text(localization.localized(.promptDuration))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(String(format: "%.1fs", duration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Tags
            if !record.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    ForEach(record.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "#E040FB"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#E040FB").opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }

            // Re-analyze button
            Button(action: {
                analyzeText = record.prompt
                selectedTab = 0
                _ = appState.promptOptimizationManager.analyzePrompt(record.prompt)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text(localization.localized(.promptAnalyze))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#E040FB"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#E040FB").opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func miniScoreBar(label: String, value: Double, color: String) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.1))
                .frame(width: 40, height: 3)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: color))
                        .frame(width: 40 * value)
                }
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // MARK: - Tab 2: Patterns

    private var patternsTab: some View {
        VStack(spacing: 12) {
            HStack {
                Text(localization.localized(.promptPatterns))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button(action: { appState.promptOptimizationManager.detectPatterns() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text(localization.localized(.promptRefreshPatterns))
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#E040FB"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if appState.promptOptimizationManager.patterns.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.2))
                    Text(localization.localized(.promptNoPatternsYet))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.promptOptimizationManager.patterns) { pattern in
                            patternCard(pattern)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func patternCard(_ pattern: PromptPattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pattern.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(pattern.effectivenessLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: pattern.effectivenessColorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(hex: pattern.effectivenessColorHex).opacity(0.15))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                patternStat(label: localization.localized(.promptPatternCount), value: "\(pattern.matchCount)")
                patternStat(label: localization.localized(.promptPatternSuccessRate), value: "\(pattern.successPercentage)%")
                patternStat(label: localization.localized(.promptPatternAvgTokens), value: "\(pattern.avgTokens)")
            }

            if !pattern.examplePrompts.isEmpty {
                Text(pattern.examplePrompts.first ?? "")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .italic()
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: pattern.effectivenessColorHex).opacity(0.2), lineWidth: 1)
        )
    }

    private func patternStat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Tab 3: A/B Test

    private var abTestTab: some View {
        VStack(spacing: 12) {
            // Create new test
            VStack(alignment: .leading, spacing: 6) {
                Text(localization.localized(.promptCreateABTest))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                TextField(localization.localized(.promptABTaskDesc), text: $abTaskDesc)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Variant A")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#00BCD4"))
                        TextField("Prompt A...", text: $abPromptA)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Variant B")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#FF9800"))
                        TextField("Prompt B...", text: $abPromptB)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                    }
                }

                Button(action: {
                    guard !abTaskDesc.isEmpty && !abPromptA.isEmpty && !abPromptB.isEmpty else { return }
                    _ = appState.promptOptimizationManager.createABTest(
                        task: abTaskDesc, promptA: abPromptA, promptB: abPromptB
                    )
                    abTaskDesc = ""
                    abPromptA = ""
                    abPromptB = ""
                }) {
                    Text(localization.localized(.promptCreateABTest))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#E040FB"))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(abTaskDesc.isEmpty || abPromptA.isEmpty || abPromptB.isEmpty)
            }
            .padding(12)

            Divider().background(Color.white.opacity(0.1))

            // Test list
            if appState.promptOptimizationManager.abTests.isEmpty {
                Spacer()
                Text(localization.localized(.promptNoABTests))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.promptOptimizationManager.abTests) { test in
                            abTestRow(test)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func abTestRow(_ test: PromptABTest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(test.taskDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                Spacer()
                Text(test.status.displayName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(test.status == .completed ? .green : .orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((test.status == .completed ? Color.green : Color.orange).opacity(0.15))
                    .cornerRadius(3)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("A")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#00BCD4"))
                        if test.winnerVariant == "A" {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(test.variantA.prompt)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("B")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#FF9800"))
                        if test.winnerVariant == "B" {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(test.variantB.prompt)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    // MARK: - Tab 4: Versions

    private var versionsTab: some View {
        VStack(spacing: 0) {
            if appState.promptOptimizationManager.versions.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.2))
                    Text(localization.localized(.promptNoVersions))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.promptOptimizationManager.versions.prefix(50)) { version in
                            versionRow(version)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func versionRow(_ version: PromptVersion) -> some View {
        HStack(spacing: 8) {
            Text(version.versionLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#E040FB"))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(version.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(formatDate(version.createdAt))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))

                    if let score = version.qualityScore {
                        Text("\(Int(score * 100))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    if let note = version.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let success = version.wasSuccessful {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(success ? .green : .red)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    // MARK: - Anti-Patterns Section

    private func antiPatternsSection(_ antiPatterns: [PromptAntiPattern]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#F44336"))
                Text(localization.localized(.promptIssuesDetected))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                issueBadge(count: antiPatterns.filter { $0.severity == .critical }.count, color: "#F44336", label: "C")
                issueBadge(count: antiPatterns.filter { $0.severity == .warning }.count, color: "#FF9800", label: "W")
                issueBadge(count: antiPatterns.filter { $0.severity == .info }.count, color: "#03A9F4", label: "I")
            }

            ForEach(antiPatterns) { ap in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: ap.category.icon)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: ap.severity.colorHex))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(ap.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Text(ap.severity.rawValue.uppercased())
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: ap.severity.colorHex))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: ap.severity.colorHex).opacity(0.15))
                                .cornerRadius(2)
                        }
                        Text(ap.description)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)

                        if !ap.fixSuggestion.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow.opacity(0.8))
                                Text(ap.fixSuggestion)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.yellow.opacity(0.7))
                                    .lineLimit(2)
                            }
                            .padding(4)
                            .background(Color.yellow.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(8)
                .background(Color(hex: ap.severity.colorHex).opacity(0.05))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: ap.severity.colorHex).opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private func issueBadge(count: Int, color: String, label: String) -> some View {
        Group {
            if count > 0 {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(hex: color))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(hex: color).opacity(0.15))
                .cornerRadius(3)
            }
        }
    }

    // MARK: - Rewrite Suggestion Section

    private func rewriteSection(_ rewrite: PromptRewriteSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#4CAF50"))
                Text(localization.localized(.promptRewriteSuggestion))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("+\(Int(rewrite.estimatedScoreImprovement * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#4CAF50").opacity(0.15))
                    .cornerRadius(3)
            }

            // Applied rules
            HStack(spacing: 4) {
                ForEach(rewrite.appliedRules, id: \.self) { rule in
                    Text(rule)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#E040FB").opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#E040FB").opacity(0.1))
                        .cornerRadius(3)
                }
            }

            // Rewritten prompt preview
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.localized(.promptRewritePreview))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(rewrite.rewrittenPrompt)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#4CAF50").opacity(0.05))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "#4CAF50").opacity(0.2), lineWidth: 1)
                    )
            }

            // Apply button
            Button(action: {
                analyzeText = rewrite.rewrittenPrompt
                _ = appState.promptOptimizationManager.analyzePrompt(analyzeText)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                    Text(localization.localized(.promptApplyRewrite))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(hex: "#4CAF50"))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func estimateTokens(_ text: String) -> Int {
        let cjkCount = text.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        let nonCjkCount = text.count - cjkCount
        return (nonCjkCount / 4) + (cjkCount * 2) + 1
    }
}
