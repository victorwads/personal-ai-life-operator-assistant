import Foundation

public struct AIRuntimePromptCacheKey: Hashable, Codable, Sendable {
    public let modelId: String
    public let promptName: String
    public let promptHash: String

    public init(modelId: String, promptName: String, promptHash: String) {
        self.modelId = modelId
        self.promptName = promptName
        self.promptHash = promptHash
    }
}
