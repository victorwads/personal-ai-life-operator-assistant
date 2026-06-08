import Foundation

struct AIRunUsageState {
    var inputTokens: Int?
    var outputTokens: Int?
    var reasoningTokens: Int?
    var cachedInputTokens: Int?
    var totalTokens: Int?
    var isInputTokensEstimated = false
    var isOutputTokensEstimated = false
    var tokensPerSecond: Double?
    var timeToFirstToken: TimeInterval?
    var runDuration: TimeInterval?
    var runStartedAt: Date?
    var lastUpdatedAt: Date?
}

extension AIRunUsageState {
    func normalizedAIUsage() -> AIUsage {
        AIUsage(
            promptTokens: inputTokens,
            completionTokens: outputTokens,
            reasoningTokens: reasoningTokens,
            totalTokens: totalTokens,
            cachedInputTokens: cachedInputTokens
        )
    }
}
