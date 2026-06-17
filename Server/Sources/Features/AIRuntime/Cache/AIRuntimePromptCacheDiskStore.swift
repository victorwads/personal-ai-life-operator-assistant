import Foundation
import MLX
import MLXLMCommon

struct AIRuntimePromptCacheDiskStore: Sendable {
    private let configuration: AIRuntimeConfiguration

    init(configuration: AIRuntimeConfiguration) {
        self.configuration = configuration
    }

    func load(
        key: AIRuntimePromptCacheKey,
        into freshCache: [any KVCache]
    ) throws -> AIRuntimePromptCacheSnapshot? {
        let cacheDirectory = directory(for: key)
        let manifestURL = cacheDirectory.appendingPathComponent("manifest.json")
        let tokenIdsURL = cacheDirectory.appendingPathComponent("tokenIds.json")
        let promptCacheURL = cacheDirectory.appendingPathComponent("prompt-cache.safetensors")

        guard FileManager.default.fileExists(atPath: manifestURL.path),
              FileManager.default.fileExists(atPath: tokenIdsURL.path),
              FileManager.default.fileExists(atPath: promptCacheURL.path) else {
            return nil
        }

        do {
            let manifest = try JSONDecoder().decode(
                AIRuntimePromptCacheManifest.self,
                from: Data(contentsOf: manifestURL)
            )
            let tokenIds = try JSONDecoder().decode(
                [Int].self,
                from: Data(contentsOf: tokenIdsURL)
            )

            guard manifest.layerCount == freshCache.count,
                  manifest.metaState.count == freshCache.count else {
                throw AIRuntimeError.promptCacheRestoreFailed(
                    "Saved layer count does not match the fresh model cache."
                )
            }
            let (loadedCache, _) = try loadPromptCache(url: promptCacheURL)

            guard loadedCache.count == freshCache.count else {
                throw AIRuntimeError.promptCacheRestoreFailed(
                    "Restored cache layer count does not match the fresh model cache."
                )
            }

            let restoredManifest = AIRuntimePromptCacheManifest(
                key: manifest.key,
                tokenCount: manifest.tokenCount,
                cacheFileCount: manifest.cacheFileCount,
                layerCount: manifest.layerCount,
                metaState: manifest.metaState,
                createdAt: manifest.createdAt,
                updatedAt: manifest.updatedAt,
                restoredFromDisk: true
            )

            return AIRuntimePromptCacheSnapshot(
                manifest: restoredManifest,
                tokenIds: tokenIds,
                cache: loadedCache
            )
        } catch let error as AIRuntimeError {
            throw error
        } catch {
            throw AIRuntimeError.promptCacheRestoreFailed(error.localizedDescription)
        }
    }

    func save(
        snapshot: AIRuntimePromptCacheSnapshot
    ) throws {
        let cacheDirectory = directory(for: snapshot.manifest.key)
        let promptCacheURL = cacheDirectory.appendingPathComponent("prompt-cache.safetensors")

        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let persistedManifest = AIRuntimePromptCacheManifest(
                key: snapshot.manifest.key,
                tokenCount: snapshot.manifest.tokenCount,
                cacheFileCount: 1,
                layerCount: snapshot.manifest.layerCount,
                metaState: snapshot.manifest.metaState,
                createdAt: snapshot.manifest.createdAt,
                updatedAt: snapshot.manifest.updatedAt,
                restoredFromDisk: false
            )

            let manifestData = try JSONEncoder.prettyPrinted.encode(persistedManifest)
            try manifestData.write(
                to: cacheDirectory.appendingPathComponent("manifest.json"),
                options: .atomic
            )

            let tokenIdsData = try JSONEncoder.prettyPrinted.encode(snapshot.tokenIds)
            try tokenIdsData.write(
                to: cacheDirectory.appendingPathComponent("tokenIds.json"),
                options: .atomic
            )
            try savePromptCache(url: promptCacheURL, cache: snapshot.cache, metadata: [:])
        } catch let error as AIRuntimeError {
            throw error
        } catch {
            throw AIRuntimeError.promptCachePersistenceFailed(error.localizedDescription)
        }
    }

    func removeAll() throws {
        let rootDirectory = promptCachesRootDirectory
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: rootDirectory)
        } catch {
            throw AIRuntimeError.promptCachePersistenceFailed(error.localizedDescription)
        }
    }

    private var promptCachesRootDirectory: URL {
        ApplicationSupportStorage
            .appSupportDirectoryURL(appending: [configuration.applicationSupportDirectoryName])
            .appendingPathComponent("PromptCaches", isDirectory: true)
    }

    private func directory(for key: AIRuntimePromptCacheKey) -> URL {
        promptCachesRootDirectory
            .appendingPathComponent(sanitizedModelId(key.modelId), isDirectory: true)
            .appendingPathComponent("\(key.promptName)-\(key.promptHash)", isDirectory: true)
    }

    private func sanitizedModelId(_ modelId: String) -> String {
        modelId.replacingOccurrences(of: "/", with: "_")
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
