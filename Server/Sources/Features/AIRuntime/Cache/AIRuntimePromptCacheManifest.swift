import Foundation

public struct AIRuntimePromptCacheManifest: Codable, Sendable {
    public let key: AIRuntimePromptCacheKey
    public let tokenCount: Int
    public let cacheFileCount: Int
    public let layerCount: Int
    public let metaState: [[String]]
    public let createdAt: Date
    public let updatedAt: Date
    public let restoredFromDisk: Bool

    public init(
        key: AIRuntimePromptCacheKey,
        tokenCount: Int,
        cacheFileCount: Int,
        layerCount: Int,
        metaState: [[String]],
        createdAt: Date,
        updatedAt: Date,
        restoredFromDisk: Bool
    ) {
        self.key = key
        self.tokenCount = tokenCount
        self.cacheFileCount = cacheFileCount
        self.layerCount = layerCount
        self.metaState = metaState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.restoredFromDisk = restoredFromDisk
    }
}
