import Foundation

@MainActor
final class ChatsFeature: FeatureRuntime {
    override class var id: String { "chats" }

    let repository: FirestoreChatRepository
    let crawlingSettings: WhatsAppCrawlingSettingsWrapper

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("ChatsFeature requires a persisted profile scope.")
        }

        let repository = FirestoreChatRepository(scope: scope)
        let crawlingSettings = WhatsAppCrawlingSettingsWrapper(settings: context.settings.store)
        self.repository = repository
        self.crawlingSettings = crawlingSettings
        super.init(context: context)

        context.mcp.toolRegistry.register([
            ListChatsTool(
                repository: repository,
                permissionModeProvider: { crawlingSettings.chatPermissionMode }
            ),
            ListChatsBySearchTool(),
            ListUnhandledChatsTool(
                repository: repository,
                permissionModeProvider: { crawlingSettings.chatPermissionMode }
            ),
            ListChatMessagesTool(
                repository: repository,
                permissionModeProvider: { crawlingSettings.chatPermissionMode }
            )
        ])
    }
}
