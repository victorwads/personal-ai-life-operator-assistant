import Foundation

struct UpdateIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "update_issue",
        summary: "Update an existing issue and append progress.",
        group: .issues,
        traits: [.writesState]
    )

    init() {}
}
