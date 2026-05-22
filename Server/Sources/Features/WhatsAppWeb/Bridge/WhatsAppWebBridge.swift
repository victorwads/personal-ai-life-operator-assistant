import Foundation
import WebKit

enum WhatsAppWebBridgeError: LocalizedError {
    case unexpectedResponse
    case invalidSnapshotPayload
    case elementNotFound(String)
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "Unexpected JavaScript response from WhatsApp Web."
        case .invalidSnapshotPayload:
            return "Could not decode WhatsApp Web snapshot payload."
        case .elementNotFound(let details):
            return "Could not find the target element in WhatsApp Web. \(details)"
        case .unsupportedOperation(let details):
            return details
        }
    }
}

@MainActor
final class WhatsAppWebBridge {
    private let yamlExtractionRunner = WhatsAppWebYAMLExtractionRunner()

    func captureSnapshot(from webView: WKWebView) async throws -> WhatsAppWebPageSnapshot {
        let script = WhatsAppWebJavaScript.dumpDocumentScript
        let json = try await webView.evaluateJavaScriptString(script)

        guard let data = json.data(using: .utf8) else {
            throw WhatsAppWebBridgeError.invalidSnapshotPayload
        }

        struct RawSnapshotPayload: Codable {
            let url: String
            let title: String
            let documentReadyState: String
            let rawHTML: String
            let capturedAt: Date
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(RawSnapshotPayload.self, from: data)
            let rawHTML = payload.rawHTML
            return WhatsAppWebPageSnapshot(
                url: payload.url,
                title: payload.title,
                documentReadyState: payload.documentReadyState,
                rawHTML: rawHTML,
                isLoggedIn: true,
                hasQrCanvas: false,
                chatRowCount: 0,
                unreadBadgeCount: 0,
                selectedChatTitle: nil,
                composePlaceholder: nil,
                bodyTextSample: String(rawHTML.prefix(500)),
                flow: .unknown,
                capturedAt: payload.capturedAt
            )
        } catch {
            throw WhatsAppWebBridgeError.invalidSnapshotPayload
        }
    }

    func captureSelectedChat(from webView: WKWebView, limit: Int) async throws -> WhatsAppWebChatCapture {
        throw WhatsAppWebBridgeError.unsupportedOperation("captureSelectedChat has been removed from the legacy WebView bridge.")
    }

    struct ChatListItem: Codable, Equatable {
        let title: String
        let preview: String?
        let timeText: String?
        let unreadCount: Int?
        let path: String?
        let clickablePath: String?
    }

    func listChatTitles(from webView: WKWebView, limit: Int) async throws -> [ChatListItem] {
        let tree = try loadWebSelectorTree()
        let result = try await yamlExtractionRunner.run(yamlTree: tree, webView: webView)
        let items = chatListItems(from: result.tree)
        return Array(items.prefix(max(1, min(limit, 200))))
    }

    func openChatByTitle(from webView: WKWebView, title: String) async throws {
        throw WhatsAppWebBridgeError.unsupportedOperation("openChatByTitle has been removed from the legacy WebView bridge.")
    }

    private func loadWebSelectorTree() throws -> YAMLTree {
        guard let url = Bundle.main.url(forResource: "whatsapp_web_selectors", withExtension: "yaml"),
              let data = try? Data(contentsOf: url),
              let yaml = String(data: data, encoding: .utf8) else {
            throw WhatsAppWebBridgeError.unexpectedResponse
        }

        return try YAMLTree.parse(yaml: yaml)
    }

    private func loadWebActionShortcuts() throws -> WhatsAppWebActionShortcuts {
        return WhatsAppWebActionShortcuts.from(yamlTree: try loadWebSelectorTree())
    }

