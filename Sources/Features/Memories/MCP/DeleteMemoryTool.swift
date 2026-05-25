import Foundation

struct DeleteMemoryTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "delete_memory",
        summary: "Delete a memory.",
        group: .memories,
        traits: [.writesState]
    )

    init() {}
}
