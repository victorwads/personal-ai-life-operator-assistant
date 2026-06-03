import Foundation

enum MCPToolValidationResult: Sendable {
    case success
    case failure([MCPToolValidationError])
}
