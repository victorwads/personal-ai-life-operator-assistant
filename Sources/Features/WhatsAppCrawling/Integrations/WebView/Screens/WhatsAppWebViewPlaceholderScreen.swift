import SwiftUI

struct WhatsAppWebViewPlaceholderScreen: View {
    var body: some View {
        CommandCenterPlaceholderScreen(
            title: "WebView",
            description: "The WhatsApp Web runtime view will appear here when the WebView integration is active or debug mode allows it."
        )
        // TODO: Display the same WKWebView instance owned by the active
        // ProfileRuntimeContainer's WebViewWhatsAppCrawlingService.
    }
}
