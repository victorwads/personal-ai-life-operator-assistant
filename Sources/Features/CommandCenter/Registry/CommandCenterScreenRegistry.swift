import SwiftUI

@MainActor
struct CommandCenterScreenRegistry {
    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState,
        settingsFeature: SettingsFeature,
        memoriesFeature: MemoriesFeature,
        whatsAppCrawlingFeature: WhatsAppCrawlingFeature
    ) -> some View {
        switch route {
        case .myProfile:
            MyProfileScreen(profile: profile, runtimeState: runtimeState, windowState: windowState)
        case .issues:
            IssuesScreen()
        case .memories:
            MemoriesScreen(feature: memoriesFeature)
        case .sensitiveData:
            SensitiveDataScreen()
        case .clientVoice:
            ClientVoiceScreen()
        case .chats:
            ChatsScreen()
        case .whatsappWebView:
            WhatsAppWebViewScreen(feature: whatsAppCrawlingFeature)
        case .whatsappWebYAMLDebug:
            WhatsAppWebYAMLDebugScreen(feature: whatsAppCrawlingFeature)
        case .whatsappNativeYAMLDebug:
            WhatsAppNativeYAMLDebugScreen()
        case .whatsappLogs:
            WhatsAppLogsScreen(feature: whatsAppCrawlingFeature)
        case .tools:
            MCPToolsScreen()
        case .aiConnection:
            AIConnectionScreen()
        case .serverLogs:
            ServerLogsScreen()
        case .settings:
            SettingsScreen(settingsSectionRegistry: settingsFeature.settingsSectionRegistry)
        }
    }
}
