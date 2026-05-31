import Foundation

@MainActor
final class AIConnectionSettingsWrapper {
    private static let scopeName = "aiConnection"

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let autoStart = "autoStart"
        static let providerKind = "providerKind"
        static let baseURL = "baseURL"
        static let apiKey = "apiKey"
        static let model = "model"
        static let temperature = "temperature"
        static let maxOutputTokens = "maxOutputTokens"
        static let streamingEnabled = "streamingEnabled"
        static let cacheMode = "cacheMode"
    }

    var autoStart: Bool {
        get {
            boolValue(for: Key.autoStart, default: false)
        }
        set {
            setBool(newValue, for: Key.autoStart)
        }
    }

    var providerKind: AIConnectionProviderKind {
        get {
            guard
                let rawValue = settings.value(scope: Self.scopeName, key: Key.providerKind),
                let providerKind = AIConnectionProviderKind(rawValue: rawValue)
            else {
                return .openRouter
            }

            return providerKind
        }
        set {
            let previousKind = providerKind
            let existingBaseURL = settings.value(scope: Self.scopeName, key: Key.baseURL) ?? ""

            settings.setValue(scope: Self.scopeName, key: Key.providerKind, value: newValue.rawValue)

            let trimmedBaseURL = existingBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldReplaceBaseURL = trimmedBaseURL.isEmpty || trimmedBaseURL == previousKind.defaultBaseURL
            if shouldReplaceBaseURL {
                settings.setValue(scope: Self.scopeName, key: Key.baseURL, value: newValue.defaultBaseURL)
            }
        }
    }

    var baseURL: String {
        get {
            let value = settings.value(scope: Self.scopeName, key: Key.baseURL) ?? ""
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedValue.isEmpty ? providerKind.defaultBaseURL : trimmedValue
        }
        set {
            settings.setValue(
                scope: Self.scopeName,
                key: Key.baseURL,
                value: newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    var apiKey: String {
        get {
            settings.value(scope: Self.scopeName, key: Key.apiKey) ?? ""
        }
        set {
            // TODO: Move API keys/secrets to Keychain before this feature is used outside local development.
            // SettingsStore is profile-scoped app configuration, not a secure secret store.
            settings.setValue(scope: Self.scopeName, key: Key.apiKey, value: newValue)
        }
    }

    var model: String {
        get {
            settings.value(scope: Self.scopeName, key: Key.model) ?? ""
        }
        set {
            settings.setValue(
                scope: Self.scopeName,
                key: Key.model,
                value: newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    var temperature: Double {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Key.temperature) ?? ""
            guard let value = Double(rawValue) else {
                return 0.7
            }

            return value
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.temperature, value: Self.format(newValue))
        }
    }

    var maxOutputTokens: Int? {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Key.maxOutputTokens) ?? ""
            guard !rawValue.isEmpty, let value = Int(rawValue), value > 0 else {
                return nil
            }

            return value
        }
        set {
            if let newValue, newValue > 0 {
                settings.setValue(scope: Self.scopeName, key: Key.maxOutputTokens, value: String(newValue))
            } else {
                settings.deleteValue(scope: Self.scopeName, key: Key.maxOutputTokens)
            }
        }
    }

    var streamingEnabled: Bool {
        get {
            boolValue(for: Key.streamingEnabled, default: true)
        }
        set {
            setBool(newValue, for: Key.streamingEnabled)
        }
    }

    var cacheMode: AIConnectionCacheMode {
        get {
            guard
                let rawValue = settings.value(scope: Self.scopeName, key: Key.cacheMode),
                let cacheMode = AIConnectionCacheMode(rawValue: rawValue)
            else {
                return .automatic
            }

            return cacheMode
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.cacheMode, value: newValue.rawValue)
        }
    }

    var providerConfiguration: AIConnectionProviderConfiguration {
        AIConnectionProviderConfiguration(
            providerKind: providerKind,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            temperature: temperature,
            maxOutputTokens: maxOutputTokens,
            streamingEnabled: streamingEnabled,
            cacheMode: cacheMode
        )
    }

    private func boolValue(for key: String, default defaultValue: Bool) -> Bool {
        guard let rawValue = settings.value(scope: Self.scopeName, key: key) else {
            return defaultValue
        }

        return rawValue == "true"
    }

    private func setBool(_ value: Bool, for key: String) {
        settings.setValue(scope: Self.scopeName, key: key, value: value ? "true" : "false")
    }

    private static func format(_ value: Double) -> String {
        let roundedValue = (value * 100).rounded() / 100
        return String(roundedValue)
    }
}
