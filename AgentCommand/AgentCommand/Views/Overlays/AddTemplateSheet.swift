import SwiftUI

struct AddTemplateSheet: View {
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let editingTemplate: PromptTemplate?
    let onSave: (PromptTemplate) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var category: TemplateCategory = .custom
    @State private var content = ""
    @State private var tagsText = ""

    // Auto-detected variables
    @State private var detectedVariables: [EditableVariable] = []

    private var isEditing: Bool { editingTemplate != nil }

    init(editingTemplate: PromptTemplate?, onSave: @escaping (PromptTemplate) -> Void) {
        self.editingTemplate = editingTemplate
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                    .foregroundColor(isEditing ? .cyan : .green)
                    .font(.title2)
                Text(isEditing ? localization.localized(.editTemplate) : localization.localized(.addTemplate))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.05))

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    fieldSection(localization.localized(.templateName), icon: "textformat") {
                        TextField(localization.localized(.templateName), text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }

                    // Description
                    fieldSection(localization.localized(.templateDescription), icon: "text.alignleft") {
                        TextField(localization.localized(.templateDescription), text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }

                    // Category
                    fieldSection(localization.localized(.templateCategory), icon: "folder.fill") {
                        HStack(spacing: 6) {
                            ForEach(TemplateCategory.allCases, id: \.self) { cat in
                                Button(action: { category = cat }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 10))
                                        Text(cat.displayName)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(category == cat ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(category == cat ? Color(hex: cat.themeColor).opacity(0.3) : Color.white.opacity(0.05))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Content
                    fieldSection(localization.localized(.templateContent), icon: "doc.text") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextEditor(text: $content)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120, maxHeight: 200)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                                .onChange(of: content) {
                                    updateDetectedVariables()
                                }

                            Text("Use {{variableName}} for dynamic variables")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Detected Variables
                    if !detectedVariables.isEmpty {
                        fieldSection(localization.localized(.templateVariables), icon: "curlybraces") {
                            VStack(spacing: 6) {
                                ForEach($detectedVariables) { $variable in
                                    HStack(spacing: 8) {
                                        Text("{{\(variable.key)}}")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.cyan)
                                            .frame(width: 100, alignment: .leading)

                                        TextField("Display Name", text: $variable.displayName)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))

                                        TextField("Default", text: $variable.defaultValue)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                                    }
                                }
                            }
                        }
                    }

                    // Tags
                    fieldSection(localization.localized(.templateTags), icon: "tag") {
                        TextField("tag1, tag2, tag3", text: $tagsText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }

                    // Preview
                    if !content.isEmpty {
                        fieldSection(localization.localized(.templatePreview), icon: "eye") {
                            Text(previewContent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                        }
                    }
                }
                .padding()
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Spacer()
                Button(localization.localized(.cancel)) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                Button(action: saveTemplate) {
                    Text(isEditing ? localization.localized(.editTemplate) : localization.localized(.addTemplate))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(canSave ? Color.cyan : Color.gray.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 520, height: 600)
        .background(Color(hex: "#0D1117"))
        .onAppear {
            if let t = editingTemplate {
                name = t.name
                description = t.description
                category = t.category
                content = t.content
                tagsText = t.tags.joined(separator: ", ")
                detectedVariables = t.variables.map {
                    EditableVariable(key: $0.key, displayName: $0.displayName, defaultValue: $0.defaultValue)
                }
            }
        }
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.secondary)
            content()
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var previewContent: String {
        var result = content
        for v in detectedVariables {
            let replacement = v.defaultValue.isEmpty ? "[\(v.displayName)]" : v.defaultValue
            result = result.replacingOccurrences(of: "{{\(v.key)}}", with: replacement)
        }
        return result
    }

    private func updateDetectedVariables() {
        let keys = PromptTemplate.extractVariables(from: content)
        let existingMap = Dictionary(uniqueKeysWithValues: detectedVariables.map { ($0.key, $0) })

        detectedVariables = keys.map { key in
            if let existing = existingMap[key] {
                return existing
            }
            // Auto-generate display name from key
            let displayName = key
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
            return EditableVariable(key: key, displayName: displayName, defaultValue: "")
        }
    }

    private func saveTemplate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let variables = detectedVariables.map {
            TemplateVariable(key: $0.key, displayName: $0.displayName, defaultValue: $0.defaultValue)
        }

        let now = Date()
        let template = PromptTemplate(
            id: editingTemplate?.id ?? "custom:\(UUID().uuidString)",
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespaces),
            category: category,
            content: content,
            variables: variables,
            tags: tags,
            isBuiltIn: false,
            createdAt: editingTemplate?.createdAt ?? now,
            updatedAt: now
        )

        onSave(template)
        dismiss()
    }
}

// MARK: - Editable Variable

private struct EditableVariable: Identifiable {
    let id = UUID()
    let key: String
    var displayName: String
    var defaultValue: String
}
