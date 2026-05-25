import Foundation

struct ListActiveIssuesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_active_issues",
        icon: "folder",
        description: "Checks the currently active issues that still need follow-up.",
        group: .issues,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ]),
        exampleParameters: [],
        traits: [.readOnly]
    )

    init() {}
}
