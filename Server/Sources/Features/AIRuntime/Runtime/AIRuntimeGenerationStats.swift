import Foundation

public struct AIRuntimeGenerationStats: Sendable, Equatable {
    public let promptTokenCount: Int
    public let generationTokenCount: Int
    public let promptTokensPerSecond: Double
    public let tokensPerSecond: Double
    public let promptTime: TimeInterval
    public let generateTime: TimeInterval

    public init(
        promptTokenCount: Int,
        generationTokenCount: Int,
        promptTokensPerSecond: Double,
        tokensPerSecond: Double,
        promptTime: TimeInterval,
        generateTime: TimeInterval
    ) {
        self.promptTokenCount = promptTokenCount
        self.generationTokenCount = generationTokenCount
        self.promptTokensPerSecond = promptTokensPerSecond
        self.tokensPerSecond = tokensPerSecond
        self.promptTime = promptTime
        self.generateTime = generateTime
    }
}

public enum AIRuntimeStreamEvent: Sendable, Equatable {
    case chunk(String)
    case stats(AIRuntimeGenerationStats)
    case startedDecoding
}
