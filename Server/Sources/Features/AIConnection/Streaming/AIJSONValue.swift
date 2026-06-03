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
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else if CFNumberIsFloatType(value) {
                self = .double(value.doubleValue)
            } else {
                self = .int(value.intValue)
            }
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
        let candidateStrings = normalizedObjectCandidates(from: jsonString)
        var lastParsingError: Error?

        for candidate in candidateStrings {
            do {
                if let dictionary = try parseJSONObjectCandidate(candidate) {
                    return try dictionary.mapValues(AIJSONValue.init(any:))
                }
            } catch {
                lastParsingError = error
            }
        }

        if let lastParsingError {
            throw AIJSONValueError.invalidJSONObject(lastParsingError.localizedDescription)
        }

        throw AIJSONValueError.expectedObjectRoot
    }

    private static func parseJSONObjectCandidate(_ jsonString: String) throws -> [String: Any]? {
        let data = Data(jsonString.utf8)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            if let decodedString = try? JSONDecoder().decode(String.self, from: data) {
                return try parseNestedJSONObjectString(decodedString)
            }
            throw error
        }

        if let dictionary = object as? [String: Any] {
            return dictionary
        }

        // Some providers/models double-encode the tool arguments as a JSON string.
        if let nestedJSONString = object as? String {
            return try parseNestedJSONObjectString(nestedJSONString)
        }

        return nil
    }

    private static func parseNestedJSONObjectString(_ nestedJSONString: String) throws -> [String: Any]? {
        let nestedCandidates = normalizedObjectCandidates(from: nestedJSONString)
        for nestedCandidate in nestedCandidates {
            let nestedData = Data(nestedCandidate.utf8)
            let nestedObject = try JSONSerialization.jsonObject(with: nestedData)
            if let nestedDictionary = nestedObject as? [String: Any] {
                return nestedDictionary
            }
        }

        // Some payloads arrive wrapped as a quoted string but are not decoded
        // cleanly by the first pass, so we try to unquote them once more.
        if nestedJSONString.hasPrefix("\""), nestedJSONString.hasSuffix("\"") {
            let requotedData = Data(nestedJSONString.utf8)
            let decodedString = try JSONDecoder().decode(String.self, from: requotedData)
            let decodedCandidates = normalizedObjectCandidates(from: decodedString)
            for decodedCandidate in decodedCandidates {
                let decodedData = Data(decodedCandidate.utf8)
                let decodedObject = try JSONSerialization.jsonObject(with: decodedData)
                if let decodedDictionary = decodedObject as? [String: Any] {
                    return decodedDictionary
                }
            }
        }

        return nil
    }

    private static func normalizedObjectCandidates(from rawText: String) -> [String] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ["{}"] }
        if trimmed == "null" {
            return ["{}"]
        }

        var candidates: [String] = [trimmed]

        if let strippedFence = stripMarkdownCodeFence(from: trimmed), strippedFence != trimmed {
            candidates.append(strippedFence)
        }

        if let extractedJSONObject = extractFirstJSONObject(from: trimmed), extractedJSONObject != trimmed {
            candidates.append(extractedJSONObject)
        }

        if let strippedFence = stripMarkdownCodeFence(from: trimmed),
           let extractedJSONObject = extractFirstJSONObject(from: strippedFence),
           extractedJSONObject != strippedFence {
            candidates.append(extractedJSONObject)
        }

        var uniqueCandidates: [String] = []
        for candidate in candidates where !uniqueCandidates.contains(candidate) {
            uniqueCandidates.append(candidate)
        }
        return uniqueCandidates
    }

    private static func stripMarkdownCodeFence(from text: String) -> String? {
        guard text.hasPrefix("```"), text.hasSuffix("```") else {
            return nil
        }

        var lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return nil }
        lines.removeFirst()
        if !lines.isEmpty, lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractFirstJSONObject(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var isInsideString = false
        var isEscaping = false

        for index in text[startIndex...].indices {
            let character = text[index]

            if isEscaping {
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if character == "\"" {
                isInsideString.toggle()
                continue
            }

            if isInsideString {
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[startIndex...index])
                }
            }
        }

        return nil
    }
}

private enum AIJSONValueError: LocalizedError {
    case unsupportedValueType(String)
    case invalidUTF8Encoding
    case invalidJSONObject(String)
    case expectedObjectRoot

    var errorDescription: String? {
        switch self {
        case let .unsupportedValueType(typeName):
            return "Unsupported JSON value type: \(typeName)"
        case .invalidUTF8Encoding:
            return "Failed to encode JSON as UTF-8."
        case let .invalidJSONObject(message):
            return "Failed to parse tool call arguments as JSON: \(message)"
        case .expectedObjectRoot:
            return "Expected a JSON object at the root."
        }
    }
}
