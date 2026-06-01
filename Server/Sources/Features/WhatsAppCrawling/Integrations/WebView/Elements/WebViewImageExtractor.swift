import AppKit
import Foundation
import WebKit

struct WebViewResolvedImage: Sendable {
    let pngData: Data
    let mimeType: String?
    let width: Double?
    let height: Double?
    let source: String?
}

@MainActor
final class WebViewImageExtractor {
    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
    }

    func extractImage(from element: WebViewInteractiveElement) async throws -> WebViewResolvedImage? {
        let extracted = try await WebViewElementInteractor(webView: webView).extractImage(element)
        guard let extracted else { return nil }

        if let base64 = extracted.base64 {
            guard let imageData = Data(base64Encoded: base64) else { return nil }
            return WebViewResolvedImage(
                pngData: imageData,
                mimeType: extracted.mimeType,
                width: extracted.width,
                height: extracted.height,
                source: extracted.source
            )
        }

        if let x = extracted.x, let y = extracted.y, let width = extracted.width, let height = extracted.height {
            let rect = CGRect(x: x, y: y, width: width, height: height)
            if let snapshot = try await takeSnapshot(of: webView, rect: rect),
               let pngData = pngData(from: snapshot) {
                return WebViewResolvedImage(
                    pngData: pngData,
                    mimeType: extracted.mimeType ?? "image/png",
                    width: extracted.width,
                    height: extracted.height,
                    source: extracted.source
                )
            }
        }

        if let source = extracted.source,
           let downloaded = try await loadImageFromHTTPSource(source),
           let pngData = pngData(from: downloaded) {
            return WebViewResolvedImage(
                pngData: pngData,
                mimeType: extracted.mimeType ?? "image/png",
                width: extracted.width,
                height: extracted.height,
                source: extracted.source
            )
        }

        return nil
    }

    private func takeSnapshot(of webView: WKWebView, rect: CGRect) async throws -> NSImage? {
        let sanitized = rect.standardized.integral
        guard sanitized.width > 0, sanitized.height > 0 else { return nil }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = sanitized

        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private func loadImageFromHTTPSource(_ source: String) async throws -> NSImage? {
        guard let url = URL(string: source) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return NSImage(data: data)
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
