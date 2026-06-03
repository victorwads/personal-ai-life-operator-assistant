import Foundation

struct MCPToolValidationError: Error, Codable, Equatable, Sendable {
    let message: String
    let suggestedAction: String
    let fieldPath: String
    let validatorName: String
    let toolName: String
}
