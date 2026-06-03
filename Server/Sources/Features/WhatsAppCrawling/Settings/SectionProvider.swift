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
                title: "WhatsApp Crawling/Polling"
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
                title: "WhatsApp WebView"
            ) {
                AnyView(
                    WhatsAppWebViewSettingsView(wrapper: webViewSettings)
                )
            }
        ]
    }
}
