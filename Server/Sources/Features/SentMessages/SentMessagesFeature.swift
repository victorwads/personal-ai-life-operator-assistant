import Foundation

@MainActor
final class SentMessagesFeature: FeatureRuntime {
    override class var id: String { "sentMessages" }

    let repository: FirestoreSentMessageRepository
    let settings: SentMessagesSettingsWrapper

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("SentMessagesFeature requires a persisted profile scope.")
        }

        self.repository = FirestoreSentMessageRepository(scope: scope)
        self.settings = SentMessagesSettingsWrapper(
            settings: context.settings.store
        )

        super.init(context: context)

        context.settings.sectionRegistry.register(
            SentMessagesSettingsSectionProvider(wrapper: settings)
        )

        context.mcp.toolRegistry.register([
            GetAssistantNameTool(settings: settings),
            SendMessageTool(
                repository: repository,
                chatRepositoryProvider: {
                    context.feature(ChatsFeature.self).repository
                },
                settings: settings,
                senderProvider: {
                    context.feature(WhatsAppCrawlingFeature.self).messageSender
                }
            )
        ])
    }

    func listByIssueId(_ issueId: String) async throws -> [SentMessage] {
        try await repository.listByIssueId(issueId)
    }
}
