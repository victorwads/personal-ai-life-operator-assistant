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
        static let assistantProviderKind = "providerKind"
        static let assistantBaseURL = "baseURL"
        static let assistantAPIKey = "apiKey"
        static let assistantModel = "model"
        static let assistantReasoningEffort = "assistantReasoningEffort"
        static let imageExtractionProviderKind = "imageExtractionProviderKind"
        static let imageExtractionBaseURL = "imageExtractionBaseURL"
        static let imageExtractionAPIKey = "imageExtractionAPIKey"
        static let imageExtractionModel = "imageExtractionModel"
        static let imageExtractionReasoningEffort = "imageExtractionReasoningEffort"
        static let temperature = "temperature"
        static let reasoningEffort = "reasoningEffort"
        static let maxOutputTokens = "maxOutputTokens"
        static let streamingEnabled = "streamingEnabled"
        static let cacheMode = "cacheMode"
        static let imageExtractionCacheMode = "imageExtractionCacheMode"
    }

    enum ProviderTarget {
        case assistant
        case imageExtraction

        var providerKindKey: String {
            switch self {
            case .assistant:
                Key.assistantProviderKind
            case .imageExtraction:
                Key.imageExtractionProviderKind
            }
        }

        var baseURLKey: String {
            switch self {
            case .assistant:
                Key.assistantBaseURL
            case .imageExtraction:
                Key.imageExtractionBaseURL
            }
        }

        var apiKeyKey: String {
            switch self {
            case .assistant:
                Key.assistantAPIKey
            case .imageExtraction:
                Key.imageExtractionAPIKey
            }
        }

        var modelKey: String {
            switch self {
            case .assistant:
                Key.assistantModel
            case .imageExtraction:
                Key.imageExtractionModel
            }
        }
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
            providerKind(for: .assistant)
        }
        set {
            setProviderKind(newValue, for: .assistant)
        }
    }

    var baseURL: String {
        get {
            baseURL(for: .assistant)
        }
        set {
            setBaseURL(newValue, for: .assistant)
        }
    }

    var apiKey: String {
        get {
            apiKey(for: .assistant)
        }
        set {
            setAPIKey(newValue, for: .assistant)
        }
    }

    var model: String {
        get {
            model(for: .assistant)
        }
        set {
            setModel(newValue, for: .assistant)
        }
    }

    var imageExtractionProviderKind: AIConnectionProviderKind {
        get {
            providerKind(for: .imageExtraction)
        }
        set {
            setProviderKind(newValue, for: .imageExtraction)
        }
    }

    var imageExtractionBaseURL: String {
        get {
            baseURL(for: .imageExtraction)
        }
        set {
            setBaseURL(newValue, for: .imageExtraction)
        }
    }

    var imageExtractionAPIKey: String {
        get {
            apiKey(for: .imageExtraction)
        }
        set {
            setAPIKey(newValue, for: .imageExtraction)
        }
    }

    var imageExtractionModel: String {
        get {
            model(for: .imageExtraction)
        }
        set {
            setModel(newValue, for: .imageExtraction)
        }
    }

    var temperature: Double {
        get {
            let rawValue = settings.value(scope: Self.scopeName, key: Key.temperature) ?? ""
            guard let value = Double(rawValue) else {
                return 0.8
            }

            return value
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.temperature, value: Self.format(newValue))
        }
    }

    var reasoningEffort: AIConnectionReasoningEffort {
        get {
            assistantReasoningEffort
        }
        set {
            assistantReasoningEffort = newValue
        }
    }

    var assistantReasoningEffort: AIConnectionReasoningEffort {
        get {
            reasoningEffort(
                primaryKey: Key.assistantReasoningEffort,
                fallbackKey: Key.reasoningEffort,
                default: .omit
            )
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.assistantReasoningEffort, value: newValue.rawValue)
        }
    }

    var imageExtractionReasoningEffort: AIConnectionReasoningEffort {
        get {
            reasoningEffort(
                primaryKey: Key.imageExtractionReasoningEffort,
                fallbackKey: nil,
                default: .omit
            )
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.imageExtractionReasoningEffort, value: newValue.rawValue)
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
            cacheMode(for: Key.cacheMode, fallbackKey: nil)
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.cacheMode, value: newValue.rawValue)
        }
    }

    var imageExtractionCacheMode: AIConnectionCacheMode {
        get {
            cacheMode(for: Key.imageExtractionCacheMode, fallbackKey: Key.cacheMode)
        }
        set {
            settings.setValue(scope: Self.scopeName, key: Key.imageExtractionCacheMode, value: newValue.rawValue)
        }
    }

    var providerConfiguration: AIConnectionProviderConfiguration {
        assistantProviderConfiguration
    }

    var assistantProviderConfiguration: AIConnectionProviderConfiguration {
        let runtime = loadRuntimeSettings(for: .assistant)
        return AIConnectionProviderConfiguration(
            providerKind: providerKind,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            temperature: runtime.temperature,
            reasoningEffort: assistantReasoningEffort,
            maxOutputTokens: maxOutputTokens,
            streamingEnabled: streamingEnabled,
            cacheMode: cacheMode,
            runtimeSettings: runtime
        )
    }

    var imageExtractionProviderConfiguration: AIConnectionProviderConfiguration {
        let runtime = loadRuntimeSettings(for: .imageExtraction)
        return AIConnectionProviderConfiguration(
            providerKind: imageExtractionProviderKind,
            baseURL: imageExtractionBaseURL,
            apiKey: imageExtractionAPIKey,
            model: imageExtractionModel,
            temperature: runtime.temperature,
            reasoningEffort: imageExtractionReasoningEffort,
            maxOutputTokens: runtime.maxTokens,
            streamingEnabled: true,
            cacheMode: imageExtractionCacheMode,
            runtimeSettings: runtime
        )
    }

    private func reasoningEffort(
        primaryKey: String,
        fallbackKey: String?,
        default defaultValue: AIConnectionReasoningEffort
    ) -> AIConnectionReasoningEffort {
        if let rawValue = settings.value(scope: Self.scopeName, key: primaryKey),
           let reasoningEffort = AIConnectionReasoningEffort(rawValue: rawValue) {
            return reasoningEffort
        }

        if let fallbackKey,
           let rawValue = settings.value(scope: Self.scopeName, key: fallbackKey),
           let reasoningEffort = AIConnectionReasoningEffort(rawValue: rawValue) {
            return reasoningEffort
        }

        return defaultValue
    }

    private func providerKind(for target: ProviderTarget) -> AIConnectionProviderKind {
        if let rawValue = settings.value(scope: Self.scopeName, key: target.providerKindKey),
           let providerKind = AIConnectionProviderKind(rawValue: rawValue) {
            return providerKind
        }

        if case .imageExtraction = target {
            return providerKind(for: .assistant)
        }

        return .openRouter
    }

    private func setProviderKind(_ newValue: AIConnectionProviderKind, for target: ProviderTarget) {
        let previousKind = providerKind(for: target)
        let existingBaseURL = settings.value(scope: Self.scopeName, key: target.baseURLKey) ?? ""

        settings.setValue(scope: Self.scopeName, key: target.providerKindKey, value: newValue.rawValue)

        let trimmedBaseURL = existingBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldReplaceBaseURL = trimmedBaseURL.isEmpty || trimmedBaseURL == previousKind.defaultBaseURL
        if shouldReplaceBaseURL {
            settings.setValue(scope: Self.scopeName, key: target.baseURLKey, value: newValue.defaultBaseURL)
        }
    }

    private func baseURL(for target: ProviderTarget) -> String {
        let value = stringValue(for: target, key: target.baseURLKey)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? providerKind(for: target).defaultBaseURL : trimmedValue
    }

    private func setBaseURL(_ value: String, for target: ProviderTarget) {
        settings.setValue(
            scope: Self.scopeName,
            key: target.baseURLKey,
            value: value.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func apiKey(for target: ProviderTarget) -> String {
        stringValue(for: target, key: target.apiKeyKey)
    }

    private func setAPIKey(_ value: String, for target: ProviderTarget) {
        // TODO: Move API keys/secrets to Keychain before this feature is used outside local development.
        // SettingsStore is profile-scoped app configuration, not a secure secret store.
        settings.setValue(scope: Self.scopeName, key: target.apiKeyKey, value: value)
    }

    private func model(for target: ProviderTarget) -> String {
        stringValue(for: target, key: target.modelKey).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setModel(_ value: String, for target: ProviderTarget) {
        settings.setValue(
            scope: Self.scopeName,
            key: target.modelKey,
            value: value.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func stringValue(for target: ProviderTarget, key: String) -> String {
        if let value = settings.value(scope: Self.scopeName, key: key) {
            return value
        }

        switch target {
        case .assistant:
            return ""
        case .imageExtraction:
            break
        }

        switch key {
        case ProviderTarget.imageExtraction.baseURLKey:
            return settings.value(scope: Self.scopeName, key: ProviderTarget.assistant.baseURLKey) ?? ""
        case ProviderTarget.imageExtraction.apiKeyKey:
            return settings.value(scope: Self.scopeName, key: ProviderTarget.assistant.apiKeyKey) ?? ""
        case ProviderTarget.imageExtraction.modelKey:
            return settings.value(scope: Self.scopeName, key: ProviderTarget.assistant.modelKey) ?? ""
        default:
            return ""
        }
    }

    private func cacheMode(for key: String, fallbackKey: String?) -> AIConnectionCacheMode {
        if let rawValue = settings.value(scope: Self.scopeName, key: key),
           let cacheMode = AIConnectionCacheMode(rawValue: rawValue) {
            return cacheMode
        }

        if let fallbackKey,
           let rawValue = settings.value(scope: Self.scopeName, key: fallbackKey),
           let cacheMode = AIConnectionCacheMode(rawValue: rawValue) {
            return cacheMode
        }

        return .automatic
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

    func loadProviderSettings(for target: ProviderTarget) -> AIProviderSettings {
        AIProviderSettings(
            providerKind: providerKind(for: target),
            baseURL: baseURL(for: target),
            apiKey: apiKey(for: target),
            model: model(for: target),
            reasoningEffort: {
                switch target {
                case .assistant: return assistantReasoningEffort
                case .imageExtraction: return imageExtractionReasoningEffort
                }
            }(),
            cacheMode: {
                switch target {
                case .assistant: return cacheMode
                case .imageExtraction: return imageExtractionCacheMode
                }
            }()
        )
    }

    func saveProviderSettings(_ settings: AIProviderSettings, for target: ProviderTarget) {
        setProviderKind(settings.providerKind, for: target)
        setBaseURL(settings.baseURL, for: target)
        setAPIKey(settings.apiKey, for: target)
        setModel(settings.model, for: target)
        switch target {
        case .assistant:
            assistantReasoningEffort = settings.reasoningEffort
            cacheMode = settings.cacheMode
        case .imageExtraction:
            imageExtractionReasoningEffort = settings.reasoningEffort
            imageExtractionCacheMode = settings.cacheMode
        }
    }

    func loadRuntimeSettings(for target: ProviderTarget) -> AIRuntimeGenerationSettings {
        let prefix = target == .assistant ? "assistant_runtime_" : "imageExtraction_runtime_"
        let defaults = AIRuntimeGenerationSettings.defaultSettings
        let fallbackTemp = (target == .assistant) ? temperature : 0.8
        let fallbackMaxTokens = (target == .assistant) ? (maxOutputTokens ?? 4096) : 4096

        return AIRuntimeGenerationSettings(
            temperature: doubleValue(for: prefix + "temperature", default: fallbackTemp),
            topP: doubleValue(for: prefix + "topP", default: defaults.topP),
            topK: intValue(for: prefix + "topK", default: defaults.topK),
            maxTokens: intValue(for: prefix + "maxTokens", default: fallbackMaxTokens),
            maxContextTokens: intValue(for: prefix + "maxContextTokens", default: defaults.maxContextTokens),
            streamOutputEnabled: boolValue(for: prefix + "streamOutputEnabled", default: defaults.streamOutputEnabled),
            showPerformanceMetrics: boolValue(for: prefix + "showPerformanceMetrics", default: defaults.showPerformanceMetrics),
            kvCacheEnabled: boolValue(for: prefix + "kvCacheEnabled", default: defaults.kvCacheEnabled),
            kvCacheQuantizationEnabled: boolValue(for: prefix + "kvCacheQuantizationEnabled", default: defaults.kvCacheQuantizationEnabled),
            kvBits: intValue(for: prefix + "kvBits", default: defaults.kvBits),
            kvGroupSize: intValue(for: prefix + "kvGroupSize", default: defaults.kvGroupSize),
            quantizedKVStart: intValue(for: prefix + "quantizedKVStart", default: defaults.quantizedKVStart),
            reasoningEnabled: boolValue(for: prefix + "reasoningEnabled", default: defaults.reasoningEnabled),
            reasoningTokensLimit: intValue(for: prefix + "reasoningTokensLimit", default: defaults.reasoningTokensLimit),
            selectedPreset: {
                if let rawPreset = settings.value(scope: Self.scopeName, key: prefix + "selectedPreset"),
                   let preset = AIRuntimePreset(rawValue: rawPreset) {
                    return preset
                }
                return defaults.selectedPreset
            }()
        )
    }

    func saveRuntimeSettings(_ settings: AIRuntimeGenerationSettings, for target: ProviderTarget) {
        let prefix = target == .assistant ? "assistant_runtime_" : "imageExtraction_runtime_"

        setDouble(settings.temperature, for: prefix + "temperature")
        setDouble(settings.topP, for: prefix + "topP")
        setInt(settings.topK, for: prefix + "topK")
        setInt(settings.maxTokens, for: prefix + "maxTokens")
        setInt(settings.maxContextTokens, for: prefix + "maxContextTokens")
        setBool(settings.streamOutputEnabled, for: prefix + "streamOutputEnabled")
        setBool(settings.showPerformanceMetrics, for: prefix + "showPerformanceMetrics")
        setBool(settings.kvCacheEnabled, for: prefix + "kvCacheEnabled")
        setBool(settings.kvCacheQuantizationEnabled, for: prefix + "kvCacheQuantizationEnabled")
        setInt(settings.kvBits, for: prefix + "kvBits")
        setInt(settings.kvGroupSize, for: prefix + "kvGroupSize")
        setInt(settings.quantizedKVStart, for: prefix + "quantizedKVStart")
        setBool(settings.reasoningEnabled, for: prefix + "reasoningEnabled")
        setInt(settings.reasoningTokensLimit, for: prefix + "reasoningTokensLimit")
        self.settings.setValue(scope: Self.scopeName, key: prefix + "selectedPreset", value: settings.selectedPreset.rawValue)

        if target == .assistant {
            temperature = settings.temperature
            maxOutputTokens = settings.maxTokens
        }
    }

    private func intValue(for key: String, default defaultValue: Int) -> Int {
        guard let rawValue = settings.value(scope: Self.scopeName, key: key), let value = Int(rawValue) else {
            return defaultValue
        }
        return value
    }

    private func setInt(_ value: Int, for key: String) {
        settings.setValue(scope: Self.scopeName, key: key, value: String(value))
    }

    private func doubleValue(for key: String, default defaultValue: Double) -> Double {
        guard let rawValue = settings.value(scope: Self.scopeName, key: key), let value = Double(rawValue) else {
            return defaultValue
        }
        return value
    }

    private func setDouble(_ value: Double, for key: String) {
        settings.setValue(scope: Self.scopeName, key: key, value: Self.format(value))
    }
}
