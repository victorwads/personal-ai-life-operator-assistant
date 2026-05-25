import Foundation

struct ListUnreadChatsTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_unread_chats",
        summary: "List chats with unread messages.",
        group: .chats,
        traits: [.readOnly]
    )

    init() {}
}
