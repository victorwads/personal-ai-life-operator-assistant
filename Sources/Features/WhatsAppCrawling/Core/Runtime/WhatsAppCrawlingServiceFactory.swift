import Foundation

@MainActor
struct WhatsAppCrawlingServiceFactory {
    let crawlingSettings: WhatsAppCrawlingSettingsWrapper
    let webViewSettings: WhatsAppWebViewSettingsWrapper
    let nativeSettings: WhatsAppNativeSettingsWrapper
    let profileId: String

    func makeService() async throws -> any WhatsAppCrawlingService {
        let activeIntegration = crawlingSettings.activeIntegration

        switch activeIntegration {
        case .webView:
            return WebViewWhatsAppCrawlingService(
                profileId: profileId,
                settings: webViewSettings
            )
        case .nativeAccessibility:
            return NativeWhatsAppCrawlingService(settings: nativeSettings)
        }
    }
}
