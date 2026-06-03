import Foundation

struct MCPArgumentTypeValidator: MCPToolCallValidator {
    let name = "MCPArgumentTypeValidator"

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

            for (fieldName, value) in call.arguments {
                guard let expectedType = schemaDescription.expectedTypes[fieldName] else {
                    continue
                }

                switch expectedType {
                case .supported(let fieldType):
                    guard value.matches(fieldType: fieldType) else {
                        errors.append(
                            MCPToolValidationError(
                                message: "Field \"\(fieldName)\" must be a \(fieldType.rawValue).",
                                suggestedAction: "Send \"\(fieldName)\" as a \(fieldType.rawValue) value before retrying.",
                                fieldPath: fieldName,
                                validatorName: name,
                                toolName: definition.name
                            )
                        )
                        continue
                    }
                case .unsupported(let rawType):
                    let schemaType = rawType == "missing" ? "missing" : "\"\(rawType)\""
                    errors.append(
                        MCPToolValidationError(
                            message: "Field \"\(fieldName)\" uses an unsupported schema type \(schemaType).",
                            suggestedAction: "Fix the schema type for \"\(fieldName)\" before retrying this tool call.",
                            fieldPath: fieldName,
                            validatorName: name,
                            toolName: definition.name
                        )
                    )
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

private extension MCPJSONValue {
    func matches(fieldType: MCPToolFieldType) -> Bool {
        switch fieldType {
        case .string:
            if case .string = self { return true }
            return false
        case .number:
            if case .int = self { return true }
            if case .double = self { return true }
            return false
        case .integer:
            if case .int = self { return true }
            return false
        case .boolean:
            if case .bool = self { return true }
            return false
        case .object:
            if case .object = self { return true }
            return false
        case .array:
            if case .array = self { return true }
            return false
        case .null:
            if case .null = self { return true }
            return false
        }
    }
}
