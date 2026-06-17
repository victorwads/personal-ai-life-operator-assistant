import Foundation

struct AIProviderRequest: Equatable, Sendable {
    let model: String
    let messages: [AIConversationMessage]
    let tools: [AIToolDefinition]
    let temperature: Double
    let reasoningEffort: AIConnectionReasoningEffort
    let maxOutputTokens: Int?
    let cacheMode: AIConnectionCacheMode
    let loadAvailableTools: Bool

    init(
        model: String,
        messages: [AIConversationMessage],
        tools: [AIToolDefinition] = [],
        temperature: Double = 0.8,
        reasoningEffort: AIConnectionReasoningEffort = .omit,
        maxOutputTokens: Int? = nil,
        cacheMode: AIConnectionCacheMode = .automatic,
        loadAvailableTools: Bool = true
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.temperature = temperature
        self.reasoningEffort = reasoningEffort
        self.maxOutputTokens = maxOutputTokens
        self.cacheMode = cacheMode
        self.loadAvailableTools = loadAvailableTools
    }
}
