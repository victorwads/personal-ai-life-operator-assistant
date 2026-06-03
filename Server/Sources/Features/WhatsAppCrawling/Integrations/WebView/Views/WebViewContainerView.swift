import SwiftUI
import WebKit

struct WebViewContainerView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard webView.superview !== nsView else { return }

        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        nsView.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: nsView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor)
        ])
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        nsView.subviews.forEach { $0.removeFromSuperview() }
    }
}
