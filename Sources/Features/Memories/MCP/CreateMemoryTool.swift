import Foundation

struct CreateMemoryTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "create_memory",
        summary: "Create a durable memory.",
        group: .memories,
        traits: [.writesState]
    )

    init() {}
}
