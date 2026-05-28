import Foundation
import WebKit

@MainActor
final class WebViewWhatsAppCrawlingService: WhatsAppCrawlingService {
    private let profileId: String
    private let settings: WhatsAppWebViewSettingsWrapper

    private(set) var state: WhatsAppCrawlingServiceState = .stopped
    let activeIntegration: WhatsAppCrawlingActiveIntegration = .webView
    private(set) var webView: WKWebView?

    var integration: (any WhatsAppCrawlingIntegration)? {
        // TODO: Expose WebViewWhatsAppIntegration once JavaScriptExecutor,
        // DOMExtractor and ShortcutExecutor are backed by this WKWebView.
        nil
    }

    init(profileId: String, settings: WhatsAppWebViewSettingsWrapper) {
        self.profileId = profileId
        self.settings = settings
    }

    func start() async {
        guard state == .stopped else { return }
        state = .starting

        do {
            let webView = try makeWebView()
            self.webView = webView

            let urlString = settings.url
            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }

            // TODO: Later, CommandCenter WebView route should show this same WKWebView instance.
            // TODO: Later, a detached WebView window can temporarily host this WKWebView.
            // TODO: Later, closing the detached window should return the WebView to the CommandCenter route.
            // TODO: Later, JavaScript injection and YAML extraction will run against this WKWebView.
            state = .started
        } catch {
            self.webView = nil
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard state == .started || state == .starting || isFailed else { return }
        state = .stopping

        webView?.stopLoading()
        webView = nil

        state = .stopped
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func makeWebView() throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = try makeWebsiteDataStore(identifier: settings.websiteDataStoreIdentifier)
        configuration.processPool = WKProcessPool()

        let viewportWidth = settings.viewportWidth
        let viewportHeight = settings.viewportHeight
        let frame = CGRect(
            x: 0,
            y: 0,
            width: max(1, viewportWidth),
            height: max(1, viewportHeight)
        )
        let webView = WKWebView(frame: frame, configuration: configuration)

        let userAgent = settings.userAgent
        if let userAgent, !userAgent.isEmpty {
            webView.customUserAgent = userAgent
        }

        webView.pageZoom = settings.zoom

        if #available(macOS 13.3, *) {
            webView.isInspectable = settings.enableWebInspector
        }

        return webView
    }

    private func makeWebsiteDataStore(identifier: String) throws -> WKWebsiteDataStore {
        guard let uuid = UUID(uuidString: identifier) else {
            throw WebViewWhatsAppCrawlingServiceError.missingWebsiteDataStoreIdentifier(profileId: profileId)
        }

        return WKWebsiteDataStore(forIdentifier: uuid)
    }
}

private enum WebViewWhatsAppCrawlingServiceError: LocalizedError {
    case missingWebsiteDataStoreIdentifier(profileId: String)

    var errorDescription: String? {
        switch self {
        case .missingWebsiteDataStoreIdentifier(let profileId):
            return "Missing WhatsApp WebView data store identifier for profile \(profileId)."
        }
    }
}
