import Foundation

@MainActor
final class ExperimentalSpeakSettingsRepository {
    static let shared = ExperimentalSpeakSettingsRepository()

    private let defaults: UserDefaults
    private let storageKey = "experimentalSpeakApiEnabled"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(defaultValue: Bool = true) -> Bool {
        guard let number = defaults.object(forKey: storageKey) as? NSNumber else {
            return defaultValue
        }
        return number.boolValue
    }

    func save(_ enabled: Bool) {
        defaults.set(enabled, forKey: storageKey)
    }
}
