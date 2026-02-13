import SwiftUI

/// Bottom overlay showing unified search results when typing in prompt bar (H1+H5)
/// Shows both RAG keyword results and semantic search results with multi-dimensional scores
struct RAGSearchResultsOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    let onSelectSnippet: (String) -> Void

    /// Whether semantic results are available
    private var hasSemanticResults: Bool {
        appState.unifiedSearchResponse?.hasResults == true
    }

    /// Prefer semantic results when available, fall back to basic RAG results
    private var displayMode: DisplayMode {
        if hasSemanticResults { return .semantic }
        if !appState.ragManager.searchResults.isEmpty { return .rag }
        return .none
    }

    enum DisplayMode {
        case semantic, rag, none
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            resultCards
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#9C27B0").opacity(0.3), Color(hex: "#00BCD4").opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: hasSemanticResults ? "brain.head.profile" : "text.book.closed.fill")
                .font(.system(size: 10))
                .foregroundColor(hasSemanticResults ? Color(hex: "#00BCD4") : Color(hex: "#9C27B0"))

            Text(localization.localized(.ragSearchResults).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            // Intent badge (when semantic results available)
            if let response = appState.unifiedSearchResponse {
                HStack(spacing: 2) {
                    Image(systemName: response.classification.primaryIntent.iconName)
                        .font(.system(size: 7))
                    Text(response.classification.primaryIntent.displayName)
                        .font(.system(size: 7, weight: .medium))
                }
                .foregroundColor(Color(hex: "#00BCD4"))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(hex: "#00BCD4").opacity(0.12))
                .cornerRadius(2)
            }

            Spacer()

            // Result count
            let count = hasSemanticResults
                ? (appState.unifiedSearchResponse?.results.count ?? 0)
                : appState.ragManager.searchResults.count
            Text("\(count) results")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            // Open full search button
            Button(action: { appState.isUnifiedSearchVisible = true }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(localization.localized(.unifiedSearch))

            // Clear button
            Button(action: {
                appState.ragManager.searchResults = []
                appState.clearUnifiedSearch()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Result Cards

    private var resultCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                switch displayMode {
                case .semantic:
                    if let response = appState.unifiedSearchResponse {
                        ForEach(response.results.prefix(8), id: \.id) { result in
                            semanticResultCard(result)
                        }
                    }
                case .rag:
                    ForEach(appState.ragManager.searchResults.prefix(6)) { result in
                        ragResultCard(result)
                    }
                case .none:
                    EmptyView()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Semantic Result Card

    private func semanticResultCard(_ result: SemanticSearchResult) -> some View {
        Button(action: {
            if let rag = result.ragResult {
                let snippet = rag.matchedSnippet
                    .replacingOccurrences(of: ">>>", with: "")
                    .replacingOccurrences(of: "<<<", with: "")
                onSelectSnippet("[\(rag.document.fileName)] \(snippet)")
            } else if let memory = result.memoryResult {
                onSelectSnippet("[Memory: \(memory.agentName)] \(memory.summary)")
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // File header with source indicator
                HStack(spacing: 4) {
                    sourceIndicator(result.source)

                    if let rag = result.ragResult {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: rag.document.fileType.colorHex))
                            .frame(width: 2, height: 14)

                        Text(rag.document.fileName)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else if let memory = result.memoryResult {
                        Text(memory.agentName)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }

                // Snippet preview
                let snippetText: String = {
                    if let rag = result.ragResult {
                        return rag.matchedSnippet
                            .replacingOccurrences(of: ">>>", with: "")
                            .replacingOccurrences(of: "<<<", with: "")
                    } else if let memory = result.memoryResult {
                        return memory.summary
                    }
                    return result.snippetWithHighlights
                }()

                Text(snippetText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)

                // Multi-dimensional score bar
                HStack(spacing: 3) {
                    miniScoreDot(value: result.keywordScore, color: "#FF9800")
                    miniScoreDot(value: result.semanticRelevance, color: "#00BCD4")
                    miniScoreDot(value: result.entityMatchScore, color: "#4CAF50")

                    Spacer()

                    // Combined score
                    Text(String(format: "%.0f%%", result.combinedScore * 100))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(scoreColor(result.combinedScore))

                    Image(systemName: "plus.circle")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "#9C27B0").opacity(0.6))
                }
            }
            .padding(8)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - RAG Result Card (legacy fallback)

    private func ragResultCard(_ result: RAGSearchResult) -> some View {
        Button(action: {
            let snippet = result.matchedSnippet
                .replacingOccurrences(of: ">>>", with: "")
                .replacingOccurrences(of: "<<<", with: "")
            onSelectSnippet("[\(result.document.fileName)] \(snippet)")
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: result.document.fileType.colorHex))
                        .frame(width: 2, height: 14)

                    Text(result.document.fileName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Text(result.matchedSnippet
                    .replacingOccurrences(of: ">>>", with: "")
                    .replacingOccurrences(of: "<<<", with: ""))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(result.document.fileType.displayName)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(Color(hex: result.document.fileType.colorHex))

                    Spacer()

                    Text(String(format: "%.1f", result.score))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF9800"))

                    Image(systemName: "plus.circle")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "#9C27B0").opacity(0.6))
                }
            }
            .padding(8)
            .frame(width: 180)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sourceIndicator(_ source: SearchResultSource) -> some View {
        let (icon, color) = sourceStyle(source)
        return Image(systemName: icon)
            .font(.system(size: 7))
            .foregroundColor(Color(hex: color))
    }

    private func miniScoreDot(value: Float, color: String) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(hex: color).opacity(Double(max(0.2, value))))
            .frame(width: max(4, CGFloat(value) * 20), height: 4)
    }

    private func scoreColor(_ score: Float) -> Color {
        if score >= 0.7 { return Color(hex: "#4CAF50") }
        if score >= 0.4 { return Color(hex: "#FF9800") }
        return Color(hex: "#F44336")
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
}
