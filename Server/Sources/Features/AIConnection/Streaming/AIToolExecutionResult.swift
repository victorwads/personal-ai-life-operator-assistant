import Foundation

struct AIToolExecutionResult: Equatable, Sendable {
    struct ValidationError: Equatable, Sendable {
        let fieldPath: String
        let message: String
        let suggestedAction: String
    }

    let toolName: String
    let success: Bool
    let payload: AIJSONValue?
    let errorMessage: String?
    let suggestedAction: String?
    let validationErrors: [ValidationError]
    let durationMilliseconds: Double?
}
