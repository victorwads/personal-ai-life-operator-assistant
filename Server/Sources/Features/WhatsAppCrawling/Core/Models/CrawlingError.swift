import Foundation

enum CrawlingError: Error, Equatable, LocalizedError {
    case invalidConfig(String)
    case parsingFailed(String)
    case runtimeUnavailable(String)
    case interactionFailed(String)
    case notImplemented(String)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfig(message):
            return "Invalid config: \(message)"
        case let .parsingFailed(message):
            return "Parsing failed: \(message)"
        case let .runtimeUnavailable(message):
            return "Runtime unavailable: \(message)"
        case let .interactionFailed(message):
            return "Interaction failed: \(message)"
        case let .notImplemented(message):
            return "Not implemented: \(message)"
        case .cancelled:
            return "Cancelled"
        case let .unknown(message):
            return "Unknown error: \(message)"
        }
    }
}
