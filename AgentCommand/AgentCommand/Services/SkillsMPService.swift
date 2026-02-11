import Foundation

/// Service for searching skills from the SkillsMP marketplace (https://skillsmp.com)
@MainActor
class SkillsMPService: ObservableObject {
    @Published var searchResults: [SkillsMPSkill] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalResults = 0

    private let baseURL = "https://skillsmp.com/api/v1/skills"
    private static let apiKeyStorageKey = "skillsmp_api_key"

    // MARK: - API Key Management

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: Self.apiKeyStorageKey) }
        set {
            if let key = newValue, !key.isEmpty {
                UserDefaults.standard.set(key, forKey: Self.apiKeyStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.apiKeyStorageKey)
            }
            objectWillChange.send()
        }
    }

    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - Search

    func search(query: String, page: Int = 1, limit: Int = 20, sortBy: String = "stars") async {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            errorMessage = "API Key not configured"
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?q=\(encoded)&page=\(page)&limit=\(limit)&sort_by=\(sortBy)") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        await performRequest(url: url, apiKey: apiKey)
    }

    // MARK: - AI Search

    func aiSearch(query: String) async {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            errorMessage = "API Key not configured"
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/ai-search?q=\(encoded)") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        await performRequest(url: url, apiKey: apiKey, timeout: 30)
    }

    // MARK: - Clear

    func clearResults() {
        searchResults = []
        totalResults = 0
        errorMessage = nil
    }

    // MARK: - Private

    private func performRequest(url: URL, apiKey: String, timeout: TimeInterval = 15) async {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isLoading = false
                return
            }

            switch httpResponse.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(SkillsMPSearchResponse.self, from: data)
                searchResults = decoded.skills
                totalResults = decoded.total ?? decoded.skills.count
            case 401:
                errorMessage = "Invalid API Key"
            case 429:
                errorMessage = "Rate limited. Please try again later."
            default:
                errorMessage = "Server error (\(httpResponse.statusCode))"
            }
        } catch is DecodingError {
            errorMessage = "Failed to parse response"
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
