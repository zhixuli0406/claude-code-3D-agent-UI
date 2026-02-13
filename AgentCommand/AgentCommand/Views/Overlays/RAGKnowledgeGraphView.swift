import SwiftUI

/// Modal sheet for RAG knowledge base management (H1)
struct RAGKnowledgeGraphView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedFileType: RAGFileType? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            tabContent
        }
        .frame(width: 680, height: 580)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#9C27B0"))
            Text(localization.localized(.ragKnowledgeBase))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Index status badge
            if appState.ragManager.isIndexing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(localization.localized(.ragIndexing))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(appState.ragManager.indexStats.totalDocuments) \(localization.localized(.ragDocuments).lowercased())")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Button(action: { appState.startRAGIndexing() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text(localization.localized(.ragReindex))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#9C27B0").opacity(0.3))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(appState.ragManager.isIndexing)

            Button(action: { appState.isRAGKnowledgeGraphVisible = false }) {
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
            tabButton(title: localization.localized(.ragDocuments), icon: "doc.text.fill", index: 0)
            tabButton(title: localization.localized(.ragKnowledgeGraph), icon: "point.3.connected.trianglepath.dotted", index: 1)
            tabButton(title: localization.localized(.ragSearch), icon: "magnifyingglass", index: 2)
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
            .foregroundColor(selectedTab == index ? Color(hex: "#9C27B0") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                selectedTab == index
                    ? Color(hex: "#9C27B0").opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: documentsTab
        case 1: graphTab
        case 2: searchTab
        default: documentsTab
        }
    }

    // MARK: - Documents Tab

    private var documentsTab: some View {
        VStack(spacing: 0) {
            // File type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(label: localization.localized(.filterAll), isSelected: selectedFileType == nil) {
                        selectedFileType = nil
                    }
                    ForEach(RAGFileType.allCases, id: \.self) { type in
                        let count = appState.ragManager.documents.filter { $0.fileType == type }.count
                        if count > 0 {
                            filterChip(label: "\(type.displayName) (\(count))", isSelected: selectedFileType == type) {
                                selectedFileType = type
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider().background(Color.white.opacity(0.1))

            // Document list
            if filteredDocuments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredDocuments) { doc in
                            documentRow(doc)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private var filteredDocuments: [RAGDocument] {
        if let type = selectedFileType {
            return appState.ragManager.documents.filter { $0.fileType == type }
        }
        return appState.ragManager.documents
    }

    private func documentRow(_ doc: RAGDocument) -> some View {
        HStack(spacing: 8) {
            // File type color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: doc.fileType.colorHex))
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.fileName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(doc.filePath)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(doc.lineCount) lines")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Text(doc.fileType.displayName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(hex: doc.fileType.colorHex))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(hex: doc.fileType.colorHex).opacity(0.15))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Graph Tab

    private var graphTab: some View {
        VStack(spacing: 12) {
            if appState.ragManager.documents.isEmpty {
                emptyState
            } else {
                // 3D scene toggle
                HStack {
                    Button(action: { appState.toggleRAGVisualization() }) {
                        HStack(spacing: 4) {
                            Image(systemName: appState.isRAGKnowledgeGraphInScene ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                            Text(appState.isRAGKnowledgeGraphInScene
                                 ? localization.localized(.ragHideFromScene)
                                 : localization.localized(.ragShowInScene))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#9C27B0").opacity(0.3))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Stats summary
                    HStack(spacing: 12) {
                        statBadge(icon: "doc.text", value: "\(appState.ragManager.documents.count)", label: "Files")
                        statBadge(icon: "arrow.triangle.branch", value: "\(appState.ragManager.relationships.count)", label: "Deps")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // File type distribution
                fileTypeDistribution

                // Relationship list
                if !appState.ragManager.relationships.isEmpty {
                    relationshipsList
                }

                Spacer()
            }
        }
    }

    private var fileTypeDistribution: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localization.localized(.ragFileType).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 16)

            let typeCounts = Dictionary(grouping: appState.ragManager.documents, by: \.fileType)
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
            let maxCount = typeCounts.first?.value ?? 1

            ForEach(typeCounts, id: \.key) { type, count in
                HStack(spacing: 8) {
                    Text(type.displayName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: type.colorHex))
                        .frame(width: 80, alignment: .trailing)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: type.colorHex).opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                    }
                    .frame(height: 12)

                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 30, alignment: .trailing)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }

    private var relationshipsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localization.localized(.ragRelationships).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(appState.ragManager.relationships.prefix(20).enumerated()), id: \.offset) { _, rel in
                        let sourceName = appState.ragManager.documents.first { $0.id == rel.sourceId }?.fileName ?? rel.sourceId
                        let targetName = appState.ragManager.documents.first { $0.id == rel.targetId }?.fileName ?? rel.targetId

                        HStack(spacing: 6) {
                            Text(sourceName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.3))

                            Text(targetName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.7))
                                .lineLimit(1)

                            Spacer()

                            Text(rel.type.rawValue)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 3)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))

                TextField(localization.localized(.ragSearch), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .onSubmit {
                        appState.ragManager.search(query: searchText)
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        appState.ragManager.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Search results
            if appState.ragManager.searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.2))
                    Text(localization.localized(.ragNoResults))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.ragManager.searchResults) { result in
                            searchResultRow(result)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func searchResultRow(_ result: RAGSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: result.document.fileType.colorHex))
                    .frame(width: 3, height: 20)

                Text(result.document.fileName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Text(String(format: "%.1f", result.score))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#9C27B0"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#9C27B0").opacity(0.15))
                    .cornerRadius(3)
            }

            // Matched snippet
            Text(result.matchedSnippet
                .replacingOccurrences(of: ">>>", with: "")
                .replacingOccurrences(of: "<<<", with: ""))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(3)
                .padding(.leading, 12)

            Text(result.document.filePath)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
                .lineLimit(1)
                .padding(.leading, 12)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Shared Components

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.15))
            Text(localization.localized(.ragNoDocuments))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
            Button(action: { appState.startRAGIndexing() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text(localization.localized(.ragReindex))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(hex: "#9C27B0").opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color(hex: "#9C27B0").opacity(0.3) : Color.white.opacity(0.05))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#9C27B0"))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
