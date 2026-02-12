import SwiftUI

struct PromptTemplateGalleryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var searchText = ""
    @State private var selectedCategory: TemplateCategory?
    @State private var selectedTemplate: PromptTemplate?
    @State private var showAddSheet = false
    @State private var editingTemplate: PromptTemplate?
    @State private var showDeleteConfirm = false
    @State private var templateToDelete: PromptTemplate?
    @State private var showToast = false
    @State private var toastMessage = ""

    // Variable input state
    @State private var variableValues: [String: String] = [:]
    @State private var showVariableInput = false

    private var manager: PromptTemplateManager { appState.promptTemplateManager }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.3)
            HSplitView {
                categorySidebar
                    .frame(minWidth: 130, maxWidth: 150)
                if let template = selectedTemplate {
                    templateDetailPanel(template)
                } else {
                    templateGrid
                        .frame(minWidth: 350)
                }
            }
        }
        .frame(width: 620, height: 520)
        .background(Color(hex: "#0D1117"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .sheet(isPresented: $showAddSheet) {
            AddTemplateSheet(editingTemplate: nil) { newTemplate in
                manager.addCustomTemplate(newTemplate)
                showToastMessage(localization.localized(.templateSaveSuccess))
            }
            .environmentObject(localization)
        }
        .sheet(item: $editingTemplate) { template in
            AddTemplateSheet(editingTemplate: template) { updated in
                manager.updateCustomTemplate(updated)
                selectedTemplate = updated
                showToastMessage(localization.localized(.templateSaveSuccess))
            }
            .environmentObject(localization)
        }
        .alert(localization.localized(.templateDeleteConfirm), isPresented: $showDeleteConfirm) {
            Button(localization.localized(.cancel), role: .cancel) {}
            Button(localization.localized(.deleteTemplate), role: .destructive) {
                if let t = templateToDelete {
                    manager.removeCustomTemplate(id: t.id)
                    selectedTemplate = nil
                }
            }
        }
        .overlay(toastOverlay, alignment: .top)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.cyan)
                .font(.title2)
            Text(localization.localized(.templateGallery))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField(localization.localized(.searchTemplates), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: 160)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))

            // Add button
            Button(action: { showAddSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(localization.localized(.addTemplate))

            // Close button
            Button(action: { appState.isTemplateGalleryVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Category Sidebar

    private var categorySidebar: some View {
        VStack(spacing: 2) {
            // All
            categoryButton(label: localization.localized(.filterAll), icon: "square.grid.2x2.fill", color: .cyan, count: manager.allTemplates().count, isSelected: selectedCategory == nil) {
                selectedCategory = nil
                selectedTemplate = nil
            }

            Divider().padding(.vertical, 4)

            // Each category
            ForEach(TemplateCategory.allCases, id: \.self) { category in
                let localizedName = localizedCategoryName(category)
                categoryButton(label: localizedName, icon: category.icon, color: Color(hex: category.themeColor), count: manager.templateCount(for: category), isSelected: selectedCategory == category) {
                    selectedCategory = category
                    selectedTemplate = nil
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 9))
                    Text(localization.localized(.builtInTemplates))
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)

                Text("\(PreBuiltTemplateCatalog.allTemplates.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.8))

                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 9))
                    Text(localization.localized(.customTemplates))
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)

                Text("\(manager.customTemplates.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple.opacity(0.8))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
    }

    private func categoryButton(label: String, icon: String, color: Color, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? color.opacity(0.15) : Color.clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        ScrollView {
            if filteredTemplates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(localization.localized(.noTemplatesFound))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(filteredTemplates, id: \.id) { template in
                        templateCard(template)
                            .onTapGesture {
                                selectedTemplate = template
                            }
                    }
                }
                .padding()
            }
        }
    }

    private func templateCard(_ template: PromptTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon + category
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: template.category.themeColor).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: template.category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: template.category.themeColor))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(localizedCategoryName(template.category))
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: template.category.themeColor).opacity(0.8))
                }

                Spacer()

                if manager.isFavorite(templateId: template.id) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
            }

            // Description
            Text(template.description)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)

            // Tags
            if !template.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(template.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8))
                            .foregroundColor(.cyan.opacity(0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.cyan.opacity(0.1)))
                    }
                }
            }

            // Variables count
            if !template.variables.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 9))
                    Text("\(template.variables.count) \(localization.localized(.templateVariables))")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Detail Panel

    private func templateDetailPanel(_ template: PromptTemplate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Back button
                Button(action: { selectedTemplate = nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)

                // Title
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: template.category.themeColor).opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: template.category.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: template.category.themeColor))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            Label(localizedCategoryName(template.category), systemImage: template.category.icon)
                            if template.isBuiltIn {
                                Label(localization.localized(.builtInTemplates), systemImage: "checkmark.seal.fill")
                            } else {
                                Label(localization.localized(.customTemplates), systemImage: "square.and.pencil")
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Favorite button
                    Button(action: { manager.toggleFavorite(templateId: template.id) }) {
                        Image(systemName: manager.isFavorite(templateId: template.id) ? "star.fill" : "star")
                            .foregroundColor(manager.isFavorite(templateId: template.id) ? .yellow : .secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }

                // Description
                Text(template.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))

                // Tags
                if !template.tags.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        ForEach(template.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundColor(.cyan.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.cyan.opacity(0.1)))
                        }
                    }
                }

                // Content preview
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(localization.localized(.templateContent))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                    Text(template.content)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                }

                // Variables
                if !template.variables.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "curlybraces")
                            Text(localization.localized(.templateVariables))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                        ForEach(template.variables, id: \.key) { variable in
                            HStack(spacing: 8) {
                                Text("{{\(variable.key)}}")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.cyan)
                                Text(variable.displayName)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                if !variable.defaultValue.isEmpty {
                                    Text("= \(variable.defaultValue)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.03)))
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 10) {
                    // Use template
                    Button(action: { useTemplate(template) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "paperplane.fill")
                            Text(localization.localized(.useTemplate))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.cyan))
                    }
                    .buttonStyle(.plain)

                    // Edit (custom only)
                    if !template.isBuiltIn {
                        Button(action: { editingTemplate = template }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text(localization.localized(.editTemplate))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.cyan.opacity(0.1))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            templateToDelete = template
                            showDeleteConfirm = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text(localization.localized(.deleteTemplate))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if showToast {
            Text(toastMessage)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(6)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) { showToast = false }
        }
    }

    // MARK: - Helpers

    private var filteredTemplates: [PromptTemplate] {
        var templates = selectedCategory != nil
            ? manager.templates(for: selectedCategory!)
            : manager.allTemplates()

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            templates = templates.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }
        return templates
    }

    private func localizedCategoryName(_ category: TemplateCategory) -> String {
        switch category {
        case .bugFix: return localization.localized(.templateCategoryBugFix)
        case .feature: return localization.localized(.templateCategoryFeature)
        case .refactor: return localization.localized(.templateCategoryRefactor)
        case .review: return localization.localized(.templateCategoryReview)
        case .custom: return localization.localized(.templateCategoryCustom)
        }
    }

    private func useTemplate(_ template: PromptTemplate) {
        manager.recordUsage(templateId: template.id)

        if template.variables.isEmpty {
            // No variables — directly set prompt text
            appState.submitPromptWithNewTeam(title: template.content)
            appState.isTemplateGalleryVisible = false
        } else {
            // Has variables — show variable input popover
            variableValues = [:]
            for v in template.variables {
                variableValues[v.key] = v.defaultValue
            }
            showVariableInput = true
        }
    }
}
