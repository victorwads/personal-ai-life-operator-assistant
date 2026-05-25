import Foundation

struct GetIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_issue",
        summary: "Fetch one issue by identifier.",
        group: .issues,
        traits: [.readOnly]
    )

    init() {}
}
