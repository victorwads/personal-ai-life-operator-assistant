import Foundation

struct MCPEnumValidator: MCPToolCallValidator {
    let name = "MCPEnumValidator"

    func validate(
        call: MCPToolCall,
        definition: any MCPToolDefinition,
        context _: MCPToolValidationContext
    ) async -> MCPToolValidationResult {
        let schemaDescriptionResult = schemaDescription(for: definition)
        switch schemaDescriptionResult {
        case .failure(let error):
            return .failure([error])
        case .success(let schemaDescription):
            var errors: [MCPToolValidationError] = []
            for (fieldName, allowedValues) in schemaDescription.enumAllowedValues {
                guard let value = call.arguments[fieldName] else {
                    continue
                }

                guard case .string(let text) = value else {
                    continue
                }

                guard allowedValues.contains(text) else {
                    let allowedValuesText = allowedValues.joined(separator: ", ")
                    errors.append(
                        MCPToolValidationError(
                            message: "Field \"\(fieldName)\" has unsupported value \"\(text)\".",
                            suggestedAction: "Use one of the supported values: \(allowedValuesText).",
                            fieldPath: fieldName,
                            validatorName: name,
                            toolName: definition.name
                        )
                    )
                    continue
                }
            }

            return errors.isEmpty ? .success : .failure(errors)
        }
    }

    private func schemaDescription(
        for definition: any MCPToolDefinition
    ) -> Result<MCPToolInputSchemaDescription, MCPToolValidationError> {
        do {
            return .success(try MCPToolInputSchemaReader.read(from: definition.inputSchema))
        } catch let error as MCPToolInputSchemaReaderError {
            return .failure(rootSchemaError(for: error, toolName: definition.name))
        } catch {
            return .failure(rootSchemaError(for: .malformed("Unknown schema parsing error."), toolName: definition.name))
        }
    }

    private func rootSchemaError(
        for error: MCPToolInputSchemaReaderError,
        toolName: String
    ) -> MCPToolValidationError {
        let detail: String
        switch error {
        case .malformed(let message):
            detail = message
        }

        return MCPToolValidationError(
            message: "Tool input schema is malformed. \(detail)",
            suggestedAction: "Fix the tool schema before retrying this tool call.",
            fieldPath: "$",
            validatorName: name,
            toolName: toolName
        )
    }
}
