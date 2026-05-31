import Foundation

struct AIProviderRequest: Equatable, Sendable {
    let model: String
    let messages: [AIConversationMessage]
    let tools: [AIToolDefinition]
    let temperature: Double
    let maxOutputTokens: Int?
    let cacheMode: AIConnectionCacheMode

    init(
        model: String,
        messages: [AIConversationMessage],
        tools: [AIToolDefinition] = [],
        temperature: Double = 0.7,
        maxOutputTokens: Int? = nil,
        cacheMode: AIConnectionCacheMode = .automatic
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.cacheMode = cacheMode
    }
}
