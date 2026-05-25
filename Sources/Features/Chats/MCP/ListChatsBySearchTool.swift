import Foundation

struct ListChatsBySearchTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_chats_by_search",
        summary: "Search chats by text query.",
        group: .chats,
        traits: [.readOnly]
    )

    init() {}
}
