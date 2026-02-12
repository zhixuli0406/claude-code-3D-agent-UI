import SwiftUI

struct ModelComparisonView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var comparisonPrompt = ""
    @State private var selectedModels: Set<ClaudeModel> = [.opus, .sonnet]
    @State private var comparisonTaskIds: [ClaudeModel: UUID] = [:]
    @State private var isComparing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(localization.localized(.modelComparison))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { appState.isModelComparisonVisible = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.05))

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 12) {
                // Model selection checkboxes
                HStack(spacing: 16) {
                    Text(localization.localized(.modelSelector))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ForEach(ClaudeModel.allCases.sorted(by: { $0.sortOrder > $1.sortOrder })) { model in
                        Toggle(isOn: Binding(
                            get: { selectedModels.contains(model) },
                            set: { isOn in
                                if isOn { selectedModels.insert(model) }
                                else { selectedModels.remove(model) }
                            }
                        )) {
                            HStack(spacing: 4) {
                                Text(model.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: model.hexColor))
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }

                // Prompt input
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .foregroundColor(Color(hex: "#00BCD4"))
                        .font(.system(size: 14))

                    TextField(localization.localized(.typeComparisonPrompt), text: $comparisonPrompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .onSubmit { startComparison() }

                    Button(action: startComparison) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text(localization.localized(.compare))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(canCompare ? Color(hex: "#00BCD4") : Color.gray.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCompare)
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .padding(.horizontal)

            // Side-by-side results
            if !comparisonTaskIds.isEmpty {
                Divider().background(Color.white.opacity(0.1))

                HStack(alignment: .top, spacing: 1) {
                    ForEach(
                        Array(comparisonTaskIds.keys).sorted(by: { $0.sortOrder > $1.sortOrder }),
                        id: \.self
                    ) { model in
                        if let taskId = comparisonTaskIds[model] {
                            ComparisonColumnView(model: model, taskId: taskId)
                        }
                    }
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right.circle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(localization.localized(.modelComparisonResults))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(hex: "#0D1117"))
    }

    private var canCompare: Bool {
        !comparisonPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedModels.count >= 2
        && !isComparing
    }

    private func startComparison() {
        let prompt = comparisonPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, selectedModels.count >= 2 else { return }

        isComparing = true
        comparisonTaskIds.removeAll()

        for model in selectedModels.sorted(by: { $0.sortOrder > $1.sortOrder }) {
            // Create a minimal team (commander only) for each model
            let teamAgents = AgentFactory.createTeam(subAgentCount: 0, model: model)
            guard let commander = teamAgents.first else { continue }

            appState.agents.append(contentsOf: teamAgents)
            appState.rebuildScene()
            appState.submitPromptTask(title: prompt, assignTo: commander.id)

            if let task = appState.tasks.last {
                comparisonTaskIds[model] = task.id
            }
        }

        isComparing = false
    }
}

struct ComparisonColumnView: View {
    let model: ClaudeModel
    let taskId: UUID
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Text(model.displayName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: model.hexColor))
                Spacer()
                if let task = appState.tasks.first(where: { $0.id == taskId }) {
                    TaskStatusBadge(status: task.status)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(hex: model.hexColor).opacity(0.1))

            // CLI output
            ScrollView {
                CLIOutputView(
                    entries: appState.cliProcessManager.outputEntries(for: taskId),
                    scrollToEntryId: nil
                )
                .environmentObject(localization)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }
}
