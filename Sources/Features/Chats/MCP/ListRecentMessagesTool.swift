import Foundation

struct ListRecentMessagesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_recent_messages",
        summary: "List recent messages for a chat.",
        group: .chats,
        traits: [.readOnly]
    )

    init() {}
}