    private func chatListItems(from tree: AnySendable) -> [ChatListItem] {
        guard let web = objectValue(of: tree)?["web"],
              let chatListRoot = objectValue(of: web)?["chat_list_root"],
              let chatListExtract = objectValue(of: chatListRoot)?["extract"],
              let chatItemNode = objectValue(of: chatListExtract)?["chat_item"],
              let items = objectValue(of: chatItemNode)?["items"].flatMap(arrayValue(of:)),
              !items.isEmpty else {
            return []
        }

        return items.compactMap { item in
            guard let itemDict = objectValue(of: item),
                  let extract = objectValue(of: itemDict["extract"] ?? .null) else {
                return nil
            }

            let title = stringValue(at: ["chat_item_name", "value"], in: extract)
            let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let normalizedTitle, !normalizedTitle.isEmpty else {
                return nil
            }

            let preview = stringValue(at: ["chat_item_last_message", "value"], in: extract)
                ?? stringValue(at: ["chat_item_last_message"], in: extract)

            let timeText = stringValue(at: ["chat_item_last_message_time", "value"], in: extract)
                ?? stringValue(at: ["chat_item_last_message_time"], in: extract)

            let unreadCount = intValue(
                at: ["chat_item_unread_badge", "extract", "count", "value"],
                in: extract
            )
            ?? intValue(at: ["chat_item_unread_badge", "extract", "count"], in: extract)

            let path = stringValue(at: ["path"], in: itemDict)
            let clickablePath = stringValue(at: ["extract", "chat_clickable_to_open_chat", "path"], in: itemDict)

            return ChatListItem(
                title: normalizedTitle,
                preview: preview,
                timeText: timeText,
                unreadCount: unreadCount,
                path: path,
                clickablePath: clickablePath
            )
        }
    }

    func executeShortcut(from webView: WKWebView, modifiers: [String], key: String) async throws {
        let modifiersJSON = try AnySendableJSON.encodeToJSONString(.array(modifiers.map { .string($0) }))
        let script = WhatsAppWebJavaScript.makeShortcutScript(
            modifiersJSONLiteral: modifiersJSON,
            keyJSONLiteral: Self.javascriptStringLiteral(key)
        )
        _ = try await webView.evaluateJavaScriptString(script)
    }

    func archiveConversation(from webView: WKWebView) async throws {
        let shortcuts = try loadWebActionShortcuts()
        guard let shortcut = shortcuts.archiveConversation else {
            throw WhatsAppWebBridgeError.unexpectedResponse
        }
        try await executeShortcut(from: webView, modifiers: shortcut.modifiers, key: shortcut.key)
    }

    func openSearch(from webView: WKWebView) async throws {
        let shortcuts = try loadWebActionShortcuts()
        guard let shortcut = shortcuts.search else {
            throw WhatsAppWebBridgeError.unexpectedResponse
        }
        try await executeShortcut(from: webView, modifiers: shortcut.modifiers, key: shortcut.key)
    }

    private func objectValue(of any: AnySendable?) -> [String: AnySendable]? {
        guard let any, case .object(let dict) = any else { return nil }
        return dict
    }

    private func arrayValue(of any: AnySendable?) -> [AnySendable]? {
        guard let any, case .array(let values) = any else { return nil }
        return values
    }

    private func stringValue(at path: [String], in root: [String: AnySendable]) -> String? {
        guard let value = value(at: path, in: root) else { return nil }
        if case .string(let string) = value { return string }
        return nil
    }

    private func intValue(at path: [String], in root: [String: AnySendable]) -> Int? {
        guard let value = value(at: path, in: root) else { return nil }
        switch value {
        case .int(let int):
            return int
        case .double(let double):
            return Int(double)
        default:
            return nil
        }
    }

    private func value(at path: [String], in root: [String: AnySendable]) -> AnySendable? {
        var current: AnySendable? = .object(root)
        for key in path {
            guard let object = objectValue(of: current),
                  let next = object[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    func captureDebugDOM(from webView: WKWebView) async throws -> WhatsAppWebDebugDOMSnapshot {
        throw WhatsAppWebBridgeError.unsupportedOperation("captureDebugDOM has been removed from the legacy WebView bridge.")
    }

    struct MessageSendResult: Codable, Equatable {
        let result: String
        let composerFound: Bool
        let inserted: Bool
        let composerSelector: String?
        let currentText: String?
        let composeDraftText: String?
        let observedOutgoingText: String?
        let selectedChatTitle: String?
        let sendButtonFound: Bool?
        let sendButtonClicked: Bool?
        let activeElementTag: String?
    }

    func sendMessage(from webView: WKWebView, text: String) async throws -> MessageSendResult {
        throw WhatsAppWebBridgeError.unsupportedOperation("sendMessage has been removed from the legacy WebView bridge.")
    }

    private static func javascriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }
}

@MainActor
private extension WKWebView {
    func evaluateJavaScriptString(_ javaScript: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let stringResult = result as? String {
                    continuation.resume(returning: stringResult)
                } else {
                    continuation.resume(throwing: WhatsAppWebBridgeError.unexpectedResponse)
                }
            }
        }
    }
}
