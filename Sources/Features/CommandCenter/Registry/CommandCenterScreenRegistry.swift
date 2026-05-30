import SwiftUI

@MainActor
struct CommandCenterScreenRegistry {
    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState,
        container: ProfileRuntimeContainer
    ) -> some View {
        switch route {
        case .myProfile:
            MyProfileScreen(profile: profile, runtimeState: runtimeState, windowState: windowState)
        case .issues:
            IssuesScreen(feature: container.feature(IssuesFeature.self))
        case .memories:
            MemoriesScreen(feature: container.feature(MemoriesFeature.self))
        case .sensitiveData:
            SensitiveDataScreen()
        case .clientVoice:
            ClientVoiceScreen()
        case .chats:
            ChatsScreen()
        case .whatsappWebView:
            WhatsAppWebViewScreen(feature: container.feature(WhatsAppCrawlingFeature.self))
        case .whatsappWebYAMLDebug:
            WhatsAppWebYAMLDebugScreen(feature: container.feature(WhatsAppCrawlingFeature.self))
        case .whatsappNativeYAMLDebug:
            WhatsAppNativeYAMLDebugScreen()
        case .whatsappLogs:
            WhatsAppLogsScreen(feature: container.feature(WhatsAppCrawlingFeature.self))
        case .tools:
            MCPToolsScreen()
        case .aiConnection:
            AIConnectionScreen()
        case .serverLogs:
            ServerLogsScreen()
        case .settings:
            SettingsScreen(
                settingsSectionRegistry: container.feature(SettingsFeature.self).settingsSectionRegistry
            )
        }
    }
}
