import SwiftUI
import Combine

/// Unified Knowledge Search View integrating RAG keyword search and semantic search (H5+H1)
/// Provides a single search interface with multi-dimensional result scoring display
struct UnifiedKnowledgeSearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var searchText = ""
    @State private var selectedMode: SearchViewMode = .all
    @State private var selectedTab: UnifiedSearchTab = .results
    @State private var expandedResultId: String?
    @State private var searchCancellable: AnyCancellable?
    @State private var searchSubject = PassthroughSubject<String, Never>()

    // Test panel state
    @State private var testQueries: [TestQueryItem] = TestQueryItem.defaultQueries
    @State private var testResults: [TestResultItem] = []
    @State private var isRunningTests = false

    enum SearchViewMode: String, CaseIterable {
        case all, rag, semantic

        var displayKey: L10nKey {
            switch self {
            case .all: return .unifiedSearchModeAll
            case .rag: return .unifiedSearchModeRAG
            case .semantic: return .unifiedSearchModeSemantic
            }
        }
    }

    enum UnifiedSearchTab: String, CaseIterable {
        case results, entities, performance

        var icon: String {
            switch self {
            case .results: return "list.bullet"
            case .entities: return "tag"
            case .performance: return "chart.bar"
            }
        }

        var displayName: String {
            switch self {
            case .results: return "Results"
            case .entities: return "Entities"
            case .performance: return "Performance"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchInputSection
            modeSelector
            Divider().background(Color.white.opacity(0.1))
            tabBar
            tabContent
        }
        .frame(width: 760, height: 620)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            searchCancellable = searchSubject
                .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
                .removeDuplicates()
                .sink { query in
                    executeSearch(query)
                }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#9C27B0"), Color(hex: "#00BCD4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }

            Text(localization.localized(.unifiedSearch))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Semantic search toggle
            HStack(spacing: 4) {
                Image(systemName: appState.isSemanticSearchEnabled ? "brain" : "brain.fill")
                    .font(.system(size: 10))
                Text("AI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(appState.isSemanticSearchEnabled ? Color(hex: "#00BCD4") : .white.opacity(0.4))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                appState.isSemanticSearchEnabled
                    ? Color(hex: "#00BCD4").opacity(0.15)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(4)
            .onTapGesture { appState.toggleSemanticSearch() }

            // Index stats badge
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.ragManager.isIndexing ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text("\(appState.ragManager.indexStats.totalDocuments) docs")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }

            Button(action: { appState.isUnifiedSearchVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Search Input

    private var searchInputSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#9C27B0"))

            TextField(localization.localized(.unifiedSearchPlaceholder), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .onSubmit { executeSearch(searchText) }
                .onChange(of: searchText) { _, newValue in
                    searchSubject.send(newValue)
                }

            if appState.isUnifiedSearchProcessing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    appState.clearUnifiedSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            Button(action: { executeSearch(searchText) }) {
                Text(localization.localized(.ragSearch))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#9C27B0").opacity(0.4))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .disabled(searchText.isEmpty)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(SearchViewMode.allCases, id: \.self) { mode in
                Button(action: { selectedMode = mode }) {
                    Text(localization.localized(mode.displayKey))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(selectedMode == mode ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedMode == mode
                                ? modeColor(mode).opacity(0.3)
                                : Color.white.opacity(0.05)
                        )
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Response metadata
            if let response = appState.unifiedSearchResponse {
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "number")
                            .font(.system(size: 8))
                        Text("\(response.results.count) \(localization.localized(.unifiedSearchResultCount).lowercased())")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("\(response.processingTimeMs)ms")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.5))

                    // Intent badge
                    HStack(spacing: 3) {
                        Image(systemName: response.classification.primaryIntent.iconName)
                            .font(.system(size: 8))
                        Text(response.classification.primaryIntent.displayName)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00BCD4").opacity(0.12))
                    .cornerRadius(3)

                    // Confidence
                    Text("\(Int(response.classification.confidence * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(confidenceColor(response.classification.confidence))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(UnifiedSearchTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? Color(hex: "#9C27B0") : .white.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? Color(hex: "#9C27B0").opacity(0.12)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .results:
            resultsTab
        case .entities:
            entitiesTab
        case .performance:
            performanceTab
        }
    }

    // MARK: - Results Tab

    private var resultsTab: some View {
        Group {
            if let response = appState.unifiedSearchResponse {
                let filtered = filteredResults(response.results)
                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filtered, id: \.id) { result in
                                unifiedResultRow(result, classification: response.classification)
                            }
                        }
                        .padding(12)
                    }
                }
            } else {
                promptState
            }
        }
    }

    private func unifiedResultRow(_ result: SemanticSearchResult, classification: QueryClassification) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            resultRowButton(result)
            if expandedResultId == result.id {
                expandedDetail(result)
            }
        }
        .background(resultRowBackground(result))
    }

    private func resultRowButton(_ result: SemanticSearchResult) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedResultId = expandedResultId == result.id ? nil : result.id
            }
        }) {
            resultRowContent(result)
        }
        .buttonStyle(.plain)
    }

    private func resultRowContent(_ result: SemanticSearchResult) -> some View {
        HStack(spacing: 8) {
            sourceIndicator(result.source)
            resultInfoColumn(result)
            Spacer()
            resultScoreBadges(result)
            resultCombinedScore(result)
            Image(systemName: expandedResultId == result.id ? "chevron.up" : "chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(8)
    }

    private func resultInfoColumn(_ result: SemanticSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let rag = result.ragResult {
                Text(rag.document.fileName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                let snippetText = result.snippetWithHighlights.isEmpty ? rag.matchedSnippet : result.snippetWithHighlights
                Text(cleanSnippet(snippetText))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            } else if let memory = result.memoryResult {
                Text("Memory: \(memory.agentName)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(memory.summary)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
        }
    }

    private func resultScoreBadges(_ result: SemanticSearchResult) -> some View {
        HStack(spacing: 4) {
            scorePill(label: "K", value: result.keywordScore, color: "#FF9800")
            scorePill(label: "S", value: result.semanticRelevance, color: "#00BCD4")
            scorePill(label: "E", value: result.entityMatchScore, color: "#4CAF50")
        }
    }

    private func resultCombinedScore(_ result: SemanticSearchResult) -> some View {
        Text(String(format: "%.2f", result.combinedScore))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(scoreColor(result.combinedScore))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(scoreColor(result.combinedScore).opacity(0.12))
            .cornerRadius(4)
    }

    private func resultRowBackground(_ result: SemanticSearchResult) -> some View {
        let isExpanded = expandedResultId == result.id
        return RoundedRectangle(cornerRadius: 6)
            .fill(Color.white.opacity(isExpanded ? 0.05 : 0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }

    private func expandedDetail(_ result: SemanticSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().background(Color.white.opacity(0.08))

            // Score dimensions bar chart
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.localized(.unifiedSearchScoreDimensions).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

                scoreBar(label: localization.localized(.unifiedSearchKeywordScore), value: result.keywordScore, color: "#FF9800")
                scoreBar(label: localization.localized(.unifiedSearchSemanticScore), value: result.semanticRelevance, color: "#00BCD4")
                scoreBar(label: localization.localized(.unifiedSearchEntityScore), value: result.entityMatchScore, color: "#4CAF50")
                scoreBar(label: localization.localized(.unifiedSearchRecencyScore), value: result.recencyScore, color: "#FFD600")
                scoreBar(label: localization.localized(.unifiedSearchRelationshipScore), value: result.relationshipScore, color: "#E91E63")
            }

            // Matched entities
            if !result.matchedEntities.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.localized(.unifiedSearchEntities).uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))

                    FlowLayout(spacing: 4) {
                        ForEach(result.matchedEntities, id: \.id) { entity in
                            entityChip(entity)
                        }
                    }
                }
            }

            // Explanation
            if !result.explanationNote.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.localized(.unifiedSearchExplanation).uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(result.explanationNote)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // File path & actions
            if let rag = result.ragResult {
                HStack {
                    Text(rag.document.filePath)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(1)

                    Spacer()

                    Text(rag.document.fileType.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(hex: rag.document.fileType.colorHex))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: rag.document.fileType.colorHex).opacity(0.12))
                        .cornerRadius(3)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Entities Tab

    private var entitiesTab: some View {
        Group {
            if let response = appState.unifiedSearchResponse {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Query analysis
                        queryAnalysisSection(response)

                        // Extracted entities
                        if !response.classification.extractedEntities.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                sectionHeader(localization.localized(.unifiedSearchEntities))
                                ForEach(response.classification.extractedEntities, id: \.id) { entity in
                                    entityDetailRow(entity)
                                }
                            }
                        }

                        // Suggested prompt refinement
                        if let suggested = response.suggestedPrompt {
                            VStack(alignment: .leading, spacing: 4) {
                                sectionHeader("Prompt Refinement")
                                Text(suggested)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "#00BCD4"))
                                    .padding(8)
                                    .background(Color(hex: "#00BCD4").opacity(0.08))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                promptState
            }
        }
    }

    private func queryAnalysisSection(_ response: SemanticSearchResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Query Analysis")

            // Original → Normalized
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Original")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(response.query.originalQuery)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    Text("FTS Query")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(response.query.ftsQuery)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#9C27B0"))
                        .lineLimit(2)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)

            // Classification info
            HStack(spacing: 12) {
                // Primary intent
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.localized(.unifiedSearchIntent))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    HStack(spacing: 4) {
                        Image(systemName: response.classification.primaryIntent.iconName)
                            .font(.system(size: 11))
                        Text(response.classification.primaryIntent.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#00BCD4"))
                }

                // Confidence
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.localized(.unifiedSearchConfidence))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(Int(response.classification.confidence * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(confidenceColor(response.classification.confidence))
                }

                // Complexity
                VStack(alignment: .leading, spacing: 2) {
                    Text("Complexity")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(response.classification.queryComplexity.rawValue.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Language
                VStack(alignment: .leading, spacing: 2) {
                    Text("Language")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(response.query.detectedLanguage.rawValue.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
            }
            .padding(8)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)

            // Semantic keywords
            if !response.query.semanticKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Semantic Keywords")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    FlowLayout(spacing: 4) {
                        ForEach(response.query.semanticKeywords, id: \.self) { kw in
                            Text(kw)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(hex: "#9C27B0"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#9C27B0").opacity(0.12))
                                .cornerRadius(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Performance Tab

    private var performanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Current search metrics
                if let response = appState.unifiedSearchResponse {
                    performanceMetrics(response)
                }

                // Test harness
                testSection
            }
            .padding(16)
        }
    }

    private func performanceMetrics(_ response: SemanticSearchResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localization.localized(.unifiedSearchPerformance))

            HStack(spacing: 16) {
                metricCard(title: localization.localized(.unifiedSearchProcessingTime), value: "\(response.processingTimeMs)ms",
                          icon: "clock", color: "#00BCD4")
                metricCard(title: "Total Candidates", value: "\(response.totalCandidates)",
                          icon: "rectangle.stack", color: "#9C27B0")
                metricCard(title: "Final Results", value: "\(response.results.count)",
                          icon: "checkmark.circle", color: "#4CAF50")
                metricCard(title: localization.localized(.unifiedSearchConfidence),
                          value: "\(Int(response.classification.confidence * 100))%",
                          icon: "brain", color: confidenceHex(response.classification.confidence))
            }

            // Score distribution
            if !response.results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Score Distribution")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 2) {
                        ForEach(Array(response.results.prefix(20).enumerated()), id: \.offset) { idx, result in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(scoreColor(result.combinedScore))
                                .frame(width: max(4, (700 - 32) / CGFloat(min(20, response.results.count)) - 2),
                                       height: CGFloat(result.combinedScore) * 40 + 2)
                        }
                    }
                    .frame(height: 42, alignment: .bottom)
                }
                .padding(8)
                .background(Color.white.opacity(0.03))
                .cornerRadius(6)
            }
        }
    }

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader(localization.localized(.unifiedSearchRunTest))
                Spacer()
                Button(action: { runTests() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isRunningTests ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(isRunningTests ? "Running..." : localization.localized(.unifiedSearchRunTest))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isRunningTests ? Color.orange.opacity(0.4) : Color(hex: "#4CAF50").opacity(0.4))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(isRunningTests)
            }

            // Test queries list
            ForEach(testQueries) { query in
                testQueryRow(query)
            }

            // Test results summary
            if !testResults.isEmpty {
                testResultsSummary
            }
        }
    }

    private func testQueryRow(_ query: TestQueryItem) -> some View {
        HStack(spacing: 8) {
            Text(query.category)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(hex: query.categoryColor))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(hex: query.categoryColor).opacity(0.12))
                .cornerRadius(2)

            Text(query.query)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            if let result = testResults.first(where: { $0.queryId == query.id }) {
                HStack(spacing: 4) {
                    Text("\(result.resultCount) results")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(result.processingTimeMs)ms")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(result.processingTimeMs < 100 ? Color.green : Color.orange)
                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(result.passed ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.02))
        .cornerRadius(4)
    }

    private var testResultsSummary: some View {
        let passed = testResults.filter(\.passed).count
        let total = testResults.count
        let avgTime = testResults.isEmpty ? 0 : testResults.map(\.processingTimeMs).reduce(0, +) / testResults.count

        return HStack(spacing: 16) {
            metricCard(title: "Passed", value: "\(passed)/\(total)",
                      icon: "checkmark.circle", color: passed == total ? "#4CAF50" : "#FF9800")
            metricCard(title: "Avg Time", value: "\(avgTime)ms",
                      icon: "clock", color: avgTime < 100 ? "#4CAF50" : "#FF9800")
            metricCard(title: localization.localized(.unifiedSearchAccuracy),
                      value: total > 0 ? "\(Int(Double(passed) / Double(total) * 100))%" : "N/A",
                      icon: "target", color: "#00BCD4")
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    // MARK: - Shared Components

    private func sourceIndicator(_ source: SearchResultSource) -> some View {
        let (icon, color) = sourceStyle(source)
        return VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(sourceLabel(source))
                .font(.system(size: 7, weight: .medium))
        }
        .foregroundColor(Color(hex: color))
        .frame(width: 36)
    }

    private func scorePill(label: String, value: Float, color: String) -> some View {
        Text("\(label)\(Int(value * 100))")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color(hex: color).opacity(0.12))
            .cornerRadius(2)
    }

    private func scoreBar(label: String, value: Float, color: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 100, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color).opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func entityChip(_ entity: QueryEntity) -> some View {
        HStack(spacing: 3) {
            Text(entity.type.displayName)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
            Text(entity.value)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.06))
        .cornerRadius(3)
    }

    private func entityDetailRow(_ entity: QueryEntity) -> some View {
        HStack(spacing: 8) {
            Text(entity.type.displayName)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(entityTypeColor(entity.type))
                .frame(width: 60, alignment: .trailing)

            Text(entity.value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)

            if entity.originalSpan != entity.value {
                Text("(\(entity.originalSpan))")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Text("\(Int(entity.confidence * 100))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(confidenceColor(entity.confidence))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.03))
        .cornerRadius(4)
    }

    private func metricCard(title: String, value: String, icon: String, color: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.15))
            Text(localization.localized(.unifiedSearchNoResults))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Text(localization.localized(.unifiedSearchNoResultsDesc))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
            Spacer()
        }
    }

    private var promptState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.12))
            Text(localization.localized(.unifiedSearchPlaceholder))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Text("RAG + Semantic | Multi-dimensional Scoring")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
            Spacer()
        }
    }

    // MARK: - Logic

    private func executeSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.clearUnifiedSearch()
            return
        }

        switch selectedMode {
        case .all:
            appState.performUnifiedSearch(query: trimmed)
        case .rag:
            // RAG-only: use the RAG manager directly but wrap into SemanticSearchResponse
            appState.ragManager.search(query: trimmed)
            appState.performUnifiedSearch(query: trimmed)
        case .semantic:
            appState.performUnifiedSearch(query: trimmed)
        }
    }

    private func filteredResults(_ results: [SemanticSearchResult]) -> [SemanticSearchResult] {
        switch selectedMode {
        case .all:
            return results
        case .rag:
            return results.filter { $0.source == .ragFullText || $0.source == .ragRelationship }
        case .semantic:
            return results.filter { $0.source == .semanticExpansion || $0.source == .entityDirect || $0.source == .agentMemory }
        }
    }

    private func runTests() {
        isRunningTests = true
        testResults = []

        let orchestrator = appState.semanticOrchestrator
        let queries = testQueries
        Task { @MainActor in
            var results: [TestResultItem] = []
            for query in queries {
                let start = CFAbsoluteTimeGetCurrent()
                let response = orchestrator.search(query: query.query)
                let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

                let passed = !response.results.isEmpty && response.classification.confidence > 0.3
                results.append(TestResultItem(
                    queryId: query.id,
                    resultCount: response.results.count,
                    processingTimeMs: elapsed,
                    topScore: response.results.first?.combinedScore ?? 0,
                    detectedIntent: response.classification.primaryIntent.displayName,
                    passed: passed
                ))
            }

            testResults = results
            isRunningTests = false
        }
    }

    // MARK: - Helpers

    private func cleanSnippet(_ snippet: String) -> String {
        snippet.replacingOccurrences(of: ">>>", with: "")
               .replacingOccurrences(of: "<<<", with: "")
    }

    private func modeColor(_ mode: SearchViewMode) -> Color {
        switch mode {
        case .all: return Color(hex: "#9C27B0")
        case .rag: return Color(hex: "#FF9800")
        case .semantic: return Color(hex: "#00BCD4")
        }
    }

    private func scoreColor(_ score: Float) -> Color {
        if score >= 0.7 { return Color(hex: "#4CAF50") }
        if score >= 0.4 { return Color(hex: "#FF9800") }
        return Color(hex: "#F44336")
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.75 { return Color(hex: "#4CAF50") }
        if confidence >= 0.5 { return Color(hex: "#FF9800") }
        return Color(hex: "#F44336")
    }

    private func confidenceHex(_ confidence: Float) -> String {
        if confidence >= 0.75 { return "#4CAF50" }
        if confidence >= 0.5 { return "#FF9800" }
        return "#F44336"
    }

    private func sourceStyle(_ source: SearchResultSource) -> (String, String) {
        switch source {
        case .ragFullText: return ("text.book.closed.fill", "#FF9800")
        case .ragRelationship: return ("arrow.triangle.branch", "#E91E63")
        case .agentMemory: return ("brain", "#9C27B0")
        case .entityDirect: return ("target", "#4CAF50")
        case .semanticExpansion: return ("sparkles", "#00BCD4")
        }
    }

    private func sourceLabel(_ source: SearchResultSource) -> String {
        switch source {
        case .ragFullText: return "FTS"
        case .ragRelationship: return "Rel"
        case .agentMemory: return "Mem"
        case .entityDirect: return "Ent"
        case .semanticExpansion: return "Sem"
        }
    }

    private func entityTypeColor(_ type: QueryEntity.EntityType) -> Color {
        switch type {
        case .fileName, .filePath: return Color(hex: "#FF9800")
        case .className, .functionName, .variableName: return Color(hex: "#00BCD4")
        case .errorMessage: return Color(hex: "#F44336")
        case .frameworkName: return Color(hex: "#9C27B0")
        default: return Color(hex: "#4CAF50")
        }
    }
}

