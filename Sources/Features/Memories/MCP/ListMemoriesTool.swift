import Foundation

struct ListMemoriesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_memories",
        summary: "List stored memories.",
        group: .memories,
        traits: [.readOnly]
    )

    init() {}
}
