import Foundation

@MainActor
protocol AIConnectionToolExecuting {
    func executeToolCall(_ toolCall: AIRequestedToolCall) async -> AIToolExecutionResult
}
