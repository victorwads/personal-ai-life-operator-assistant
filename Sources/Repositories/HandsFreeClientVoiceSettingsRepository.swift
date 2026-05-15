import Foundation

@MainActor
final class HandsFreeClientVoiceSettingsRepository {
    static let shared = HandsFreeClientVoiceSettingsRepository()
    static let defaultDebounceSeconds = 2.5

    private let defaults: UserDefaults
    private let enabledStorageKey = "handsFreeClientVoiceEnabled"
    private let debounceSecondsStorageKey = "handsFreeClientVoiceDebounceSeconds"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(defaultValue: Bool = true) -> Bool {
        if defaults.object(forKey: enabledStorageKey) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: enabledStorageKey)
    }

    func save(_ enabled: Bool) {
        defaults.set(enabled, forKey: enabledStorageKey)
    }

    func loadDebounceSeconds(defaultValue: Double = 2.5) -> Double {
        guard let number = defaults.object(forKey: debounceSecondsStorageKey) as? NSNumber else {
            return defaultValue
        }

        return Self.clampDebounceSeconds(number.doubleValue)
    }

    func save(debounceSeconds: Double) {
        defaults.set(NSNumber(value: Self.clampDebounceSeconds(debounceSeconds)), forKey: debounceSecondsStorageKey)
    }

    private static func clampDebounceSeconds(_ value: Double) -> Double {
        max(0.5, min(value, 5.0))
    }
}
