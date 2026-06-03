import Foundation

@MainActor
final class MCPServerSettingsWrapper {
    private static let scopeName = "mcpServer"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let autoStart = "autoStart"
    }

    var autoStart: Bool {
        get {
            (settings.value(scope: Self.scopeName, key: Key.autoStart) ?? "") == "true"
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.autoStart, value: newValue ? "true" : "false")
        }
    }
}
