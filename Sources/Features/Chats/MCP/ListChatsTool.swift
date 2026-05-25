import Foundation

struct ListChatsTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_chats",
        summary: "List persisted chats.",
        group: .chats,
        traits: [.readOnly]
    )

    init() {}
}
