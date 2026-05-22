import SwiftUI

struct BridgeStatusBadge: View {
    let integrationMode: WhatsAppIntegrationMode
    let isPolling: Bool
    let isBusy: Bool
    let accessibilityTrusted: Bool
    let whatsappRunning: Bool
    let webSnapshot: WhatsAppWebPageSnapshot?
    let onRequestAccessibilityPermission: () -> Void
    let onStartPolling: () -> Void

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
        } else if isBusy {
            StatusBadge(
                title: "WhatsApp busy",
                state: .paused,
                help: "Integration is performing an action. Polling will resume automatically."
            )
        } else {
            Button(action: onStartPolling) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(StatusBadgeState.paused.indicatorColor)
                        .frame(width: 8, height: 8)

                    Text("WhatsApp paused")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(StatusBadgeState.paused.backgroundColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Polling is paused. Click to start polling and resume WhatsApp status updates.")
        }
    }
}

#Preview("OK / Open") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
        isPolling: true,
        isBusy: false,
        accessibilityTrusted: true,
        whatsappRunning: true,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {},
        onStartPolling: {}
    )
    .padding()
}

#Preview("OK / Closed") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
        isPolling: true,
        isBusy: false,
        accessibilityTrusted: true,
        whatsappRunning: false,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {},
        onStartPolling: {}
    )
    .padding()
}

#Preview("Needs Accessibility") {
    BridgeStatusBadge(
        integrationMode: .desktopAX,
        isPolling: false,
        isBusy: false,
        accessibilityTrusted: false,
        whatsappRunning: false,
        webSnapshot: nil,
        onRequestAccessibilityPermission: {},
        onStartPolling: {}
    )
    .padding()
}
