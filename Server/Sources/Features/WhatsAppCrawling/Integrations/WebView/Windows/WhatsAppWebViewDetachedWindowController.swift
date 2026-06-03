import AppKit
import WebKit

@MainActor
final class WhatsAppWebViewDetachedWindowController: NSWindowController, NSWindowDelegate {
    private weak var service: WebViewWhatsAppCrawlingService?
    private let webView: WKWebView

    init(service: WebViewWhatsAppCrawlingService, webView: WKWebView) {
        self.service = service
        self.webView = webView

        let contentController = WhatsAppWebViewDetachedContentViewController(webView: webView)
        let window = NSWindow(contentViewController: contentController)
        window.title = "WhatsApp Web"
        window.setContentSize(NSSize(width: 980, height: 740))
        window.styleMask.insert(.closable)
        window.styleMask.insert(.resizable)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        attach()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        attach()
    }

    func windowWillClose(_ notification: Notification) {
        service?.detachedWindowDidClose()
    }

    private func attach() {
        guard let contentController = contentViewController as? WhatsAppWebViewDetachedContentViewController else { return }
        contentController.attach(webView: webView)
    }
}

private final class WhatsAppWebViewDetachedContentViewController: NSViewController {
    private let containerView = NSView()
    private let initialWebView: WKWebView

    init(webView: WKWebView) {
        self.initialWebView = webView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        attach(webView: initialWebView)
    }

    func attach(webView: WKWebView) {
        guard webView.superview !== containerView else { return }

        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
}
