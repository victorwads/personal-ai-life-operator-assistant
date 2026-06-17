import SwiftUI

@MainActor
struct WhatsAppCrawlingSettingsSectionProvider: SettingsSectionProvider {
    let crawlingSettings: WhatsAppCrawlingSettingsWrapper
    let webViewSettings: WhatsAppWebViewSettingsWrapper
    let nativeSettings: WhatsAppNativeSettingsWrapper

    func settingsSections() -> [SettingsSectionDefinition] {
        [
            SettingsSectionDefinition(
                scopeName: "whatsappCrawling",
                title: "WhatsApp Crawling/Polling",
                featureTitle: "WhatsApp"
            ) {
                AnyView(
                    WhatsAppCrawlingSettingsView(
                        crawlingSettings: crawlingSettings,
                        nativeSettings: nativeSettings
                    )
                )
            },
            SettingsSectionDefinition(
                scopeName: "whatsappWebView",
                title: "WhatsApp WebView",
                featureTitle: "WhatsApp"
            ) {
                AnyView(
                    WhatsAppWebViewSettingsView(wrapper: webViewSettings)
                )
            }
        ]
    }
}
