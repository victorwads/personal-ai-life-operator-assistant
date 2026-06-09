import SwiftUI

struct WhatsAppWebViewScreen: View {
    let feature: WhatsAppCrawlingFeature

    var body: some View {
        WhatsAppWebViewServiceContent(service: feature.webViewService)
    }
}

private struct WhatsAppWebViewServiceContent: View {
    @ObservedObject var service: WebViewWhatsAppCrawlingService
    @State private var phoneNumber = ""

    @ViewBuilder
    private func content(for service: WebViewWhatsAppCrawlingService) -> some View {
        switch service.state {
        case .stopped:
            serviceStateView(
                title: "WhatsApp WebView is stopped",
                description: "Start the WebView service to load WhatsApp Web in this profile workspace.",
                actionTitle: "Start",
                action: {
                    await service.start()
                }
            )
        case .starting:
            VStack(spacing: 12) {
                ProgressView()
                Text("Starting WhatsApp WebView...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .started:
            if service.presentationMode == .detached {
                serviceStateView(
                    title: "WebView is detached",
                    description: "WhatsApp Web is open in a separate window.",
                    actionTitle: nil,
                    action: nil
                )
            } else if let webView = service.webView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("WhatsApp Web")
                                .font(.headline)
                            Spacer()
                            Button {
                                service.detach()
                            } label: {
                                Image(systemName: "rectangle.on.rectangle")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .help("Open WebView in separate window")

                            Button("Stop") {
                                Task { @MainActor in
                                    await service.stop()
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        DSSettingsTextField(
                            title: "Test phone",
                            prompt: "5511983227673",
                            helperText: "Temporary test helper. Press Enter for JS URL change without reload, or use the buttons below.",
                            text: $phoneNumber
                        )
                        .onSubmit {
                            Task { @MainActor in
                                await service.navigateToPhoneUsingJavaScript(phoneNumber)
                            }
                        }

                        HStack(spacing: 8) {
                            Button("JS URL Change") {
                                Task { @MainActor in
                                    await service.navigateToPhoneUsingJavaScript(phoneNumber)
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Reload URL") {
                                Task { @MainActor in
                                    await service.navigateToPhoneUsingReload(phoneNumber)
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        if let message = service.navigationStatusMessage, !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()

                    WebViewContainerView(webView: webView)
                }
            } else {
                serviceStateView(
                    title: "WebView is running without a view",
                    description: "The runtime reports running, but no WKWebView is currently available.",
                    actionTitle: "Restart",
                    action: {
                        await service.stop()
                        await service.start()
                    }
                )
            }
        case .stopping:
            VStack(spacing: 12) {
                ProgressView()
                Text("Stopping WhatsApp WebView...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            serviceStateView(
                title: "WhatsApp WebView failed",
                description: message,
                actionTitle: "Start",
                action: {
                    await service.start()
                }
            )
        }
    }

    private func serviceStateView(
        title: String,
        description: String,
        actionTitle: String?,
        action: (() async -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(description)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle) {
                    Task { @MainActor in
                        await action()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var body: some View {
        Group { content(for: service) }
    }
}
