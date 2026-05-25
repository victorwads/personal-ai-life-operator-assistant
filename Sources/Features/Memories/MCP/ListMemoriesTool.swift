import Foundation

struct ListMemoriesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_memories",
        icon: "list.bullet.rectangle",
        description: "Lists all saved memory entries, including durable facts, recurring preferences, and standing instructions. Review this at startup and occasionally during long-running work so persistent context stays available.",
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ]),
        exampleParameters: [],
        traits: [.readOnly]
    )

    init() {}
}
