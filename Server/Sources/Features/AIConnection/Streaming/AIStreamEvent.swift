import Foundation

enum AIStreamEvent: Equatable, Sendable {
    case requestStarted(provider: AIConnectionProviderKind, model: String)
    case responseStarted(id: String?)
    case textDelta(String)
    case reasoningDelta(String)
    case toolCallStarted(id: String, name: String)
    case toolCallArgumentsDelta(id: String, delta: String)
    case toolCallCompleted(AIRequestedToolCall)
    case usage(AIUsage)
    case completed(AIProviderResponse)
    case failed(AIProviderFailure)
}
