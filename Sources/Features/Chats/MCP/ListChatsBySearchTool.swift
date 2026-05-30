import Foundation

struct ListChatsBySearchTool: MCPToolDefinition {
    let name = "list_chats_by_search"
    let icon = "magnifyingglass"
    let description = "Search chats by query, name, or term and return the best matches."
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object(["type": .string("string")]),
            "limit": .object(["type": .string("number")])
        ]),
        "required": .array([.string("query")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "query", value: .string("Leonardo")),
        .init(name: "limit", value: .integer(3))
    ]
    let traits: [MCPToolTrait] = [.readOnly]
}
