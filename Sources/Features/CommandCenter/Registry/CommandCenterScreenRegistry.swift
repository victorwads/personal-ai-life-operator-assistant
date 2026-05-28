import SwiftUI

struct CommandCenterScreenRegistry {
    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState,
        settingsSectionRegistry: SettingsSectionRegistry? = nil,
        whatsAppWebViewService: WebViewWhatsAppCrawlingService? = nil
    ) -> some View {
        switch route {
        case .myProfile:
            MyProfileScreen(profile: profile, runtimeState: runtimeState, windowState: windowState)
        case .issues:
            IssuesPlaceholderScreen()
        case .memories:
            MemoriesPlaceholderScreen()
        case .sensitiveData:
            SensitiveDataPlaceholderScreen()
        case .clientVoice:
            ClientVoicePlaceholderScreen()
        case .chats:
            ChatsPlaceholderScreen()
        case .whatsappWebView:
            if let whatsAppWebViewService {
                WhatsAppWebViewScreen(service: whatsAppWebViewService)
            } else {
                CommandCenterPlaceholderScreen(
                    title: "WebView runtime unavailable",
                    description: "Open the profile window from a persisted profile so the runtime container can provide the WebView service."
                )
            }
        case .whatsappWebYAMLDebug:
            if let whatsAppWebViewService {
                WhatsAppWebYAMLDebugScreen(service: whatsAppWebViewService)
            } else {
                CommandCenterPlaceholderScreen(
                    title: "WebView runtime unavailable",
                    description: "Open the profile window from a persisted profile so the runtime container can provide the WebView service."
                )
            }
        case .whatsappNativeYAMLDebug:
            WhatsAppNativeYAMLDebugPlaceholderScreen()
        case .whatsappLogs:
            WhatsAppLogsPlaceholderScreen()
        case .tools:
            MCPToolsPlaceholderScreen()
        case .aiConnection:
            AIConnectionPlaceholderScreen()
        case .serverLogs:
            ServerLogsPlaceholderScreen()
        case .settings:
            SettingsScreen(settingsSectionRegistry: settingsSectionRegistry)
        }
    }
}
