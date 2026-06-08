import Foundation
import WebKit

struct WebViewExtractedImage: Equatable {
    let base64: String?
    let mimeType: String?
    let width: Double?
    let height: Double?
    let source: String?

    static func from(_ value: Any?) -> WebViewExtractedImage? {
        guard let object = dictionary(from: value) else { return nil }
        let base64 = nonEmptyString(object["base64"])

        let mimeType = object["mimeType"] as? String
        let width = numberValue(from: object["width"])
        let height = numberValue(from: object["height"])
        let source = object["source"] as? String

        let hasBase64 = base64 != nil
        let hasSource = source != nil
        guard hasBase64 || hasSource else { return nil }

        return WebViewExtractedImage(
            base64: base64,
            mimeType: mimeType,
            width: width,
            height: height,
            source: source
        )
    }

    private static func dictionary(from value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                guard let key = key as? String else { continue }
                result[key] = value
            }
            return result
        }
        return nil
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }

    private static func numberValue(from value: Any?) -> Double? {
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        return nil
    }
}

@MainActor
final class WebViewElementInteractor {
    private struct InteractionCommand: Encodable {
        let id: String
        let action: String
        let payload: [String: String]?
    }

    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
    }

    func click(_ element: WebViewInteractiveElement) async throws -> Bool {
        try await interact(with: element.id, action: "click", payload: nil)
    }

    func focus(_ element: WebViewInteractiveElement) async throws -> Bool {
        try await interact(with: element.id, action: "focus", payload: nil)
    }

    func type(_ text: String, into element: WebViewInteractiveElement) async throws -> Bool {
        try await interact(with: element.id, action: "type", payload: ["text": text])
    }

    func pressEnter(_ element: WebViewInteractiveElement) async throws -> Bool {
        try await interact(with: element.id, action: "pressEnter", payload: nil)
    }

    func executeShortcut(_ shortcut: ShortcutConfig) async throws -> Bool {
        let keys = shortcut.modifiers + [shortcut.key]
        guard !keys.isEmpty else { return false }

        let command = ShortcutCommand(keys: keys)
        let commandData = try JSONEncoder().encode(command)
        guard let commandJSON = String(data: commandData, encoding: .utf8) else {
            return false
        }

        let script = """
        window.AssistantMCP.executeShortcut(\(commandJSON));
        """

        let value = try await evaluate(script: script)
        return value as? Bool ?? false
    }

    func pressEscape() async throws -> Bool {
        try await executeShortcut(ShortcutConfig(modifiers: [], key: "Escape"))
    }

    func extractImage(_ element: WebViewInteractiveElement) async throws -> WebViewExtractedImage? {
        return try await extractImages([element]).first
    }

    func extractImages(_ elements: [WebViewInteractiveElement]) async throws -> [WebViewExtractedImage] {
        let ids = elements.map(\.id).filter { !$0.isEmpty }
        guard !ids.isEmpty else { return [] }

        let value = try await interactRaw(with: ids, action: "extractImages", payload: nil)
        let array = value as? [Any] ?? []
        return array.compactMap { WebViewExtractedImage.from($0) }
    }

    private func interact(with id: String, action: String, payload: [String: String]?) async throws -> Bool {
        let value = try await interactRaw(with: id, action: action, payload: payload)
        return value as? Bool ?? false
    }

    private func interactRaw(with id: String, action: String, payload: [String: String]?) async throws -> Any? {
        let command = InteractionCommand(id: id, action: action, payload: payload)
        let commandData = try JSONEncoder().encode(command)
        guard let commandJSON = String(data: commandData, encoding: .utf8) else {
            return nil
        }

        let script = """
        window.AssistantMCP.interactWithElementCommand(\(commandJSON));
        """

        return try await evaluate(script: script)
    }

    private struct MultipleInteractionCommand: Encodable {
        let ids: [String]
        let action: String
        let payload: [String: String]?
    }

    private func interactRaw(with ids: [String], action: String, payload: [String: String]?) async throws -> Any? {
        let command = MultipleInteractionCommand(ids: ids, action: action, payload: payload)
        let commandData = try JSONEncoder().encode(command)
        guard let commandJSON = String(data: commandData, encoding: .utf8) else {
            return nil
        }

        let script = """
        window.AssistantMCP.interactWithElementsCommand(\(commandJSON));
        """

        return try await evaluate(script: script)
    }

    private struct ShortcutCommand: Encodable {
        let keys: [String]
    }

    private func evaluate(script: String) async throws -> Any? {
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
}
