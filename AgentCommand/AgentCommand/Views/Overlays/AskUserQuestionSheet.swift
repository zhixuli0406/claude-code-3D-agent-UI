import SwiftUI

struct AskUserQuestionSheet: View {
    let data: AskUserQuestionData
    let onSubmit: ([UserQuestionAnswer]) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var localization: LocalizationManager

    // Per-question selection state: [questionId: Set<optionLabel>]
    @State private var selections: [UUID: Set<String>] = [:]
    // Per-question custom text: [questionId: String]
    @State private var customTexts: [UUID: String] = [:]
    // Track which questions have custom input expanded
    @State private var showCustomInput: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(data.questions) { question in
                        questionView(question)
                    }
                }
                .padding(.horizontal, 4)
            }

            buttonsView
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 300, idealHeight: 400)
        .padding(24)
        .background(Color(hex: "#0D1117"))
        .onAppear { initializeSelections() }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundColor(Color(hex: "#2196F3"))

            Text(localization.localized(.askUserQuestion))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - Question

    @ViewBuilder
    private func questionView(_ question: UserQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header badge + question text
            if !question.header.isEmpty {
                Text(question.header.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00BCD4").opacity(0.15))
                    .cornerRadius(3)
            }

            Text(question.question)
                .font(.subheadline)
                .foregroundColor(.white)

            // Options
            let currentSelections = selections[question.id] ?? []
            ForEach(question.options) { option in
                let isSelected = currentSelections.contains(option.label)
                optionCard(
                    option: option,
                    isSelected: isSelected,
                    isMultiSelect: question.multiSelect
                ) {
                    toggleSelection(questionId: question.id, label: option.label, multiSelect: question.multiSelect)
                }
            }

            // Custom answer toggle
            Button(action: {
                if showCustomInput.contains(question.id) {
                    showCustomInput.remove(question.id)
                } else {
                    showCustomInput.insert(question.id)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showCustomInput.contains(question.id) ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text(localization.localized(.customAnswer))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if showCustomInput.contains(question.id) {
                TextField(localization.localized(.customAnswer), text: Binding(
                    get: { customTexts[question.id] ?? "" },
                    set: { customTexts[question.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Option Card

    @ViewBuilder
    private func optionCard(option: QuestionOption, isSelected: Bool, isMultiSelect: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Selection indicator
                Image(systemName: isMultiSelect
                    ? (isSelected ? "checkmark.square.fill" : "square")
                    : (isSelected ? "largecircle.fill.circle" : "circle")
                )
                .foregroundColor(isSelected ? Color(hex: "#00BCD4") : .secondary)
                .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    if let desc = option.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(hex: "#00BCD4").opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color(hex: "#00BCD4") : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Buttons

    private var buttonsView: some View {
        HStack {
            Button(action: onCancel) {
                Text(localization.localized(.skipQuestion))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: submit) {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(.caption)
                    Text(localization.localized(.submitAnswer))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "#00BCD4"))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!hasAnySelection)
        }
    }

    // MARK: - Logic

    private var hasAnySelection: Bool {
        for question in data.questions {
            let selected = selections[question.id] ?? []
            let custom = customTexts[question.id] ?? ""
            if !selected.isEmpty || !custom.isEmpty {
                return true
            }
        }
        return false
    }

    private func initializeSelections() {
        for question in data.questions {
            selections[question.id] = []
            customTexts[question.id] = ""
        }
    }

    private func toggleSelection(questionId: UUID, label: String, multiSelect: Bool) {
        var current = selections[questionId] ?? []
        if multiSelect {
            if current.contains(label) {
                current.remove(label)
            } else {
                current.insert(label)
            }
        } else {
            current = current.contains(label) ? [] : [label]
        }
        selections[questionId] = current
    }

    private func submit() {
        let answers: [UserQuestionAnswer] = data.questions.map { question in
            let selected = Array(selections[question.id] ?? [])
            let custom = customTexts[question.id]
            return UserQuestionAnswer(
                questionId: question.id,
                selectedOptions: selected,
                customText: custom?.isEmpty == true ? nil : custom
            )
        }
        onSubmit(answers)
    }
}
