import SwiftUI

struct BridgeStatusBadge: View {
    let integrationMode: WhatsAppIntegrationMode
    let accessibilityTrusted: Bool
    let whatsappRunning: Bool
    let webSnapshot: WhatsAppWebPageSnapshot?
    let onRequestAccessibilityPermission: () -> Void

    var body: some View {
        switch integrationMode {
        case .web:
            let isLoggedIn = webSnapshot?.isLoggedIn == true && webSnapshot?.flow != .loginQr
            StatusBadge(
                title: isLoggedIn ? "WhatsApp Web" : "WhatsApp Closed",
                isOnline: isLoggedIn,
                help: webSnapshot.map { "Web flow: \($0.flow.rawValue)" } ?? "WhatsApp Web snapshot not available yet."
            )

        case .desktopAX:
            if accessibilityTrusted {
                StatusBadge(
                    title: whatsappRunning ? "WhatsApp Native" : "WhatsApp Closed",
                    isOnline: whatsappRunning,
                    help: "Shows whether WhatsApp Desktop is currently running."
                )
            } else {
                Button {
                    onRequestAccessibilityPermission()
                } label: {
                    StatusBadge(
                        title: "Accessibility Error",
                        isOnline: false,
                        help: "Accessibility permission is required for WhatsApp Native. Click to request it."
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("OK / Open") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
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
        accessibilityTrusted: false,
        whatsappRunning: false,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {}
    )
    .padding()
}
