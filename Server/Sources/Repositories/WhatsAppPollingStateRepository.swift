import Foundation

final class WhatsAppPollingStateRepository {
    private enum Keys {
        static let pollingEnabled = "whatsApp.polling.enabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// When unset, default to enabled so the app starts polling on first launch.
    func loadPollingEnabled(defaultValue: Bool = true) -> Bool {
        if defaults.object(forKey: Keys.pollingEnabled) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: Keys.pollingEnabled)
    }

    func savePollingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.pollingEnabled)
    }
}

