import Foundation

@MainActor
final class AIRuntimeSettingsWrapper {
    private static let scopeName = "aiRuntime"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let temperature = "temperature"
        static let topP = "topP"
        static let maxTokens = "maxTokens"
        static let reasoningEnabled = "reasoningEnabled"
    }

    var temperature: Float {
        get {
            if let value = settings.value(scope: Self.scopeName, key: Key.temperature),
               let floatVal = Float(value) {
                return floatVal
            }
            return 0.8
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.temperature, value: String(newValue))
        }
    }

    var topP: Float {
        get {
            if let value = settings.value(scope: Self.scopeName, key: Key.topP),
               let floatVal = Float(value) {
                return floatVal
            }
            return 0.95
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.topP, value: String(newValue))
        }
    }

    var maxTokens: Int {
        get {
            if let value = settings.value(scope: Self.scopeName, key: Key.maxTokens),
               let intVal = Int(value) {
                return intVal
            }
            return 4096
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.maxTokens, value: String(newValue))
        }
    }

    var reasoningEnabled: Bool {
        get {
            if let value = settings.value(scope: Self.scopeName, key: Key.reasoningEnabled) {
                return value == "true"
            }
            return false
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.reasoningEnabled, value: newValue ? "true" : "false")
        }
    }
}
