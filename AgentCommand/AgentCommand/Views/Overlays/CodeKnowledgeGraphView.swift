import SwiftUI

/// Modal sheet for Code Knowledge Graph detail view (J1)
struct CodeKnowledgeGraphDetailView: View {
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
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#FF6F00"))
            Text(localization.localized(.codeKnowledgeGraph))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if appState.codeKnowledgeGraphManager.isAnalyzing {
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.6)
                    Text(localization.localized(.ckgAnalyzing))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF9800"))
                }
            }

            // Stats badge
            Text("\(appState.codeKnowledgeGraphManager.stats.totalFiles) files")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FF6F00"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#FF6F00").opacity(0.1))
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
            tabButton(title: localization.localized(.ckgFileDependencies), icon: "point.3.connected.trianglepath.dotted", index: 0)
            tabButton(title: localization.localized(.ckgFunctionCalls), icon: "arrow.triangle.turn.up.right.diamond.fill", index: 1)
            tabButton(title: localization.localized(.ckgArchitectureOverview), icon: "building.columns.fill", index: 2)
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
            .foregroundColor(selectedTab == index ? Color(hex: "#FF6F00") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(hex: "#FF6F00").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: fileDependenciesTab
        case 1: functionCallsTab
        case 2: architectureTab
        default: fileDependenciesTab
        }
    }

    // MARK: - File Dependencies Tab

    private var fileDependenciesTab: some View {
        VStack(spacing: 0) {
            // Summary stats
            HStack(spacing: 16) {
                statBadge(icon: "doc.fill", value: "\(appState.codeKnowledgeGraphManager.stats.totalFiles)", label: localization.localized(.ckgTotalFiles))
                statBadge(icon: "arrow.triangle.branch", value: "\(appState.codeKnowledgeGraphManager.stats.totalDependencies)", label: localization.localized(.ckgDependencies))
                statBadge(icon: "gauge.with.needle", value: String(format: "%.1f", appState.codeKnowledgeGraphManager.stats.avgComplexity), label: localization.localized(.ckgAvgComplexity))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    appState.codeKnowledgeGraphManager.analyzeProject(directory: appState.workspaceManager.activeDirectory)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text(localization.localized(.ckgAnalyze))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#FF6F00"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#FF6F00").opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: { appState.toggleCodeKnowledgeGraphVisualization() }) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isCodeKnowledgeGraphInScene ? "eye.slash" : "eye")
                        Text(appState.isCodeKnowledgeGraphInScene ? localization.localized(.ckgHideFromScene) : localization.localized(.ckgShowInScene))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // File list
            if appState.codeKnowledgeGraphManager.fileNodes.isEmpty {
                emptyState(icon: "point.3.connected.trianglepath.dotted", message: localization.localized(.ckgNoFiles))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.codeKnowledgeGraphManager.fileNodes) { node in
                            fileCard(node)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func fileCard(_ node: CodeFileNode) -> some View {
        Button(action: {
            appState.codeKnowledgeGraphManager.highlightAffectedFiles(fileId: node.id)
        }) {
            HStack(spacing: 8) {
                Image(systemName: node.type.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: node.type.hexColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(node.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(node.lineCount) lines")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text("C:\(node.complexity)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: node.complexity > 20 ? "#F44336" : node.complexity > 10 ? "#FF9800" : "#4CAF50"))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(node.isHighlighted ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: node.isHighlighted ? "#FF6F00" : "#FFFFFF").opacity(node.isHighlighted ? 0.3 : 0.06), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Function Calls Tab

    private var functionCallsTab: some View {
        VStack(spacing: 0) {
            if appState.codeKnowledgeGraphManager.callChains.isEmpty {
                emptyState(icon: "arrow.triangle.turn.up.right.diamond.fill", message: localization.localized(.ckgNoFunctionCalls))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.codeKnowledgeGraphManager.callChains) { chain in
                            HStack(spacing: 8) {
                                Text(chain.callerFunction)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "#FF6F00"))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(chain.calleeFunction)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "#42A5F5"))
                                Spacer()
                                Text("×\(chain.callCount)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
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

    // MARK: - Architecture Tab

    private var architectureTab: some View {
        VStack(spacing: 0) {
            // Architecture overview
            HStack(spacing: 16) {
                statBadge(icon: "doc.fill", value: "\(appState.codeKnowledgeGraphManager.fileNodes.filter { $0.type == .swiftFile }.count)", label: "Swift Files")
                statBadge(icon: "checkmark.shield.fill", value: "\(appState.codeKnowledgeGraphManager.fileNodes.filter { $0.type == .test }.count)", label: "Tests")
                statBadge(icon: "gearshape.fill", value: "\(appState.codeKnowledgeGraphManager.fileNodes.filter { $0.type == .config }.count)", label: "Configs")
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.1))

            // Dependency type breakdown
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(DependencyType.allCases, id: \.rawValue) { depType in
                        let count = appState.codeKnowledgeGraphManager.edges.filter { $0.edgeType == depType }.count
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: depType.hexColor))
                                .frame(width: 8, height: 8)
                            Text(depType.rawValue.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: depType.hexColor))
                        }
                    }
                }
                .padding(16)
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
            .foregroundColor(Color(hex: "#FF6F00"))
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
