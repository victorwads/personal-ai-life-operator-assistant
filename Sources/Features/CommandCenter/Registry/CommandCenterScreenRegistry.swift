import SwiftUI

@MainActor
struct CommandCenterScreenRegistry {
    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState,
        appFeatures: AppFeatures
    ) -> some View {
        switch route {
        case .myProfile:
            MyProfileScreen(profile: profile, runtimeState: runtimeState, windowState: windowState)
        case .issues:
            IssuesScreen(feature: appFeatures.feature(IssuesFeature.self))
        case .memories:
            MemoriesScreen(feature: appFeatures.feature(MemoriesFeature.self))
        case .sensitiveData:
            SensitiveDataScreen()
        case .clientVoice:
            ClientVoiceScreen()
        case .sentMessages:
            SentMessagesScreen(feature: appFeatures.feature(SentMessagesFeature.self))
        case .chats:
            ChatsScreen(feature: appFeatures.feature(ChatsFeature.self))
        case .whatsappWebView:
            WhatsAppWebViewScreen(feature: appFeatures.feature(WhatsAppCrawlingFeature.self))
        case .whatsappWebYAMLDebug:
            WhatsAppWebYAMLDebugScreen(feature: appFeatures.feature(WhatsAppCrawlingFeature.self))
        case .whatsappNativeYAMLDebug:
            WhatsAppNativeYAMLDebugScreen()
        case .whatsappLogs:
            WhatsAppLogsScreen(feature: appFeatures.feature(WhatsAppCrawlingFeature.self))
        case .tools:
            MCPToolsScreen(mcpServersFeature: appFeatures.feature(MCPServersFeature.self))
        case .aiConnection:
            AIConnectionScreen()
        case .serverLogs:
            ServerLogsScreen()
        case .settings:
            SettingsScreen(
                settingsSectionRegistry: appFeatures.feature(SettingsFeature.self).settingsSectionRegistry
            )
        }
    }
}
