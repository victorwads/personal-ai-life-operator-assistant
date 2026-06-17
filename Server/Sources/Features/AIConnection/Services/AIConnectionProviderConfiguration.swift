import Foundation

struct AIConnectionProviderConfiguration: Equatable, Sendable {
    let providerKind: AIConnectionProviderKind
    let baseURL: String
    let apiKey: String
    let model: String
    let temperature: Double
    let reasoningEffort: AIConnectionReasoningEffort
    let maxOutputTokens: Int?
    let streamingEnabled: Bool
    let cacheMode: AIConnectionCacheMode
    let runtimeSettings: AIRuntimeGenerationSettings?

    init(
        providerKind: AIConnectionProviderKind,
        baseURL: String,
        apiKey: String,
        model: String,
        temperature: Double,
        reasoningEffort: AIConnectionReasoningEffort,
        maxOutputTokens: Int?,
        streamingEnabled: Bool,
        cacheMode: AIConnectionCacheMode,
        runtimeSettings: AIRuntimeGenerationSettings? = nil
    ) {
        self.providerKind = providerKind
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.reasoningEffort = reasoningEffort
        self.maxOutputTokens = maxOutputTokens
        self.streamingEnabled = streamingEnabled
        self.cacheMode = cacheMode
        self.runtimeSettings = runtimeSettings
    }
}
