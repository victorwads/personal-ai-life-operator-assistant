import Foundation

@MainActor
final class ClientVoiceSettingsWrapper {
    static let scopeName = "clientVoice"
    private static let defaultSpeechRecognitionDebounceFinalMs = 1_200

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let workerAutoStart = "workerAutoStart"
        static let speechRecognitionLanguage = "speechRecognitionLanguage"
        static let speechRecognitionDebounceFinalMs = "speechRecognitionDebounceFinalMs"
    }

    var workerAutoStart: Bool {
        get {
            boolValue(for: Key.workerAutoStart, default: false)
        }
        set {
            setBool(newValue, for: Key.workerAutoStart)
        }
    }

    var speechRecognitionLanguage: ClientVoiceSpeechRecognitionLanguage {
        get {
            guard
                let rawValue = settings.value(scope: Self.scopeName, key: Key.speechRecognitionLanguage),
                let language = ClientVoiceSpeechRecognitionLanguage(rawValue: rawValue)
            else {
                return .systemDefault
            }

            return language
        }
        set {
            settings.setValue(
                scope: Self.scopeName,
                key: Key.speechRecognitionLanguage,
                value: newValue.rawValue
            )
        }
    }

    var speechRecognitionDebounceFinalMs: Int {
        get {
            intValue(
                for: Key.speechRecognitionDebounceFinalMs,
                default: Self.defaultSpeechRecognitionDebounceFinalMs
            )
        }
        set {
            setInt(max(100, newValue), for: Key.speechRecognitionDebounceFinalMs)
        }
    }

    var speechRecognitionListenConfig: ListenConfig {
        ListenConfig(
            language: speechRecognitionLanguage.rawValue,
            debounceFinalMs: speechRecognitionDebounceFinalMs
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

    private func intValue(for key: String, default defaultValue: Int) -> Int {
        guard
            let rawValue = settings.value(scope: Self.scopeName, key: key),
            let value = Int(rawValue),
            value > 0
        else {
            return defaultValue
        }

        return value
    }

    private func setInt(_ value: Int, for key: String) {
        settings.setValue(scope: Self.scopeName, key: key, value: String(value))
    }
}
