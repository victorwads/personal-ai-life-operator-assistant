import Foundation

struct ListActiveIssuesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_active_issues",
        summary: "List issues that are still active.",
        group: .issues,
        traits: [.readOnly]
    )

    init() {}
}
