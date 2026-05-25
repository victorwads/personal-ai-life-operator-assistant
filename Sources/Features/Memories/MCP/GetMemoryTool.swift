import Foundation

struct GetMemoryTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_memory",
        summary: "Fetch a memory by identifier.",
        group: .memories,
        traits: [.readOnly]
    )

    init() {}
}
