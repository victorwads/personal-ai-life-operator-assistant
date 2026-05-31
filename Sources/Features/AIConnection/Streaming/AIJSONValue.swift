import Foundation

// TODO: Consider moving this to Shared as a generic JSON value type.
// This currently duplicates MCPJSONValue to keep AIConnection isolated during the first streaming foundation pass.
// If more features need JSON bridging, unify these types instead of adding more copies.
enum AIJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AIJSONValue])
    case object([String: AIJSONValue])

    init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()
        if singleValue.decodeNil() {
            self = .null
            return
        }

        if let value = try? singleValue.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? singleValue.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? singleValue.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? singleValue.decode(String.self) {
            self = .string(value)
            return
        }

        if let arrayContainer = try? decoder.unkeyedContainer() {
            var container = arrayContainer
            var values: [AIJSONValue] = []
            while !container.isAtEnd {
                values.append(try container.decode(AIJSONValue.self))
            }
            self = .array(values)
            return
        }

        let objectContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var object: [String: AIJSONValue] = [:]
        for key in objectContainer.allKeys {
            object[key.stringValue] = try objectContainer.decode(AIJSONValue.self, forKey: key)
        }
        self = .object(object)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .int(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .object(values):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in values {
                try container.encode(value, forKey: DynamicCodingKey(key))
            }
        }
    }
}

extension AIJSONValue {
    init(any value: Any) throws {
        switch value {
        case is NSNull:
            self = .null
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(try value.map(AIJSONValue.init(any:)))
        case let value as [String: Any]:
            self = .object(try value.mapValues(AIJSONValue.init(any:)))
        default:
            throw AIJSONValueError.unsupportedValueType(String(describing: type(of: value)))
        }
    }

    var foundationValue: Any {
        switch self {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        case let .string(value):
            return value
        case let .array(values):
            return values.map(\.foundationValue)
        case let .object(values):
            return values.mapValues(\.foundationValue)
        }
    }

    func jsonString(prettyPrinted: Bool = false) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: foundationValue,
            options: prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw AIJSONValueError.invalidUTF8Encoding
        }

        return string
    }

    static func parseObject(from jsonString: String) throws -> [String: AIJSONValue] {
        let data = Data(jsonString.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw AIJSONValueError.expectedObjectRoot
        }

        return try dictionary.mapValues(AIJSONValue.init(any:))
    }
}

private enum AIJSONValueError: LocalizedError {
    case unsupportedValueType(String)
    case invalidUTF8Encoding
    case expectedObjectRoot

    var errorDescription: String? {
        switch self {
        case let .unsupportedValueType(typeName):
            return "Unsupported JSON value type: \(typeName)"
        case .invalidUTF8Encoding:
            return "Failed to encode JSON as UTF-8."
        case .expectedObjectRoot:
            return "Expected a JSON object at the root."
        }
    }
}
