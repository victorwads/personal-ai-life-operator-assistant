import SwiftUI

struct WhatsAppCrawlingSettingsView: View {
    let crawlingSettings: WhatsAppCrawlingSettingsWrapper
    let webViewSettings: WhatsAppWebViewSettingsWrapper
    let nativeSettings: WhatsAppNativeSettingsWrapper

    @State private var activeIntegration: WhatsAppCrawlingActiveIntegration = .webView
    @State private var pollingIntervalSeconds = 5
    @State private var accessPolicy: WhatsAppCrawlingAccessPolicy = .allowAllExceptDenyList
    @State private var autoStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            Picker("Access Policy", selection: accessPolicyBinding) {
                ForEach(WhatsAppCrawlingAccessPolicy.allCases) { policy in
                    Text(policy.title).tag(policy)
                }
            }

            Toggle("Auto Start", isOn: autoStartBinding)

            Divider()

            switch activeIntegration {
            case .webView:
                WhatsAppWebViewSettingsView(wrapper: webViewSettings)
            case .nativeAccessibility:
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

    private var accessPolicyBinding: Binding<WhatsAppCrawlingAccessPolicy> {
        Binding {
            accessPolicy
        } set: { value in
            accessPolicy = value
            crawlingSettings.accessPolicy = value
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
        accessPolicy = crawlingSettings.accessPolicy
        autoStart = crawlingSettings.autoStart
    }
}
