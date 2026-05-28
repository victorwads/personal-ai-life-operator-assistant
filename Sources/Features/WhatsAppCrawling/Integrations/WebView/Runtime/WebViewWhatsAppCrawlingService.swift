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
    private var navigationDelegateProxy: NavigationDelegateProxy?

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
            attachNavigationDelegate(to: webView)

            let urlString = settings.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !urlString.isEmpty,
                let url = URL(string: urlString),
                let scheme = url.scheme?.lowercased(),
                scheme == "http" || scheme == "https"
            else {
                throw WebViewWhatsAppCrawlingServiceError.invalidURL(urlString)
            }

            logNavigationEvent("Loading URL: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
            startInitialWarmup(webView)

            presentationMode = .embedded
            state = .started
        } catch {
            self.webView = nil
            navigationDelegateProxy = nil
            presentationMode = .embedded
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard state == .started || state == .starting || isFailed else { return }
        state = .stopping
        closeDetachedWindow()

        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        navigationDelegateProxy = nil
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
        logNavigationEvent("Creating WKWebView with viewport \(Int(frame.width))x\(Int(frame.height))")
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

    private func attachNavigationDelegate(to webView: WKWebView) {
        let proxy = NavigationDelegateProxy(service: self)
        navigationDelegateProxy = proxy
        webView.navigationDelegate = proxy
    }

    private func startInitialWarmup(_ webView: WKWebView) {
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            await self.runInitialWarmup(on: webView)
        }
    }

    private func runInitialWarmup(on webView: WKWebView) async {
        for attempt in 1...5 {
            guard self.webView === webView else { return }

            do {
                let readyStateResult = try await evaluateJavaScript("document.readyState", in: webView)
                let readyState = (readyStateResult as? String) ?? String(describing: readyStateResult ?? "nil")
                logNavigationEvent("warmup[\(attempt)] readyState=\(readyState)")
            } catch {
                logNavigationEvent("warmup[\(attempt)] readyState failed: \(error.localizedDescription)")
            }

            do {
                let snapshot = try await takeSnapshot(of: webView)
                let status = snapshot == nil ? "nil" : "ok"
                logNavigationEvent("warmup[\(attempt)] snapshot=\(status)")
            } catch {
                logNavigationEvent("warmup[\(attempt)] snapshot failed: \(error.localizedDescription)")
            }

            if webView.isLoading == false { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    private func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any? {
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

    private func takeSnapshot(of webView: WKWebView) async throws -> NSImage? {
        try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    fileprivate func handleNavigationFailed(_ error: Error) {
        // Keep service alive for UI/debug, but surface failure clearly.
        state = .failed(error.localizedDescription)
    }

    fileprivate func logNavigationEvent(_ message: String) {
        print("WebViewWhatsAppCrawlingService[\(profileId)]: \(message)")
    }
}

private enum WebViewWhatsAppCrawlingServiceError: LocalizedError {
    case missingWebsiteDataStoreIdentifier(profileId: String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingWebsiteDataStoreIdentifier(let profileId):
            return "Missing WhatsApp WebView data store identifier for profile \(profileId)."
        case .invalidURL(let value):
            return "Invalid WhatsApp WebView URL: \(value)"
        }
    }
}

private final class NavigationDelegateProxy: NSObject, WKNavigationDelegate {
    private weak var service: WebViewWhatsAppCrawlingService?

    init(service: WebViewWhatsAppCrawlingService) {
        self.service = service
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        service?.logNavigationEvent("didStartProvisionalNavigation")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        service?.logNavigationEvent("didCommitNavigation")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        service?.logNavigationEvent("didFinishNavigation")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        service?.logNavigationEvent("didFailNavigation: \(error.localizedDescription)")
        service?.handleNavigationFailed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        service?.logNavigationEvent("didFailProvisionalNavigation: \(error.localizedDescription)")
        service?.handleNavigationFailed(error)
    }
}
