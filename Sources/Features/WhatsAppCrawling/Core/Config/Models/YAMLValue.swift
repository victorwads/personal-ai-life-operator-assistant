import Foundation

enum YAMLValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([YAMLValue])
    case dictionary([String: YAMLValue])
    case null

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if container.decodeNil() {
                self = .null
                return
            }

            if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
                return
            }

            if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
                return
            }

            if let doubleValue = try? container.decode(Double.self) {
                self = .double(doubleValue)
                return
            }

            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
                return
            }
        }

        if let container = try? decoder.unkeyedContainer() {
            var values: [YAMLValue] = []
            var unkeyed = container
            while !unkeyed.isAtEnd {
                let value = try unkeyed.decode(YAMLValue.self)
                values.append(value)
            }
            self = .array(values)
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var dictionary: [String: YAMLValue] = [:]
        for key in container.allKeys {
            dictionary[key.stringValue] = try container.decode(YAMLValue.self, forKey: key)
        }
        self = .dictionary(dictionary)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .int(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .dictionary(values):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in values {
                try container.encode(value, forKey: DynamicCodingKey.key(key))
            }
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}
