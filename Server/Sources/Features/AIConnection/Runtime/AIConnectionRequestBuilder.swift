import Foundation

struct AIConnectionRequestBuilder {
    func buildRequest(
        messages: [AIConversationMessage],
        availableToolDefinitions: [AIToolDefinition],
        configuration: AIConnectionProviderConfiguration
    ) -> AIProviderRequest {
        AIProviderRequest(
            model: configuration.model,
            messages: messages,
            tools: availableToolDefinitions,
            temperature: configuration.temperature,
            reasoningEffort: configuration.reasoningEffort,
            maxOutputTokens: configuration.maxOutputTokens,
            cacheMode: configuration.cacheMode
        )
    }
}
