import SwiftUI

struct WhatsAppCrawlingSettingsView: View {
    let crawlingSettings: WhatsAppCrawlingSettingsWrapper
    let nativeSettings: WhatsAppNativeSettingsWrapper

    @State private var activeIntegration: WhatsAppCrawlingActiveIntegration = .webView
    @State private var pollingIntervalSeconds = 5
    @State private var chatPermissionMode: ChatPermissionMode = .allowAllExceptDenied
    @State private var autoStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto Start Crawling/Polling", isOn: autoStartBinding)

            Picker("Active Integration", selection: activeIntegrationBinding) {
                ForEach(WhatsAppCrawlingActiveIntegration.allCases) { integration in
                    Text(integration.title).tag(integration)
                }
            }

            Stepper(
                "Polling Interval: \(pollingIntervalSeconds)s",
                value: pollingIntervalBinding,
                in: 1...300
            )

            Picker("Chat Permission Mode", selection: chatPermissionModeBinding) {
                ForEach(ChatPermissionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if activeIntegration == .nativeAccessibility {
                Divider()
                WhatsAppNativeSettingsView(wrapper: nativeSettings)
            }
        }
        .task {
            load()
        }
    }

    private var activeIntegrationBinding: Binding<WhatsAppCrawlingActiveIntegration> {
        Binding {
            activeIntegration
        } set: { value in
            activeIntegration = value
            crawlingSettings.activeIntegration = value
        }
    }

    private var pollingIntervalBinding: Binding<Int> {
        Binding {
            pollingIntervalSeconds
        } set: { value in
            pollingIntervalSeconds = value
            crawlingSettings.pollingIntervalSeconds = value
        }
    }

    private var chatPermissionModeBinding: Binding<ChatPermissionMode> {
        Binding {
            chatPermissionMode
        } set: { value in
            chatPermissionMode = value
            crawlingSettings.chatPermissionMode = value
        }
    }

    private var autoStartBinding: Binding<Bool> {
        Binding {
            autoStart
        } set: { value in
            autoStart = value
            crawlingSettings.autoStart = value
        }
    }

    private func load() {
        activeIntegration = crawlingSettings.activeIntegration
        pollingIntervalSeconds = crawlingSettings.pollingIntervalSeconds
        chatPermissionMode = crawlingSettings.chatPermissionMode
        autoStart = crawlingSettings.autoStart
    }
}
