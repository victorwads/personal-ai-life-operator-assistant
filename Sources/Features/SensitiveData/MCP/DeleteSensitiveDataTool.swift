import Foundation

struct DeleteSensitiveDataTool: MCPToolHandler {
    // TODO: Soft delete the record, preserve audit history, and keep deleted items out of normal list_sensitive_data results.
    static let definition = MCPToolDefinition(
        name: "delete_sensitive_data",
        icon: "trash",
        description: """
        Soft-deletes a sensitive data entry by key.

        Sensitive data should be marked as deleted. Deleted records should not appear in normal list_sensitive_data results. Audit history must remain preserved.
        """,
        group: .sensitiveData,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "key": .object(["type": .string("string")]),
                "issueId": .object(["type": .string("string")]),
                "reason": .object(["type": .string("string")])
            ]),
            "required": .array([.string("issueId"), .string("reason"), .string("key")])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("client_document")),
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "reason", value: .string("remover dado sensível incorreto"))
        ],
        traits: [.writesState]
    )

    init() {}
}
