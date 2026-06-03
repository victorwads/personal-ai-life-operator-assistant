import Foundation

struct AIConnectionRequestBuilder {
    func buildRequest(
        messages: [AIConversationMessage],
        availableToolDefinitions: [AIToolDefinition]
    ) -> AIProviderRequest {
        AIProviderRequest(
            model: "",
            messages: messages,
            tools: availableToolDefinitions,
            temperature: 0.7,
            maxOutputTokens: nil,
            cacheMode: .automatic
        )
    }
}
