import Foundation

struct AIRunUsageState {
    var inputTokens: Int?
    var outputTokens: Int?
    var reasoningTokens: Int?
    var totalTokens: Int?
    var isOutputTokensEstimated = false
    var tokensPerSecond: Double?
    var timeToFirstToken: TimeInterval?
    var runDuration: TimeInterval?
    var runStartedAt: Date?
    var lastUpdatedAt: Date?
}
