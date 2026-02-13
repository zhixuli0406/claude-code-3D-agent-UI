import SwiftUI

// MARK: - J1: Code Knowledge Graph Status Overlay (right-side floating panel)

struct CodeKnowledgeGraphOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#FF6F00").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FF6F00").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FF6F00"))
            Text(localization.localized(.codeKnowledgeGraph))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.codeKnowledgeGraphManager.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let stats = appState.codeKnowledgeGraphManager.stats

            HStack {
                Text(localization.localized(.ckgTotalFiles))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalFiles)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.ckgDependencies))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalDependencies)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.ckgAvgComplexity))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.1f", stats.avgComplexity))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: stats.avgComplexity > 20 ? "#F44336" : stats.avgComplexity > 10 ? "#FF9800" : "#4CAF50"))
            }

            if !stats.mostConnectedFile.isEmpty {
                HStack {
                    Text(localization.localized(.ckgMostConnected))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(stats.mostConnectedFile)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF6F00"))
                        .lineLimit(1)
                }
            }

            // Recent files
            ForEach(appState.codeKnowledgeGraphManager.fileNodes.prefix(3)) { node in
                fileRow(node)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func fileRow(_ node: CodeFileNode) -> some View {
        HStack(spacing: 4) {
            Image(systemName: node.type.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: node.type.hexColor))
            Text(node.name)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text("\(node.lineCount)L")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
