import Foundation

class ConfigurationLoader {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Load from bundle

    func loadAgentsFromBundle() -> [Agent] {
        guard let url = Bundle.main.url(forResource: "agents", withExtension: "json", subdirectory: "SampleConfigs") else {
            print("[ConfigLoader] agents.json not found in bundle")
            return []
        }
        return (try? loadAgents(from: url)) ?? []
    }

    func loadTasksFromBundle() -> [AgentTask] {
        guard let url = Bundle.main.url(forResource: "tasks", withExtension: "json", subdirectory: "SampleConfigs") else {
            print("[ConfigLoader] tasks.json not found in bundle")
            return []
        }
        return (try? loadTasks(from: url)) ?? []
    }

    func loadSceneConfigFromBundle() -> SceneConfiguration? {
        guard let url = Bundle.main.url(forResource: "scene_layout", withExtension: "json", subdirectory: "SampleConfigs") else {
            print("[ConfigLoader] scene_layout.json not found in bundle")
            return nil
        }
        return try? loadSceneConfig(from: url)
    }

    // MARK: - Load from URL

    func loadAgents(from url: URL) throws -> [Agent] {
        let data = try Data(contentsOf: url)
        let wrapper = try decoder.decode(AgentsWrapper.self, from: data)
        return wrapper.agents
    }

    func loadTasks(from url: URL) throws -> [AgentTask] {
        let data = try Data(contentsOf: url)
        let wrapper = try decoder.decode(TasksWrapper.self, from: data)
        return wrapper.tasks
    }

    func loadSceneConfig(from url: URL) throws -> SceneConfiguration {
        let data = try Data(contentsOf: url)
        return try decoder.decode(SceneConfiguration.self, from: data)
    }

    // MARK: - Load from directory (convenience)

    func loadAll(from directory: URL) throws -> (agents: [Agent], tasks: [AgentTask], sceneConfig: SceneConfiguration) {
        let agents = try loadAgents(from: directory.appendingPathComponent("agents.json"))
        let tasks = try loadTasks(from: directory.appendingPathComponent("tasks.json"))
        let sceneConfig = try loadSceneConfig(from: directory.appendingPathComponent("scene_layout.json"))
        return (agents, tasks, sceneConfig)
    }
}

// MARK: - JSON Wrappers

private struct AgentsWrapper: Codable {
    let agents: [Agent]
}

private struct TasksWrapper: Codable {
    let tasks: [AgentTask]
}
