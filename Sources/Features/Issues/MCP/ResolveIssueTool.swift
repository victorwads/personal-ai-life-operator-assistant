import Foundation

struct ResolveIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "resolve_issue",
        summary: "Mark an issue as resolved.",
        group: .issues,
        traits: [.writesState]
    )

    init() {}
}
