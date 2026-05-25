import Foundation

struct ResolveIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "resolve_issue",
        icon: "checkmark.seal",
        description: "Marks an issue as resolved by id and reason. Only call this when the issue's resolutionCondition has been satisfied.",
        group: .issues,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "reason": .object(["type": .string("string")])
            ]),
            "required": .array([.string("issueId"), .string("reason")])
        ]),
        exampleParameters: [
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "reason", value: .string("Task completed and confirmed with the client."))
        ],
        traits: [.writesState]
    )

    init() {}
}
