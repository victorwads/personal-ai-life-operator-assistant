import SwiftUI

struct CommandCenterScreenRegistry {
    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState,
        settingsSectionRegistry: SettingsSectionRegistry? = nil
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
            WhatsAppWebViewPlaceholderScreen()
        case .whatsappWebYAMLDebug:
            WhatsAppWebYAMLDebugPlaceholderScreen()
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
