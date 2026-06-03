import Foundation

struct AIConnectionProviderConfiguration: Equatable, Sendable {
    let providerKind: AIConnectionProviderKind
    let baseURL: String
    let apiKey: String
    let model: String
    let temperature: Double
    let maxOutputTokens: Int?
    let streamingEnabled: Bool
    let cacheMode: AIConnectionCacheMode
}
