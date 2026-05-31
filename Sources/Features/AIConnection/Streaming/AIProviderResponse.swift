import Foundation

struct AIProviderResponse: Equatable, Sendable {
    let id: String?
    let model: String
    let provider: AIConnectionProviderKind
    let finishReason: String?
    let text: String
    let reasoning: String
    let toolCalls: [AIRequestedToolCall]
    let usage: AIUsage?
}
