import SwiftUI

@MainActor
struct CommandCenterScreenRegistry {
    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState,
        appFeatures: AppFeatures,
        onOpenIssueDetail: @escaping (String) -> Void
    ) -> some View {
        switch route {
        case .myProfile:
            MyProfileScreen(profile: profile, runtimeState: runtimeState, windowState: windowState)
        case .issues:
            IssuesScreen(
                feature: appFeatures.feature(IssuesFeature.self),
                onOpenIssueDetail: onOpenIssueDetail
            )
        case .chats:
            ChatsScreen(feature: appFeatures.feature(ChatsFeature.self))
        case .memories:
            MemoriesScreen(feature: appFeatures.feature(MemoriesFeature.self))
        case .sensitiveData:
            SensitiveDataScreen(feature: appFeatures.feature(SensitiveDataFeature.self))
        case .clientVoice:
            ClientVoiceScreen(feature: appFeatures.feature(ClientVoiceFeature.self))
        case .sentMessages:
            SentMessagesScreen(feature: appFeatures.feature(SentMessagesFeature.self))
        case .email:
            EmailIntegrationScreen()
        case .calendar:
            CalendarIntegrationScreen()
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
            AIConnectionScreen(feature: appFeatures.feature(AIConnectionFeature.self))
        case .aiResourceUsage:
            AIResourceUsageView(repository: appFeatures.feature(AIConnectionFeature.self).resourceUsageRepository)
        case .serverLogs:
            ServerLogsScreen(feature: appFeatures.feature(ServerLogsFeature.self))
        case .settings:
            SettingsScreen(
                settingsSectionRegistry: appFeatures.feature(SettingsFeature.self).settingsSectionRegistry
            )
        }
    }
}
