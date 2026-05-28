import Foundation

@MainActor
final class AIConnectionSettingsWrapper {
    private static let scopeName = "aiConnection"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let baseURL = "baseURL"
    }

    var baseURL: String {
        get {
            let value = settings.value(scope: Self.scopeName, key: Key.baseURL) ?? ""
            return value.isEmpty ? "http://localhost:1234" : value
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.baseURL, value: newValue)
        }
    }
}
