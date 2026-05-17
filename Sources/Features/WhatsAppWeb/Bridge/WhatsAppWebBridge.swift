import Foundation
import WebKit

enum WhatsAppWebBridgeError: LocalizedError {
    case unexpectedResponse
    case invalidSnapshotPayload

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "Unexpected JavaScript response from WhatsApp Web."
        case .invalidSnapshotPayload:
            return "Could not decode WhatsApp Web snapshot payload."
        }
    }
}

@MainActor
final class WhatsAppWebBridge {
    func captureSnapshot(from webView: WKWebView) async throws -> WhatsAppWebPageSnapshot {
        let script = Self.snapshotScript
        let json = try await webView.evaluateJavaScriptString(script)

        guard let data = json.data(using: .utf8) else {
            throw WhatsAppWebBridgeError.invalidSnapshotPayload
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WhatsAppWebPageSnapshot.self, from: data)
        } catch {
            throw WhatsAppWebBridgeError.invalidSnapshotPayload
        }
    }

    private static let snapshotScript = """
    (() => {
      const pickText = (value) => typeof value === 'string' ? value.trim() : '';
      const selectedChatCandidate = document.querySelector('[aria-selected="true"]');
      const selectedChatTitle =
        pickText(selectedChatCandidate?.getAttribute('title')) ||
        pickText(selectedChatCandidate?.querySelector('[title]')?.getAttribute('title')) ||
        null;
      const composeCandidate =
        document.querySelector('[contenteditable="true"][data-tab]') ||
        document.querySelector('[contenteditable="true"][role="textbox"]');
      const composePlaceholder =
        pickText(composeCandidate?.getAttribute('data-lexical-editor')) ? 'lexical-editor' :
        (pickText(composeCandidate?.getAttribute('aria-label')) || null);
      const unreadBadgeCount = document.querySelectorAll('[aria-label*="unread"], [data-testid*="icon-unread"], [data-testid="icon-unread-count"]').length;
      const chatRowCount = document.querySelectorAll('[role="listitem"]').length;
      const bodyTextSample = pickText(document.body?.innerText || '').slice(0, 500);
      const payload = {
        url: window.location.href,
        title: document.title,
        documentReadyState: document.readyState,
        isLoggedIn: !document.body?.innerText?.includes('Use WhatsApp on your computer'),
        hasQrCanvas: document.querySelectorAll('canvas').length > 0,
        chatRowCount,
        unreadBadgeCount,
        selectedChatTitle,
        composePlaceholder,
        bodyTextSample,
        capturedAt: new Date().toISOString()
      };
      return JSON.stringify(payload);
    })();
    """
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
