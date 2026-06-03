import Foundation

enum MCPSupport {
    static func string(_ name: String, from call: MCPToolCall) throws -> String {
        guard let value = call.arguments[name]?.stringValue?.trimmedNonEmpty else {
            throw MCPToolExtractionError.missingOrInvalid(name)
        }
        return value
    }

    static func optionalString(_ name: String, from call: MCPToolCall) -> String? {
        call.arguments[name]?.stringValue?.trimmedNonEmpty
    }

    static func int(_ name: String, from call: MCPToolCall) throws -> Int {
        guard let value = call.arguments[name]?.intValue else {
            throw MCPToolExtractionError.missingOrInvalid(name)
        }
        return value
    }

    static func optionalInt(_ name: String, from call: MCPToolCall) -> Int? {
        call.arguments[name]?.intValue
    }

    static func optionalLimit(from call: MCPToolCall, default defaultValue: Int) -> Int {
        guard let value = call.arguments["limit"]?.intValue else {
            return defaultValue
        }
        return max(1, value)
    }

    static func date(_ name: String, from call: MCPToolCall) throws -> Date {
        guard let value = call.arguments[name] else {
            throw MCPToolExtractionError.missingOrInvalid(name)
        }

        guard case .string(let text) = value, let date = ISO8601DateFormatter().date(from: text) else {
            throw MCPToolExtractionError.invalidDate(name)
        }

        return date
    }

    static func optionalDate(_ name: String, from call: MCPToolCall) throws -> Date? {
        guard case .string(let text)? = call.arguments[name] else {
            return nil
        }
        guard let date = ISO8601DateFormatter().date(from: text) else {
            throw MCPToolExtractionError.invalidDate(name)
        }
        return date
    }

    static func defineEnum<T: CaseIterable & RawRepresentable>(_ type: T.Type) -> MCPJSONValue
    where T.RawValue == String {
        .array(T.allCases.map { .string($0.rawValue) })
    }
}

enum MCPToolExtractionError: Error, LocalizedError {
    case missingOrInvalid(String)
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case let .missingOrInvalid(field):
            return "Tool argument extraction failed for field `\(field)`."
        case let .invalidDate(field):
            return "Tool argument extraction failed for date field `\(field)`; expected ISO-8601."
        }
    }
}

extension MCPJSONValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        case .string(let value):
            return Int(value)
        default:
            return nil
        }
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
