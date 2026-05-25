import Foundation

struct SearchMemoriesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "search_memories",
        summary: "Search memories by text query.",
        group: .memories,
        traits: [.readOnly]
    )

    init() {}
}
