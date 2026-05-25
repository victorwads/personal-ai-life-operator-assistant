import Foundation

struct CreateMemoryTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "create_memory",
        icon: "brain",
        description: """
        Creates or updates a long-term memory entry keyed by `key`.

        Use this for durable facts and standing instructions that should keep influencing future interactions. If the key already exists, it updates the existing memory instead of creating a duplicate.

        Do not tell the user you will remember something unless you save the memory first.
        """,
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "key": .object(["type": .string("string")]),
                "content": .object(["type": .string("string")])
            ]),
            "required": .array([.string("key"), .string("content")])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("victor_assertive_feedback_rule")),
            .init(name: "content", value: .string("Whenever Victor becomes rude or unnecessarily aggressive, explain calmly how he could have said it in a more assertive and non-violent way."))
        ],
        traits: [.writesState]
    )

    init() {}
}
