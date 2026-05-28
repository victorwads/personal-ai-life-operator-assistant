import AppKit
import Foundation
import WebKit

@MainActor
final class WebViewWhatsAppCrawlingService: ObservableObject, WhatsAppCrawlingService {
    enum WebViewPresentationMode: Equatable {
        case embedded
        case detached
    }

    private let profileId: String
    private let settings: WhatsAppWebViewSettingsWrapper
    private var detachedWindowController: WhatsAppWebViewDetachedWindowController?

    @Published private(set) var state: WhatsAppCrawlingServiceState = .stopped
    @Published private(set) var presentationMode: WebViewPresentationMode = .embedded
    let activeIntegration: WhatsAppCrawlingActiveIntegration = .webView
    @Published private(set) var webView: WKWebView?

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
        guard state == .stopped || isFailed else { return }
        state = .starting

        do {
            await refreshUserAgentIfNeeded()
            let webView = try makeWebView()
            self.webView = webView

            let urlString = settings.url
            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }

            presentationMode = .embedded
            state = .started
        } catch {
            self.webView = nil
            presentationMode = .embedded
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard state == .started || state == .starting || isFailed else { return }
        state = .stopping
        closeDetachedWindow()

        webView?.stopLoading()
        webView = nil
        presentationMode = .embedded

        state = .stopped
    }

    func detach() {
        guard state == .started, let webView else { return }
        guard detachedWindowController == nil else {
            detachedWindowController?.showWindow(nil)
            detachedWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = WhatsAppWebViewDetachedWindowController(service: self, webView: webView)
        detachedWindowController = controller
        presentationMode = .detached
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reattach() {
        closeDetachedWindow()
        presentationMode = .embedded
    }

    func detachedWindowDidClose() {
        detachedWindowController = nil
        presentationMode = .embedded
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func makeWebView() throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = try makeWebsiteDataStore(identifier: settings.websiteDataStoreIdentifier)
        configuration.processPool = WKProcessPool()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: WebViewJavaScripts.assistantBridge,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

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

    private func refreshUserAgentIfNeeded() async {
        let needsInitialCapture = (settings.userAgent ?? "").isEmpty
        let needsAutoRefresh = settings.userAgentAutoRefreshEnabled && isRefreshExpired()

        guard needsInitialCapture || needsAutoRefresh else {
            return
        }

        do {
            let service = BrowserUserAgentCaptureService()
            let userAgent = try await service.captureUserAgent()
            settings.userAgent = userAgent
            settings.lastUserAgentRefreshDate = Date()
        } catch {
            print("TODO: User-Agent capture failed for WhatsApp WebView: \(error.localizedDescription)")
        }
    }

    private func isRefreshExpired(now: Date = Date()) -> Bool {
        guard let lastRefresh = settings.lastUserAgentRefreshDate else { return true }
        let intervalDays = settings.userAgentRefreshIntervalDays
        guard intervalDays > 0 else { return true }
        let intervalSeconds = TimeInterval(intervalDays * 86_400)
        return now.timeIntervalSince(lastRefresh) >= intervalSeconds
    }

    private func makeWebsiteDataStore(identifier: String) throws -> WKWebsiteDataStore {
        guard let uuid = UUID(uuidString: identifier) else {
            throw WebViewWhatsAppCrawlingServiceError.missingWebsiteDataStoreIdentifier(profileId: profileId)
        }

        return WKWebsiteDataStore(forIdentifier: uuid)
    }

    private func closeDetachedWindow() {
        guard let detachedWindowController else { return }
        detachedWindowController.window?.delegate = nil
        detachedWindowController.close()
        self.detachedWindowController = nil
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
