import Foundation

struct WaitForChatMessageTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "wait_for_chat_message",
        summary: "Wait for a new message in a chat.",
        group: .chats,
        traits: [.blocking]
    )

    init() {}
}
