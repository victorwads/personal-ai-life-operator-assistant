import Foundation

final class AIConnectionStreamingService: AIConnectionStreamingServing {
    private let settingsProvider: @Sendable () async -> AIConnectionProviderConfiguration
    private let providerExchangeLogger: @Sendable (AIConnectionErrorLogStore.ProviderExchangeLogPayload) -> Void

    // TODO: Implement the real agent tool loop.
    // For now this service can expose tools and execute a requested tool call,
    // but streaming does not yet consume model tool calls and continue the conversation.
    private let toolCatalog: any AIConnectionToolCataloging
    private let toolExecutor: any AIConnectionToolExecuting

    init(
        settingsProvider: @escaping @Sendable () async -> AIConnectionProviderConfiguration,
        toolCatalog: any AIConnectionToolCataloging,
        toolExecutor: any AIConnectionToolExecuting,
        providerExchangeLogger: @escaping @Sendable (AIConnectionErrorLogStore.ProviderExchangeLogPayload) -> Void = { _ in }
    ) {
        self.settingsProvider = settingsProvider
        self.toolCatalog = toolCatalog
        self.toolExecutor = toolExecutor
        self.providerExchangeLogger = providerExchangeLogger
    }

    func streamEvents(
        for request: AIProviderRequest
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let configuration = await settingsProvider()
                    let normalizedRequest = AIProviderRequest(
                        model: request.model.isEmpty ? configuration.model : request.model,
                        messages: request.messages,
                        tools: request.tools.isEmpty ? await availableTools() : request.tools,
                        temperature: request.temperature,
                        reasoningEffort: request.reasoningEffort,
                        maxOutputTokens: request.maxOutputTokens,
                        cacheMode: request.cacheMode
                    )

                    let client = OpenAICompatibleStreamingClient(
                        configuration: configuration,
                        providerExchangeLogger: providerExchangeLogger
                    )
                    for try await event in client.streamEvents(for: normalizedRequest) {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func availableTools() async -> [AIToolDefinition] {
        await MainActor.run {
            toolCatalog.listTools()
        }
    }

    func executeToolCall(_ toolCall: AIRequestedToolCall) async -> AIToolExecutionResult {
        await toolExecutor.executeToolCall(toolCall)
    }
}
