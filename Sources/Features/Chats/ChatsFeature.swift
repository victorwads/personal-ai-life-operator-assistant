import Foundation

@MainActor
final class ChatsFeature: FeatureRuntime {
    override class var id: String { "chats" }

    let repository: FirestoreChatRepository

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("ChatsFeature requires a persisted profile scope.")
        }

        let repository = FirestoreChatRepository(scope: scope)
        self.repository = repository
        super.init(context: context)

        context.mcp.toolRegistry.register([
            ListChatsTool(repository: repository),
            ListChatsBySearchTool(),
            ListUnhandledChatsTool(repository: repository),
            ListChatMessagesTool(repository: repository)
        ])
    }
}
