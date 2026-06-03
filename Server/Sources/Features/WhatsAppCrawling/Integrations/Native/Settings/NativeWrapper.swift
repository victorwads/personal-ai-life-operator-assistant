import Foundation

@MainActor
final class WhatsAppNativeSettingsWrapper {
    private static let scopeName = "whatsappNative"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let enabled = "enabled"
    }

    var enabled: Bool {
        get {
            (settings.value(scope: Self.scopeName, key: Key.enabled) ?? "") == "true"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.enabled, value: newValue ? "true" : "false")
        }
    }
}
