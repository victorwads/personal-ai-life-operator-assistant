import Foundation

struct MCPIssueIdValidator: MCPToolCallValidator {
    let name = "MCPIssueIdValidator"

    private let issueValidator: @MainActor @Sendable () -> any IssueReferenceValidating

    init(
        issueValidator: @escaping @MainActor @Sendable () -> any IssueReferenceValidating
    ) {
        self.issueValidator = issueValidator
    }

    func validate(
        call: MCPToolCall,
        definition: any MCPToolDefinition,
        context _: MCPToolValidationContext
    ) async -> MCPToolValidationResult {
        guard let issueValue = call.arguments["issueId"] else {
            return .success
        }

        guard case .string(let issueIdRaw) = issueValue, let issueId = issueIdRaw.trimmedNonEmpty else {
            return .failure([
                MCPToolValidationError(
                    message: "Field \"issueId\" must be a non-empty string.",
                    suggestedAction: "Use list_active_issues to find a related active issue, or create_issue to create one before retrying.",
                    fieldPath: "issueId",
                    validatorName: name,
                    toolName: definition.name
                )
            ])
        }

        do {
            let validator = await issueValidator()
            _ = try await validator.validateIssueId(issueId)
            return .success
        } catch {
            return .failure([
                MCPToolValidationError(
                    message: "Invalid or inactive issueId \"\(issueId)\".",
                    suggestedAction: "Use list_active_issues to find a related active issue, or create_issue to create one before retrying.",
                    fieldPath: "issueId",
                    validatorName: name,
                    toolName: definition.name
                )
            ])
        }
    }
}
