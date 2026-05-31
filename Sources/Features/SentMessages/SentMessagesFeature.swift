import Foundation

@MainActor
final class SentMessagesFeature: FeatureRuntime {
    override class var id: String { "sentMessages" }

    let repository: FirestoreSentMessageRepository
    private(set) var settings: SentMessagesSettingsWrapper

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("SentMessagesFeature requires a persisted profile scope.")
        }

        let settings = SentMessagesSettingsWrapper(settings: context.settings.store)
        self.repository = FirestoreSentMessageRepository(scope: scope)
        self.settings = settings
        super.init(context: context)

        context.settings.sectionRegistry.register(
            SentMessagesSettingsSectionProvider(wrapper: settings)
        )

        context.mcp.toolRegistry.register([
            GetAssistantNameTool(settings: settings),
            SendMessageTool(
                repository: repository,
                settings: settings,
                senderProvider: {
                    context.feature(WhatsAppCrawlingFeature.self).messageSender
                }
            )
        ])
    }
}
