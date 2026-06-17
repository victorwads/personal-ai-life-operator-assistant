import Foundation

public struct AIProviderSettings: Equatable, Codable, Sendable {
    public var providerKind: AIConnectionProviderKind
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var reasoningEffort: AIConnectionReasoningEffort
    public var cacheMode: AIConnectionCacheMode

    public init(
        providerKind: AIConnectionProviderKind,
        baseURL: String,
        apiKey: String,
        model: String,
        reasoningEffort: AIConnectionReasoningEffort,
        cacheMode: AIConnectionCacheMode
    ) {
        self.providerKind = providerKind
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.cacheMode = cacheMode
    }
}
