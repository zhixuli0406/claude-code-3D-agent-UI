import Foundation

/// Manages prompt templates: built-in catalog, custom templates, favorites, and recent usage.
/// Persists custom templates and user preferences via UserDefaults.
@MainActor
class PromptTemplateManager: ObservableObject {
    @Published var customTemplates: [PromptTemplate] = []
    @Published var favoriteTemplateIds: Set<String> = []
    @Published var recentTemplateIds: [String] = []

    private let storageKey = "promptTemplateManager_v1"
    private let maxRecentCount = 5

    init() {
        load()
    }

    // MARK: - All Templates

    func allTemplates() -> [PromptTemplate] {
        PreBuiltTemplateCatalog.allTemplates + customTemplates
    }

    func templates(for category: TemplateCategory) -> [PromptTemplate] {
        allTemplates().filter { $0.category == category }
    }

    func template(byId id: String) -> PromptTemplate? {
        PreBuiltTemplateCatalog.template(byId: id) ?? customTemplates.first { $0.id == id }
    }

    func favoriteTemplates() -> [PromptTemplate] {
        allTemplates().filter { favoriteTemplateIds.contains($0.id) }
    }

    func recentTemplates() -> [PromptTemplate] {
        recentTemplateIds.compactMap { id in template(byId: id) }
    }

    func templateCount(for category: TemplateCategory) -> Int {
        allTemplates().filter { $0.category == category }.count
    }

    // MARK: - Favorites

    func toggleFavorite(templateId: String) {
        if favoriteTemplateIds.contains(templateId) {
            favoriteTemplateIds.remove(templateId)
        } else {
            favoriteTemplateIds.insert(templateId)
        }
        save()
    }

    func isFavorite(templateId: String) -> Bool {
        favoriteTemplateIds.contains(templateId)
    }

    // MARK: - Recent Usage

    func recordUsage(templateId: String) {
        recentTemplateIds.removeAll { $0 == templateId }
        recentTemplateIds.insert(templateId, at: 0)
        if recentTemplateIds.count > maxRecentCount {
            recentTemplateIds = Array(recentTemplateIds.prefix(maxRecentCount))
        }
        save()
    }

    // MARK: - Custom Template CRUD

    @discardableResult
    func addCustomTemplate(_ template: PromptTemplate) -> Bool {
        guard !customTemplates.contains(where: { $0.id == template.id }) else { return false }
        customTemplates.append(template)
        save()
        return true
    }

    func updateCustomTemplate(_ updated: PromptTemplate) {
        guard let idx = customTemplates.firstIndex(where: { $0.id == updated.id }) else { return }
        customTemplates[idx] = updated
        save()
    }

    func removeCustomTemplate(id: String) {
        customTemplates.removeAll { $0.id == id }
        favoriteTemplateIds.remove(id)
        recentTemplateIds.removeAll { $0 == id }
        save()
    }

    func isCustomTemplate(id: String) -> Bool {
        customTemplates.contains { $0.id == id }
    }

    // MARK: - Render

    func renderTemplate(_ template: PromptTemplate, with values: [String: String]) -> String {
        template.render(with: values)
    }

    // MARK: - Persistence

    private func save() {
        let data = PromptTemplateManagerData(
            customTemplates: customTemplates,
            favoriteTemplateIds: Array(favoriteTemplateIds),
            recentTemplateIds: recentTemplateIds
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(PromptTemplateManagerData.self, from: data) else { return }
        customTemplates = decoded.customTemplates
        favoriteTemplateIds = Set(decoded.favoriteTemplateIds)
        recentTemplateIds = decoded.recentTemplateIds
    }
}

private struct PromptTemplateManagerData: Codable {
    let customTemplates: [PromptTemplate]
    let favoriteTemplateIds: [String]
    let recentTemplateIds: [String]
}
