import Foundation

/// Manages agent skill installations, activation, and persistence.
/// Based on Claude Agent Skills architecture - skills are modular capabilities
/// that can be installed and activated per agent.
@MainActor
class SkillManager: ObservableObject {
    // agentName -> [skillId -> SkillInstallation]
    @Published var agentSkills: [String: [String: SkillInstallation]] = [:]
    // Custom skills created by the user
    @Published var customSkills: [AgentSkill] = []

    private let storageKey = "skillManager_v2"

    init() {
        load()
    }

    // MARK: - Skill Discovery & Catalog

    func allAvailableSkills() -> [AgentSkill] {
        PreBuiltSkillCatalog.allSkills + customSkills
    }

    func availableSkills(for category: SkillCategory) -> [AgentSkill] {
        allAvailableSkills().filter { $0.category == category }
    }

    func resolveSkill(byId id: String) -> AgentSkill? {
        PreBuiltSkillCatalog.skill(byId: id) ?? customSkills.first { $0.id == id }
    }

    // MARK: - Installation

    @discardableResult
    func installSkill(skillId: String, forAgent agentName: String) -> Bool {
        guard agentSkills[agentName]?[skillId] == nil else { return false }

        var skills = agentSkills[agentName] ?? [:]
        skills[skillId] = SkillInstallation(
            skillId: skillId,
            isActive: true,
            installedAt: Date(),
            lastUsedAt: nil,
            usageCount: 0
        )
        agentSkills[agentName] = skills
        save()
        return true
    }

    func uninstallSkill(skillId: String, forAgent agentName: String) {
        agentSkills[agentName]?.removeValue(forKey: skillId)
        save()
    }

    // MARK: - Activation / Deactivation

    func toggleActive(skillId: String, forAgent agentName: String) {
        guard agentSkills[agentName]?[skillId] != nil else { return }
        agentSkills[agentName]?[skillId]?.isActive.toggle()
        save()
    }

    func setActive(skillId: String, forAgent agentName: String, active: Bool) {
        agentSkills[agentName]?[skillId]?.isActive = active
        save()
    }

    // MARK: - Usage Tracking

    func recordUsage(skillId: String, forAgent agentName: String) {
        agentSkills[agentName]?[skillId]?.usageCount += 1
        agentSkills[agentName]?[skillId]?.lastUsedAt = Date()
        save()
    }

    // MARK: - Query

    func installations(forAgent agentName: String) -> [String: SkillInstallation] {
        agentSkills[agentName] ?? [:]
    }

    func installation(forAgent agentName: String, skillId: String) -> SkillInstallation? {
        agentSkills[agentName]?[skillId]
    }

    func isInstalled(skillId: String, forAgent agentName: String) -> Bool {
        agentSkills[agentName]?[skillId] != nil
    }

    func isActive(skillId: String, forAgent agentName: String) -> Bool {
        agentSkills[agentName]?[skillId]?.isActive ?? false
    }

    func installedCount(forAgent agentName: String, category: SkillCategory) -> Int {
        let categorySkillIds = Set(allAvailableSkills().filter { $0.category == category }.map { $0.id })
        return installations(forAgent: agentName).values
            .filter { categorySkillIds.contains($0.skillId) }
            .count
    }

    func activeCount(forAgent agentName: String) -> Int {
        installations(forAgent: agentName).values.filter { $0.isActive }.count
    }

    func totalInstalledCount(forAgent agentName: String) -> Int {
        installations(forAgent: agentName).count
    }

    // MARK: - Custom Skills CRUD

    @discardableResult
    func addCustomSkill(_ skill: AgentSkill) -> Bool {
        guard !customSkills.contains(where: { $0.id == skill.id }) else { return false }
        customSkills.append(skill)
        save()
        return true
    }

    func updateCustomSkill(_ updated: AgentSkill) {
        guard let idx = customSkills.firstIndex(where: { $0.id == updated.id }) else { return }
        customSkills[idx] = updated
        save()
    }

    func removeCustomSkill(id: String) {
        customSkills.removeAll { $0.id == id }
        for agentName in agentSkills.keys {
            agentSkills[agentName]?.removeValue(forKey: id)
        }
        save()
    }

    func isCustomSkill(id: String) -> Bool {
        customSkills.contains { $0.id == id }
    }

    // MARK: - Persistence

    private func save() {
        let data = SkillManagerData(agentSkills: agentSkills, customSkills: customSkills)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SkillManagerData.self, from: data) else { return }
        agentSkills = decoded.agentSkills
        customSkills = decoded.customSkills
    }
}

private struct SkillManagerData: Codable {
    let agentSkills: [String: [String: SkillInstallation]]
    let customSkills: [AgentSkill]
}
