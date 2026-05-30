import Foundation

@MainActor
final class ChatsFeature: FeatureRuntime {
    override class var id: String { "chats" }

    required init(context: FeatureContext) {
        super.init(context: context)
        context.mcp.toolRegistry.register([
            ListChatsBySearchTool(),
            ListUnhandledChatsTool(),
            ListChatMessagesTool(),
            SendMessageTool(),
            WaitForEventTool()
        ])
    }
}
