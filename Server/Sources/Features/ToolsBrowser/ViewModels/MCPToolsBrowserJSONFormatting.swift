import Foundation

enum MCPToolsBrowserJSONFormatting {
    static func prettyPrinted(_ value: MCPJSONValue) -> String {
        guard
            let data = try? JSONEncoder().encode(value),
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let string = String(data: prettyData, encoding: .utf8)
        else {
            return value.description
        }

        return string.replacingOccurrences(of: "\\/", with: "/")
    }

    static func prettyPrinted(call: MCPToolCall) -> String {
        prettyPrinted(.object([
            "name": .string(call.name),
            "arguments": .object(call.arguments)
        ]))
    }

    static func prettyPrinted(result: MCPToolExecutionResult) -> String {
        guard
            let data = try? JSONEncoder().encode(result),
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let string = String(data: prettyData, encoding: .utf8)
        else {
            return String(describing: result)
        }

        return string.replacingOccurrences(of: "\\/", with: "/")
    }

    static func prettyPrintedSuccessPayload(_ payload: MCPJSONValue?) -> String? {
        guard let payload else { return nil }

        switch payload {
        case let .string(text):
            return DSDebugMirrorJSON.prettyPrintedJSONString(text) ?? text
        default:
            return prettyPrinted(payload)
        }
    }

    static func parse(_ text: String) -> MCPJSONValue? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MCPJSONValue.self, from: data)
    }
}
