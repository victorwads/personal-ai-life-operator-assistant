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

    func extractImages(from elements: [WebViewInteractiveElement]) async throws -> [WebViewResolvedImage] {
        guard !elements.isEmpty else { return [] }

        let extractedItems = try await WebViewElementInteractor(webView: webView).extractImages(elements)
        var resolvedImages: [WebViewResolvedImage] = []

        for extracted in extractedItems {
            do {
                if let base64 = extracted.base64,
                   let imageData = Data(base64Encoded: base64) {
                    resolvedImages.append(
                        WebViewResolvedImage(
                            pngData: imageData,
                            mimeType: extracted.mimeType,
                            width: extracted.width,
                            height: extracted.height,
                            source: extracted.source
                        )
                    )
                    continue
                }

                if let source = extracted.source,
                   let downloaded = try await loadImageFromHTTPSource(source),
                   let pngData = pngData(from: downloaded) {
                    resolvedImages.append(
                        WebViewResolvedImage(
                            pngData: pngData,
                            mimeType: extracted.mimeType ?? "image/png",
                            width: extracted.width,
                            height: extracted.height,
                            source: extracted.source
                        )
                    )
                }
            } catch {
                continue
            }
        }

        return resolvedImages
    }

    func extractImage(from element: WebViewInteractiveElement) async throws -> WebViewResolvedImage? {
        try await extractImages(from: [element]).first
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
