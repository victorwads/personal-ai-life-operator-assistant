import Foundation

@MainActor
final class DeveloperModeSettingsRepository {
    private let defaults: UserDefaults
    private let storageKey = "developerModeEnabled.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Bool {
        defaults.bool(forKey: storageKey)
    }

    func save(_ enabled: Bool) {
        defaults.set(enabled, forKey: storageKey)
    }
}

