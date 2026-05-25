import Foundation

struct GetIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_issue",
        icon: "folder",
        description: "Fetches an issue by id.",
        group: .issues,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object(["type": .string("string")])
            ]),
            "required": .array([.string("id")])
        ]),
        exampleParameters: [
            .init(name: "id", value: .string("issue-1"))
        ],
        traits: [.readOnly]
    )

    init() {}
}
