import Foundation

enum AIResourceUsagePool: String, Codable, CaseIterable, Sendable {
    case total
    case assistant
    case imageExtraction
}

struct AIResourceTokenUsage: Codable, Equatable, Sendable {
    var requests: Int
    var inputTokens: Int
    var outputTokens: Int
    var reasoningTokens: Int
    var cachedInputTokens: Int
    var totalTokens: Int

    init(
        requests: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        reasoningTokens: Int = 0,
        cachedInputTokens: Int = 0,
        totalTokens: Int = 0
    ) {
        self.requests = requests
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.cachedInputTokens = cachedInputTokens
        self.totalTokens = totalTokens
    }
}

struct AIResourceUsageAddition: Equatable, Sendable {
    let pool: AIResourceUsagePool
    let provider: AIConnectionProviderKind?
    let model: String?
    let usage: AIUsage
    let success: Bool

    init(
        pool: AIResourceUsagePool,
        provider: AIConnectionProviderKind?,
        model: String?,
        usage: AIUsage,
        success: Bool
    ) {
        self.pool = pool
        self.provider = provider
        self.model = model
        self.usage = usage
        self.success = success
    }
}
