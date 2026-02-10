import Foundation

@MainActor
class LocalizationManager: ObservableObject {
    @Published var currentLanguage: AppLanguage

    private static let languageKey = "appLanguage"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.languageKey),
           let lang = AppLanguage(rawValue: saved) {
            currentLanguage = lang
        } else {
            currentLanguage = .zhTW
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
    }

    func localized(_ key: L10nKey) -> String {
        L10n.string(for: key, language: currentLanguage)
    }
}
