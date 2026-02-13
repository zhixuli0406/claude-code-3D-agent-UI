import SwiftUI
import Combine

struct PromptInputBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var promptText = ""
    @State private var showConfirmation = false
    @State private var showVariableSheet = false
    @State private var pendingTemplate: PromptTemplate?
    @State private var variableValues: [String: String] = [:]

    // Live quality analysis state
    @State private var liveScore: PromptQualityScore?
    @State private var analysisCancellable: AnyCancellable?
    @State private var analysisSubject = PassthroughSubject<String, Never>()

    private var templateManager: PromptTemplateManager { appState.promptTemplateManager }

    var body: some View {
        HStack(spacing: 10) {
            // LIVE mode indicator
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text(localization.localized(.live))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.1))
            .cornerRadius(4)

            // New team indicator
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                Text(localization.localized(.newTeamAutoCreated))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)

            // G2: Template quick-select menu
            templateMenuButton

            // G1: Model selector
            ModelSelectorButton(selectedModel: $appState.selectedModelForNewTeam)

            // Unified Knowledge Search button
            Button(action: { appState.isUnifiedSearchVisible = true }) {
                HStack(spacing: 3) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10))
                    Text(localization.localized(.ragSearch))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#9C27B0"))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "#9C27B0").opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Terminal icon
            Image(systemName: "terminal")
                .foregroundColor(Color(hex: "#00BCD4"))
                .font(.system(size: 14))

            // Live quality badge
            if let score = liveScore, !promptText.isEmpty {
                Text(score.gradeLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: score.gradeColorHex))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: score.gradeColorHex).opacity(0.15))
                    .cornerRadius(3)
                    .help("Quality: \(score.overallPercentage)%")
            }

            // Text field
            TextField(localization.localized(.typeTaskPrompt), text: $promptText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .onSubmit {
                    submitTask()
                }
                .onChange(of: promptText) { _, newValue in
                    analysisSubject.send(newValue)
                }

            // Send button
            Button(action: { submitTask() }) {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                    Text(localization.localized(.send))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(promptText.isEmpty ? Color.gray.opacity(0.3) : Color(hex: "#00BCD4"))
                )
            }
            .buttonStyle(.plain)
            .disabled(promptText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#0D1117").opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#00BCD4").opacity(0.3)),
            alignment: .top
        )
        .overlay(
            confirmationBanner
        )
        .sheet(isPresented: $showVariableSheet) {
            if let template = pendingTemplate {
                TemplateVariableInputSheet(
                    template: template,
                    variableValues: $variableValues,
                    onSubmit: { values in
                        let rendered = template.render(with: values)
                        promptText = rendered
                        showVariableSheet = false
                        pendingTemplate = nil
                    },
                    onCancel: {
                        showVariableSheet = false
                        pendingTemplate = nil
                    }
                )
                .environmentObject(localization)
            }
        }
        .onAppear {
            analysisCancellable = analysisSubject
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .removeDuplicates()
                .sink { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.count >= 3 {
                        liveScore = appState.promptOptimizationManager.quickAnalyze(trimmed)
                    } else {
                        liveScore = nil
                    }
                }
        }
    }

    // MARK: - Template Menu Button

    private var templateMenuButton: some View {
        Menu {
            // Recent templates
            let recents = templateManager.recentTemplates()
            if !recents.isEmpty {
                Section(localization.localized(.recentTemplates)) {
                    ForEach(recents, id: \.id) { template in
                        Button(action: { selectTemplate(template) }) {
                            Label(template.name, systemImage: template.category.icon)
                        }
                    }
                }
            }

            Divider()

            // By category
            ForEach(TemplateCategory.allCases, id: \.self) { category in
                let templates = templateManager.templates(for: category)
                if !templates.isEmpty {
                    Section(category.displayName) {
                        ForEach(templates.prefix(4), id: \.id) { template in
                            Button(action: { selectTemplate(template) }) {
                                Label(template.name, systemImage: template.category.icon)
                            }
                        }
                    }
                }
            }

            Divider()

            // Browse all
            Button(action: { appState.isTemplateGalleryVisible = true }) {
                Label(localization.localized(.browseAllTemplates), systemImage: "square.grid.2x2")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11))
                Text(localization.localized(.promptTemplates))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#00BCD4"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: "#00BCD4").opacity(0.1))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func selectTemplate(_ template: PromptTemplate) {
        templateManager.recordUsage(templateId: template.id)

        if template.variables.isEmpty {
            promptText = template.content
        } else {
            variableValues = [:]
            for v in template.variables {
                variableValues[v.key] = v.defaultValue
            }
            pendingTemplate = template
            showVariableSheet = true
        }
    }

    @ViewBuilder
    private var confirmationBanner: some View {
        if showConfirmation {
            Text(localization.localized(.taskCreated))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#4CAF50"))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(hex: "#4CAF50").opacity(0.15))
                .cornerRadius(4)
                .offset(y: -30)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func submitTask() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.submitPromptSmart(title: trimmed)
        promptText = ""

        withAnimation(.easeInOut(duration: 0.3)) {
            showConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConfirmation = false
            }
        }
    }
}

// MARK: - Template Variable Input Sheet

struct TemplateVariableInputSheet: View {
    @EnvironmentObject var localization: LocalizationManager
    let template: PromptTemplate
    @Binding var variableValues: [String: String]
    let onSubmit: ([String: String]) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: template.category.icon)
                    .foregroundColor(Color(hex: template.category.themeColor))
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.05))

            Divider().opacity(0.3)

            // Variables form
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localization.localized(.templateVariables))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ForEach(template.variables, id: \.key) { variable in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(variable.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                Text("{{\(variable.key)}}")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.cyan.opacity(0.6))
                            }
                            TextField(
                                variable.defaultValue.isEmpty
                                    ? localization.localized(.templateVariablePlaceholder)
                                    : variable.defaultValue,
                                text: Binding(
                                    get: { variableValues[variable.key] ?? variable.defaultValue },
                                    set: { variableValues[variable.key] = $0 }
                                )
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                        }
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.localized(.templatePreview))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(template.render(with: variableValues))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                    }
                }
                .padding()
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Spacer()
                Button(localization.localized(.cancel), action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                Button(action: { onSubmit(variableValues) }) {
                    Text(localization.localized(.useTemplate))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.cyan))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .frame(width: 440, height: 420)
        .background(Color(hex: "#0D1117"))
    }
}
