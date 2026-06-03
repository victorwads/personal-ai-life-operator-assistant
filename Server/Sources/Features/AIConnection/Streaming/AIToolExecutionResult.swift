import Foundation

struct AIToolExecutionResult: Equatable, Sendable {
    let toolName: String
    let success: Bool
    let payload: AIJSONValue?
    let errorMessage: String?
    let suggestedAction: String?
    let durationMilliseconds: Double?
}
