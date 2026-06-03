import Foundation

enum MCPToolInputSchemaReaderError: Error {
    case malformed(String)
}

enum MCPToolFieldType: String, Sendable {
    case string
    case number
    case integer
    case boolean
    case object
    case array
    case null
}

enum MCPToolExpectedFieldType: Sendable {
    case supported(MCPToolFieldType)
    case unsupported(String)
}

struct MCPToolInputSchemaDescription: Sendable {
    let allowedFieldNames: [String]
    let requiredFieldNames: [String]
    let expectedTypes: [String: MCPToolExpectedFieldType]
    let enumAllowedValues: [String: [String]]
}

struct MCPToolInputSchemaReader {
    static func read(from schema: MCPJSONValue) throws -> MCPToolInputSchemaDescription {
        guard case .object(let root) = schema else {
            throw MCPToolInputSchemaReaderError.malformed("inputSchema must be an object.")
        }

        guard root["type"]?.stringValue == "object" else {
            throw MCPToolInputSchemaReaderError.malformed("inputSchema type must be \"object\".")
        }

        guard case .object(let properties)? = root["properties"] else {
            throw MCPToolInputSchemaReaderError.malformed("inputSchema properties must be an object.")
        }

        let requiredFieldNames = try readRequiredFieldNames(from: root["required"])

        let allowedFieldNames = properties.keys.sorted()
        var expectedTypes: [String: MCPToolExpectedFieldType] = [:]
        var enumAllowedValues: [String: [String]] = [:]
        for fieldName in allowedFieldNames {
            guard case .object(let propertySchema)? = properties[fieldName] else {
                throw MCPToolInputSchemaReaderError.malformed("Schema for field \"\(fieldName)\" must be an object.")
            }

            guard let rawType = propertySchema["type"]?.stringValue else {
                expectedTypes[fieldName] = .unsupported("missing")
                continue
            }

            if let supportedType = MCPToolFieldType(rawValue: rawType) {
                expectedTypes[fieldName] = .supported(supportedType)
            } else {
                expectedTypes[fieldName] = .unsupported(rawType)
            }

            if let enumValues = try readEnumValues(from: propertySchema, fieldName: fieldName) {
                enumAllowedValues[fieldName] = enumValues
            }
        }

        return MCPToolInputSchemaDescription(
            allowedFieldNames: allowedFieldNames,
            requiredFieldNames: requiredFieldNames,
            expectedTypes: expectedTypes,
            enumAllowedValues: enumAllowedValues
        )
    }

    private static func readEnumValues(
        from propertySchema: [String: MCPJSONValue],
        fieldName: String
    ) throws -> [String]? {
        guard let enumValue = propertySchema["enum"] else {
            return nil
        }

        guard case .array(let values) = enumValue else {
            throw MCPToolInputSchemaReaderError.malformed("Schema enum for field \"\(fieldName)\" must be an array.")
        }

        return try values.map { value in
            guard case .string(let text) = value else {
                throw MCPToolInputSchemaReaderError.malformed("Schema enum values for field \"\(fieldName)\" must be strings.")
            }
            return text
        }
    }

    private static func readRequiredFieldNames(
        from requiredValue: MCPJSONValue?
    ) throws -> [String] {
        guard let requiredValue else {
            return []
        }

        guard case .array(let values) = requiredValue else {
            throw MCPToolInputSchemaReaderError.malformed("inputSchema required must be an array of field names.")
        }

        return try values.map { value in
            guard case .string(let fieldName) = value else {
                throw MCPToolInputSchemaReaderError.malformed("inputSchema required entries must be strings.")
            }
            return fieldName
        }
    }
}
