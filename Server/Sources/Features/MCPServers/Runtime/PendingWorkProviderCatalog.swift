import Foundation

@MainActor
enum PendingWorkProviderCatalog {
    static func makeProviders(context: FeatureContext) -> [any PendingWorkProvider] {
        guard let scope = context.profileContext.scope else {
            return []
        }

        let crawlingSettings = WhatsAppCrawlingSettingsWrapper(settings: context.settings.store)
        let chatRepository = FirestoreChatRepository(scope: scope)
        let clientInteractionRepository = FirestoreClientInteractionRequestRepository(scope: scope)

        return [
            ChatsPendingWorkProvider(
                repository: chatRepository,
                permissionModeProvider: { crawlingSettings.chatPermissionMode }
            ),
            WaitingAgentPendingWorkProvider(
                repository: clientInteractionRepository,
                issueTitleProvider: { issueId in
                    try await context.feature(IssuesFeature.self).issue(id: issueId)?.title
                }
            )
        ]
    }
}
