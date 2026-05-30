import Foundation

enum MCPToolArguments {
    static func requiredString(_ name: String, from call: MCPToolCall) throws -> String {
        guard let value = call.arguments[name]?.stringValue?.trimmedNonEmpty else {
            throw MCPToolArgumentError.missingRequired(name)
        }
        return value
    }

    static func optionalString(_ name: String, from call: MCPToolCall) -> String? {
        call.arguments[name]?.stringValue?.trimmedNonEmpty
    }

    static func optionalInt(_ name: String, from call: MCPToolCall) -> Int? {
        call.arguments[name]?.intValue
    }

    static func optionalDate(_ name: String, from call: MCPToolCall) -> Date? {
        guard case .string(let text)? = call.arguments[name] else {
            return nil
        }
        return ISO8601DateFormatter().date(from: text)
    }

    static func requiredDate(_ name: String, from call: MCPToolCall) throws -> Date {
        guard let value = call.arguments[name] else {
            throw MCPToolArgumentError.missingRequired(name)
        }

        guard case .string(let text) = value, let date = ISO8601DateFormatter().date(from: text) else {
            throw MCPToolArgumentError.invalidDate(name)
        }

        return date
    }

    static func optionalLimit(from call: MCPToolCall, default defaultValue: Int) -> Int {
        guard let value = call.arguments["limit"]?.intValue else {
            return defaultValue
        }
        return max(1, value)
    }
}

enum MCPToolArgumentError: Error {
    case missingRequired(String)
    case invalidDate(String)

    var serverError: MCPServerError {
        switch self {
        case .missingRequired(let name):
            return .invalidArguments("Missing required argument `\(name)`.")
        case .invalidDate(let name):
            return .invalidArguments("Invalid date format for argument `\(name)`. Use ISO-8601.")
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
