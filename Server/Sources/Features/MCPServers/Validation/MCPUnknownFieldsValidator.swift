import Foundation

struct MCPUnknownFieldsValidator: MCPToolCallValidator {
    let name = "MCPUnknownFieldsValidator"

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
            let allowedFieldNames = Set(schemaDescription.allowedFieldNames)
            let unknownFields = call.arguments.keys
                .filter { !allowedFieldNames.contains($0) }
                .sorted()

            let supportedFields = schemaDescription.allowedFieldNames.joined(separator: ", ")
            let errors = unknownFields.map { fieldName in
                MCPToolValidationError(
                    message: "Unknown field \"\(fieldName)\".",
                    suggestedAction: "Remove \"\(fieldName)\" or replace it with one of the supported fields: \(supportedFields).",
                    fieldPath: fieldName,
                    validatorName: name,
                    toolName: definition.name
                )
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
