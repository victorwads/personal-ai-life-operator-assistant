import Foundation

protocol AIConnectionStreamingServing {
    func streamEvents(
        for request: AIProviderRequest,
        overrideConfiguration: AIConnectionProviderConfiguration?
    ) -> AsyncThrowingStream<AIStreamEvent, Error>

    func availableTools() async -> [AIToolDefinition]
    func executeToolCall(_ toolCall: AIRequestedToolCall) async -> AIToolExecutionResult
}

extension AIConnectionStreamingServing {
    func streamEvents(
        for request: AIProviderRequest
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        streamEvents(for: request, overrideConfiguration: nil)
    }
}

