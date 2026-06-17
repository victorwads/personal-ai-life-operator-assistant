import Foundation

public enum AIRuntimeError: Error, LocalizedError {
    case modelNotLoaded
    case promptResourceNotFound(String)
    case promptCacheNotPrepared(String)
    case promptCachePersistenceFailed(String)
    case promptCacheRestoreFailed(String)
    case invalidImage(URL)
    case imageInputUnsupported
    case imageExtractionFailed(String)
    case mlxArraySerializationUnavailable

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "AIRuntime model is not loaded."
        case let .promptResourceNotFound(message):
            return message
        case let .promptCacheNotPrepared(name):
            return "Prompt cache was not prepared for \(name)."
        case let .promptCachePersistenceFailed(message):
            return "Prompt cache persistence failed: \(message)"
        case let .promptCacheRestoreFailed(message):
            return "Prompt cache restore failed: \(message)"
        case let .invalidImage(url):
            return "The selected image could not be loaded: \(url.path)"
        case .imageInputUnsupported:
            return "The current model/runtime does not support image input through the available mlx-swift-lm API."
        case let .imageExtractionFailed(message):
            return "Image extraction failed: \(message)"
        case .mlxArraySerializationUnavailable:
            return "MLXArray serialization is unavailable for prompt cache persistence."
        }
    }
}
