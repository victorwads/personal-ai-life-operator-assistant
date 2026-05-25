import Foundation

struct ListChatsBySearchTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_chats_by_search",
        icon: "magnifyingglass",
        description: "Search chats by query, name, or term and return the best matches.",
        group: .chats,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object(["type": .string("string")]),
                "limit": .object(["type": .string("number")])
            ]),
            "required": .array([.string("query")])
        ]),
        exampleParameters: [
            .init(name: "query", value: .string("Leonardo")),
            .init(name: "limit", value: .integer(3))
        ],
        traits: [.readOnly]
    )

    init() {}
}
