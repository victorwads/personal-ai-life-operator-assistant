import AppKit
import SwiftUI
import WebKit

@MainActor
final class WhatsAppWebDetachedWindowController: NSWindowController, NSWindowDelegate {
    private weak var appModel: AppModel?
    private let accountId: UUID

    init(appModel: AppModel, account: WhatsAppWebAccount, webView: WKWebView) {
        self.appModel = appModel
        self.accountId = account.id

        let rootView = WhatsAppWebDetachedWindowView(
            account: account,
            webView: webView
        )
        .environmentObject(appModel)
        .frame(minWidth: 980, minHeight: 680)

        let hosting = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Assistant MCP - \(account.name)"
        window.contentView = hosting
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }

        appModel?.handleDetachedWhatsAppWebWindowClosed(accountId: accountId)
    }
}

private struct WhatsAppWebDetachedWindowView: View {
    @EnvironmentObject private var appModel: AppModel

    let account: WhatsAppWebAccount
    let webView: WKWebView

    private var isIntegrationActive: Bool {
        appModel.isPolling || appModel.isSendingMessage
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                    Text("Detached WhatsApp Web")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appModel.closeDetachedWhatsAppWebWindow(accountId: account.id)
                } label: {
                    Label("Return to sidebar", systemImage: "sidebar.left")
                }
            }
            .padding(12)

            Divider()

            WhatsAppWebView(
                webView: webView,
                mode: isIntegrationActive ? .bridgePolling : .interactive,
                pollingPageZoom: appModel.whatsAppWebSettings.pageZoom
            )
            .id(account.id)
            .allowsHitTesting(!isIntegrationActive)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
