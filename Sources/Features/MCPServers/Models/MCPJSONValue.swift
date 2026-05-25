import Foundation

enum MCPJSONValue: Codable, Equatable, Sendable, CustomStringConvertible {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([MCPJSONValue])
    case object([String: MCPJSONValue])

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
            var values: [MCPJSONValue] = []
            while !container.isAtEnd {
                values.append(try container.decode(MCPJSONValue.self))
            }
            self = .array(values)
            return
        }

        let objectContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var object: [String: MCPJSONValue] = [:]
        for key in objectContainer.allKeys {
            object[key.stringValue] = try objectContainer.decode(MCPJSONValue.self, forKey: key)
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

    var description: String {
        switch self {
        case .null:
            return "null"
        case let .bool(value):
            return String(value)
        case let .int(value):
            return String(value)
        case let .double(value):
            return String(value)
        case let .string(value):
            return value
        case let .array(values):
            return values.map(\.description).joined(separator: ", ")
        case let .object(values):
            return values
                .map { "\($0.key): \($0.value.description)" }
                .sorted()
                .joined(separator: ", ")
        }
    }
}

extension MCPJSONValue {
    static func number(_ value: Double) -> MCPJSONValue {
        .double(value)
    }

    static func integer(_ value: Int) -> MCPJSONValue {
        .int(value)
    }
}
