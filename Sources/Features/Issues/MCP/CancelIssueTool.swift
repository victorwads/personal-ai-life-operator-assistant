import Foundation

struct CancelIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "cancel_issue",
        icon: "xmark.circle",
        description: "Marks an issue as canceled by id and reason.",
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
            .init(name: "reason", value: .string("The request is no longer needed."))
        ],
        traits: [.writesState]
    )

    init() {}
}
