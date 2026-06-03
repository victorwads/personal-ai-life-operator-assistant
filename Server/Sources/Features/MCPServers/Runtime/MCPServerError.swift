import Foundation

enum MCPServerError: Error, Codable, Equatable, Sendable, LocalizedError {
    case notImplemented(String)
    case invalidArguments(String)
    case toolNotFound(String)
    case validationFailed([MCPToolValidationError])
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
        case let .validationFailed(validationErrors):
            return MCPValidationFailureFormatter.format(validationErrors)
        case let .executionFailed(message):
            return message
        case .cancelled:
            return "Cancelled"
        }
    }
}

private enum MCPValidationFailureFormatter {
    static func format(_ errors: [MCPToolValidationError]) -> String {
        let details = errors.map(formatLine).joined(separator: "\n")

        return """
        Tool call rejected: validation failed.
        Fix the following issues:
        
        \(details)
        """
    }

    private static func formatLine(_ error: MCPToolValidationError) -> String {
        return """
        Message: \(error.message)"
        Suggested action: \(error.suggestedAction)
        """
    }
}
