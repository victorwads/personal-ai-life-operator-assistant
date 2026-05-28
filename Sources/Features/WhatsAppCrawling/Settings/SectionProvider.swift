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
                title: "WhatsApp Crawling"
            ) {
                AnyView(
                    WhatsAppCrawlingSettingsView(
                        crawlingSettings: crawlingSettings,
                        webViewSettings: webViewSettings,
                        nativeSettings: nativeSettings
                    )
                )
            }
        ]
    }
}
