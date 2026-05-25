import Foundation

struct CancelIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "cancel_issue",
        summary: "Cancel an issue.",
        group: .issues,
        traits: [.writesState]
    )

    init() {}
}
