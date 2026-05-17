import SwiftUI

struct BridgeStatusBadge: View {
    let integrationMode: WhatsAppIntegrationMode
    let isPolling: Bool
    let accessibilityTrusted: Bool
    let whatsappRunning: Bool
    let webSnapshot: WhatsAppWebPageSnapshot?
    let onRequestAccessibilityPermission: () -> Void

    var body: some View {
        if isPolling {
            switch integrationMode {
            case .web:
                let isLoggedIn = webSnapshot?.isLoggedIn == true && webSnapshot?.flow != .loginQr
                StatusBadge(
                    title: isLoggedIn ? "WhatsApp Web" : "WhatsApp Closed",
                    state: isLoggedIn ? .online : .offline,
                    help: webSnapshot.map { "Web flow: \($0.flow.rawValue)" } ?? "WhatsApp Web snapshot not available yet."
                )

            case .desktopAX:
                if accessibilityTrusted {
                    StatusBadge(
                        title: whatsappRunning ? "WhatsApp Native" : "WhatsApp Closed",
                        state: whatsappRunning ? .online : .offline,
                        help: "Shows whether WhatsApp Desktop is currently running."
                    )
                } else {
                    Button {
                        onRequestAccessibilityPermission()
                    } label: {
                        StatusBadge(
                            title: "Accessibility Error",
                            state: .offline,
                            help: "Accessibility permission is required for WhatsApp Native. Click to request it."
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            StatusBadge(
                title: "WhatsApp paused",
                state: .paused,
                help: "Polling is paused. Start polling to resume WhatsApp status updates."
            )
        }
    }
}

#Preview("OK / Open") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
        isPolling: true,
        accessibilityTrusted: true,
        whatsappRunning: true,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {}
    )
    .padding()
}

#Preview("OK / Closed") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
        isPolling: true,
        accessibilityTrusted: true,
        whatsappRunning: false,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {}
    )
    .padding()
}

#Preview("Needs Accessibility") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
        isPolling: false,
        accessibilityTrusted: false,
        whatsappRunning: false,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {}
    )
    .padding()
}
