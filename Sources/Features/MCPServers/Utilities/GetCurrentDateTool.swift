import Foundation

struct GetCurrentDateTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_current_date",
        summary: "Return the current date and time.",
        group: .utilities,
        traits: [.readOnly]
    )

    init() {}
}
