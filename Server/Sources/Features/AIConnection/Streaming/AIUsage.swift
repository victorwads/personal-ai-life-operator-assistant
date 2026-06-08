import Foundation

struct AIUsage: Equatable, Sendable {
    let promptTokens: Int?
    let completionTokens: Int?
    let reasoningTokens: Int?
    let totalTokens: Int?
    let cachedInputTokens: Int?

    init(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        totalTokens: Int? = nil,
        cachedInputTokens: Int? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.cachedInputTokens = cachedInputTokens
    }
}
