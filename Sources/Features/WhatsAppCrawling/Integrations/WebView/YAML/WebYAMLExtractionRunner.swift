import Foundation
import WebKit
import Yams

@MainActor
enum WebYAMLExtractionRunner {
    static func run(yamlText: String, in webView: WKWebView) async throws -> String {
        let spec = try makeSpec(from: yamlText)
        let jsonData = try JSONSerialization.data(withJSONObject: spec, options: [])
        guard let specJSON = String(data: jsonData, encoding: .utf8) else {
            throw WebYAMLExtractionRunnerError.invalidSpecEncoding
        }

        let script = """
        (() => {
          const spec = \(specJSON);
          return JSON.stringify(window.AssistantMCP.extractTree(spec), null, 2);
        })();
        """

        let raw = try await evaluate(script: script, in: webView)
        if let value = raw as? String {
            return value
        }
        if let value = raw {
            return String(describing: value)
        }
        return "null"
    }

    static func makeSpec(from yamlText: String) throws -> [String: Any] {
        let loaded = try Yams.load(yaml: yamlText)
        guard let root = loaded else {
            return ["web": [:], "flows": [:]]
        }

        guard let dictionary = normalizeToJSONObject(root) as? [String: Any] else {
            throw WebYAMLExtractionRunnerError.invalidYAMLRoot
        }

        let web = dictionary["web"] as? [String: Any] ?? [:]
        let flows = dictionary["flows"] as? [String: Any] ?? [:]
        return ["web": web, "flows": flows]
    }

    private static func evaluate(script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private static func normalizeToJSONObject(_ value: Any) -> Any? {
        switch value {
        case let value as String:
            return value
        case let value as Bool:
            return value
        case let value as Int:
            return value
        case let value as Double:
            return value
        case let value as Float:
            return Double(value)
        case let value as NSNumber:
            return value
        case is NSNull:
            return NSNull()
        case let array as [Any]:
            return array.compactMap { normalizeToJSONObject($0) }
        case let dict as [String: Any]:
            var normalized: [String: Any] = [:]
            for (key, val) in dict {
                normalized[key] = normalizeToJSONObject(val) ?? NSNull()
            }
            return normalized
        case let dict as [AnyHashable: Any]:
            var normalized: [String: Any] = [:]
            for (key, val) in dict {
                normalized[String(describing: key)] = normalizeToJSONObject(val) ?? NSNull()
            }
            return normalized
        default:
            return nil
        }
    }
}

enum WebYAMLExtractionRunnerError: LocalizedError {
    case bundledYAMLNotFound
    case invalidYAMLRoot
    case invalidSpecEncoding

    var errorDescription: String? {
        switch self {
        case .bundledYAMLNotFound:
            return "Bundled Web selector YAML file was not found."
        case .invalidYAMLRoot:
            return "Invalid YAML root. Expected a dictionary at top level."
        case .invalidSpecEncoding:
            return "Failed to encode Web extraction spec as JSON."
        }
    }
}
