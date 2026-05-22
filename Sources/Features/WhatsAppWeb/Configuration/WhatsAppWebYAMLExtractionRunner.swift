import Foundation
import WebKit

enum WhatsAppWebYAMLExtractionRunnerError: LocalizedError {
    case invalidSpecRoot
    case invalidResultPayload

    var errorDescription: String? {
        switch self {
        case .invalidSpecRoot:
            return "Invalid YAML spec. Expected a root object."
        case .invalidResultPayload:
            return "Invalid extraction result payload."
        }
    }
}

@MainActor
final class WhatsAppWebYAMLExtractionRunner {
    struct RunResult: Sendable, Equatable {
        let json: String
        let tree: AnySendable
    }

    func run(yamlTree: YAMLTree, webView: WKWebView) async throws -> RunResult {
        let specAny: AnySendable = .object(yamlTree.root)
        let specJSON = try AnySendableJSON.encodeToJSONString(specAny)
        let script = WhatsAppWebJavaScript.makeExtractionScript(specJSONLiteral: specJSON)
        let json = try await evaluateJavaScriptString(script, in: webView)

        guard let data = json.data(using: String.Encoding.utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let any = AnySendableJSON.decodeFromJSONObject(obj) else {
            throw WhatsAppWebYAMLExtractionRunnerError.invalidResultPayload
        }

        return RunResult(json: json, tree: any)
    }

    private func evaluateJavaScriptString(_ javaScript: String, in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let stringResult = result as? String {
                    continuation.resume(returning: stringResult)
                } else if let result {
                    continuation.resume(returning: String(describing: result))
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

enum AnySendableJSON {
    static func encodeToJSONString(_ value: AnySendable) throws -> String {
        let obj = encodeToJSONObject(value)
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func encodeToJSONObject(_ value: AnySendable) -> Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let v):
            return v
        case .int(let v):
            return v
        case .double(let v):
            return v
        case .string(let v):
            return v
        case .array(let values):
            return values.map(encodeToJSONObject)
        case .object(let dict):
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (key, value) in dict {
                out[key] = encodeToJSONObject(value)
            }
            return out
        }
    }

    static func decodeFromJSONObject(_ value: Any?) -> AnySendable? {
        guard let value else { return .null }
        if value is NSNull { return .null }
        if let bool = value as? Bool { return .bool(bool) }
        if let int = value as? Int { return .int(int) }
        if let double = value as? Double { return .double(double) }
        if let number = value as? NSNumber {
            let type = String(cString: number.objCType)
            if type == "c" { return .bool(number.boolValue) }
            let doubleValue = number.doubleValue
            let intValue = number.intValue
            if fabs(doubleValue - Double(intValue)) < .ulpOfOne {
                return .int(intValue)
            }
            return .double(doubleValue)
        }
        if let string = value as? String { return .string(string) }
        if let array = value as? [Any] {
            return .array(array.compactMap { decodeFromJSONObject($0) })
        }
        if let dict = value as? [String: Any] {
            var out: [String: AnySendable] = [:]
            out.reserveCapacity(dict.count)
            for (key, value) in dict {
                out[key] = decodeFromJSONObject(value) ?? .null
            }
            return .object(out)
        }
        return nil
    }
}
