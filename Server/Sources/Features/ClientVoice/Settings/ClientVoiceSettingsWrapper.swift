import Foundation
import AVFoundation

@MainActor
final class ClientVoiceSettingsWrapper {
    static let scopeName = "clientVoice"
    static let speechOutputMethod = "speechOutputMethod"
    static let speechOutputVoiceIdentifier = "speechOutputVoiceIdentifier"
    static let speechOutputLanguage = "speechOutputLanguage"
    static let speechOutputRate = "speechOutputRate"

    private static let defaultSpeechRecognitionDebounceFinalMs = 1_200
    private static let defaultWhisperPostProcessingLanguage = WhisperLanguage.auto
    private static let defaultAskSendMode = ClientVoiceAskSendMode.handsFree
    private static let defaultSpeechOutputMethod = SpeakMethod.command
    private static let defaultSpeechOutputLanguage = "pt-BR"
    private static let defaultSpeechOutputRate = AVSpeechUtteranceDefaultSpeechRate

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private enum Key {
        static let workerAutoStart = "workerAutoStart"
        static let speechRecognitionLanguage = "speechRecognitionLanguage"
        static let speechRecognitionDebounceFinalMs = "speechRecognitionDebounceFinalMs"
        static let whisperPostProcessingEnabled = "whisperPostProcessingEnabled"
        static let whisperPostProcessingModelPath = "whisperPostProcessingModelPath"
        static let whisperPostProcessingCoreMLModelPath = "whisperPostProcessingCoreMLModelPath"
        static let whisperPostProcessingLanguage = "whisperPostProcessingLanguage"
        static let askSendMode = "askSendMode"
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
            debounceFinalMs: speechRecognitionDebounceFinalMs,
            postProcessing: WhisperPostProcessingConfig(
                isEnabled: whisperPostProcessingEnabled,
                modelPath: whisperPostProcessingModelPath,
                coreMLModelPath: whisperPostProcessingCoreMLModelPath,
                language: whisperPostProcessingLanguage.rawValue
            )
        )
    }

    var askSendMode: ClientVoiceAskSendMode {
        get {
            guard
                let rawValue = settings.value(scope: Self.scopeName, key: Key.askSendMode),
                let mode = ClientVoiceAskSendMode(rawValue: rawValue)
            else {
                return Self.defaultAskSendMode
            }

            return mode
        }
        set {
            settings.setValue(
                scope: Self.scopeName,
                key: Key.askSendMode,
                value: newValue.rawValue
            )
        }
    }

    var whisperPostProcessingEnabled: Bool {
        get {
            boolValue(for: Key.whisperPostProcessingEnabled, default: false)
        }
        set {
            setBool(newValue, for: Key.whisperPostProcessingEnabled)
        }
    }

    var whisperPostProcessingModelPath: String? {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Key.whisperPostProcessingModelPath)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return rawValue.isEmpty ? nil : rawValue
        }
        set {
            let trimmedValue = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedValue.isEmpty {
                settings.deleteValue(scope: Self.scopeName, key: Key.whisperPostProcessingModelPath)
            } else {
                settings.setValue(
                    scope: Self.scopeName,
                    key: Key.whisperPostProcessingModelPath,
                    value: trimmedValue
                )
            }
        }
    }

    var whisperPostProcessingLanguage: WhisperLanguage {
        get {
            guard
                let rawValue = settings.value(scope: Self.scopeName, key: Key.whisperPostProcessingLanguage),
                let language = WhisperLanguage(rawValue: rawValue)
            else {
                return Self.defaultWhisperPostProcessingLanguage
            }

            return language
        }
        set {
            settings.setValue(
                scope: Self.scopeName,
                key: Key.whisperPostProcessingLanguage,
                value: newValue.rawValue
            )
        }
    }

    var whisperPostProcessingCoreMLModelPath: String? {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Key.whisperPostProcessingCoreMLModelPath)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return rawValue.isEmpty ? nil : rawValue
        }
        set {
            let trimmedValue = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedValue.isEmpty {
                settings.deleteValue(scope: Self.scopeName, key: Key.whisperPostProcessingCoreMLModelPath)
            } else {
                settings.setValue(
                    scope: Self.scopeName,
                    key: Key.whisperPostProcessingCoreMLModelPath,
                    value: trimmedValue
                )
            }
        }
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

    var speechOutputMethod: SpeakMethod {
        get {
            guard
                let rawValue = settings.value(scope: Self.scopeName, key: Self.speechOutputMethod),
                let method = SpeakMethod(rawValue: rawValue)
            else {
                return Self.defaultSpeechOutputMethod
            }
            return method
        }
        set {
            settings.setValue(
                scope: Self.scopeName,
                key: Self.speechOutputMethod,
                value: newValue.rawValue
            )
        }
    }

    var speechOutputVoiceIdentifier: String? {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Self.speechOutputVoiceIdentifier)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return rawValue.isEmpty ? nil : rawValue
        }
        set {
            let trimmedValue = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedValue.isEmpty {
                settings.deleteValue(scope: Self.scopeName, key: Self.speechOutputVoiceIdentifier)
            } else {
                settings.setValue(
                    scope: Self.scopeName,
                    key: Self.speechOutputVoiceIdentifier,
                    value: trimmedValue
                )
            }
        }
    }

    var speechOutputLanguage: String {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Self.speechOutputLanguage)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return rawValue.isEmpty ? Self.defaultSpeechOutputLanguage : rawValue
        }
        set {
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.setValue(
                scope: Self.scopeName,
                key: Self.speechOutputLanguage,
                value: trimmedValue.isEmpty ? Self.defaultSpeechOutputLanguage : trimmedValue
            )
        }
    }

    var speechOutputRate: Float {
        get {
            let val = floatValue(for: Self.speechOutputRate, default: Self.defaultSpeechOutputRate)
            return max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, val))
        }
        set {
            let clamped = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, newValue))
            setFloat(clamped, for: Self.speechOutputRate)
        }
    }

    var speechSpeakConfig: SpeakConfig {
        switch speechOutputMethod {
        case .command:
            return SayCommandSpeakConfig(rate: speechOutputRate)
        case .swiftAPI:
            return SwiftAPISpeakConfig(
                voice: speechOutputVoiceIdentifier,
                language: speechOutputLanguage,
                rate: speechOutputRate
            )
        }
    }

    private func floatValue(for key: String, default defaultValue: Float) -> Float {
        guard
            let rawValue = settings.value(scope: Self.scopeName, key: key),
            let value = Float(rawValue)
        else {
            return defaultValue
        }
        return value
    }

    private func setFloat(_ value: Float, for key: String) {
        settings.setValue(scope: Self.scopeName, key: key, value: String(value))
    }
}
