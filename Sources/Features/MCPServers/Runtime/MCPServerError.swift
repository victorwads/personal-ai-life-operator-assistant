import Foundation

enum MCPServerError: Error, Codable, Equatable, Sendable, LocalizedError {
    case notImplemented(String)
    case invalidArguments(String)
    case toolNotFound(String)
    case executionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case let .notImplemented(message):
            return message
        case let .invalidArguments(message):
            return message
        case let .toolNotFound(message):
            return message
        case let .executionFailed(message):
            return message
        case .cancelled:
            return "Cancelled"
        }
    }
}
