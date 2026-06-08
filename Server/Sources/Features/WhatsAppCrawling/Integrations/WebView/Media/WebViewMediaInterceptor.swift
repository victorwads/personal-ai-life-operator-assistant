import Foundation
import WebKit

@MainActor
final class WebViewMediaInterceptor {
    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
    }

    func cleanup(stop: Bool = false) async throws {
        _ = try await evaluate(script: "window.AssistantMCP.MediaInterceptor.cleanup(\(stop ? "true" : "false"));")
    }

    func consume(index: Int, type: String) async throws -> WebViewCapturedMedia? {
        let requestedIndex = max(0, index)
        return try await withCheckedThrowingContinuation { continuation in
            webView.callAsyncJavaScript(
                "return await window.AssistantMCP.MediaInterceptor.consume(index, type);",
                arguments: [
                    "index": requestedIndex,
                    "type": type
                ],
                in: nil,
                in: .page
            ) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: WebViewCapturedMedia.from(value))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
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
