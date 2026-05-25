import Foundation

struct CreateIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "create_issue",
        summary: "Create a new operational issue.",
        group: .issues,
        traits: [.writesState]
    )

    init() {}
}
