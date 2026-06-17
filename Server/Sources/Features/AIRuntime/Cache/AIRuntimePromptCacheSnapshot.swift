import MLXLMCommon

public final class AIRuntimePromptCacheSnapshot: @unchecked Sendable {
    public let manifest: AIRuntimePromptCacheManifest
    public let tokenIds: [Int]
    public let cache: [any KVCache]

    public init(
        manifest: AIRuntimePromptCacheManifest,
        tokenIds: [Int],
        cache: [any KVCache]
    ) {
        self.manifest = manifest
        self.tokenIds = tokenIds
        self.cache = cache
    }

    public func copyCache() -> [any KVCache] {
        cache.map { $0.copy() }
    }
}
