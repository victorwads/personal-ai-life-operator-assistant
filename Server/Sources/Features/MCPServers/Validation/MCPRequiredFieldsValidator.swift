import Foundation

struct MCPRequiredFieldsValidator: MCPToolCallValidator {
    let name = "MCPRequiredFieldsValidator"

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
            let errors = schemaDescription.requiredFieldNames.compactMap { fieldName in
                guard let value = call.arguments[fieldName], value != .null else {
                    return MCPToolValidationError(
                        message: "Missing required field \"\(fieldName)\".",
                        suggestedAction: "Provide the required field \"\(fieldName)\" before retrying the tool call.",
                        fieldPath: fieldName,
                        validatorName: name,
                        toolName: definition.name
                    )
                }

                if isEmptyRequiredString(value, fieldName: fieldName, schemaDescription: schemaDescription) {
                    return MCPToolValidationError(
                        message: "Required field \"\(fieldName)\" must not be empty.",
                        suggestedAction: "Provide a non-empty value for \"\(fieldName)\" before retrying the tool call.",
                        fieldPath: fieldName,
                        validatorName: name,
                        toolName: definition.name
                    )
                }

                return nil
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

    private func isEmptyRequiredString(
        _ value: MCPJSONValue,
        fieldName: String,
        schemaDescription: MCPToolInputSchemaDescription
    ) -> Bool {
        guard
            case .supported(.string)? = schemaDescription.expectedTypes[fieldName],
            case .string(let text) = value
        else {
            return false
        }

        return text.trimmedNonEmpty == nil
    }
}