// MARK: - Flow Layout
// FlowLayout is defined in SkillBookView.swift — reused here via the shared definition.

// MARK: - Test Models

struct TestQueryItem: Identifiable {
    let id = UUID().uuidString
    let query: String
    let category: String
    let categoryColor: String
    let expectedIntent: String

    static let defaultQueries: [TestQueryItem] = [
        TestQueryItem(query: "find the search function in RAGSearchEngine", category: "Code", categoryColor: "#00BCD4", expectedIntent: "codeSearch"),
        TestQueryItem(query: "fix the crash in AppState", category: "Fix", categoryColor: "#F44336", expectedIntent: "codeFix"),
        TestQueryItem(query: "how does the semantic scoring work?", category: "Explain", categoryColor: "#4CAF50", expectedIntent: "codeExplain"),
        TestQueryItem(query: "AppState.swift", category: "File", categoryColor: "#FF9800", expectedIntent: "fileNavigation"),
        TestQueryItem(query: "what imports does ContentView use?", category: "Deps", categoryColor: "#9C27B0", expectedIntent: "dependencyQuery"),
        TestQueryItem(query: "refactor the database module", category: "Refactor", categoryColor: "#E91E63", expectedIntent: "codeRefactor"),
        TestQueryItem(query: "建立新的 API 端點", category: "CJK", categoryColor: "#FFD600", expectedIntent: "codeGenerate"),
        TestQueryItem(query: "error nil is not convertible", category: "Error", categoryColor: "#F44336", expectedIntent: "errorDiagnosis"),
    ]
}

struct TestResultItem: Identifiable {
    let id = UUID().uuidString
    let queryId: String
    let resultCount: Int
    let processingTimeMs: Int
    let topScore: Float
    let detectedIntent: String
    let passed: Bool
}
