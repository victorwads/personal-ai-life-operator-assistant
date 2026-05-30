import Foundation

struct DeleteSensitiveDataTool: MCPToolDefinition {
    // TODO: Soft delete the record, preserve audit history, and keep deleted items out of normal list_sensitive_data results.
    let name = "delete_sensitive_data"
    let icon = "trash"
    let description = """
    Soft-deletes a sensitive data entry by key.

    Sensitive data should be marked as deleted. Deleted records should not appear in normal list_sensitive_data results. Audit history must remain preserved.
    """
    let group = "sensitiveData"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "key": .object(["type": .string("string")]),
            "issueId": .object(["type": .string("string")]),
            "reason": .object(["type": .string("string")])
        ]),
        "required": .array([.string("issueId"), .string("reason"), .string("key")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "key", value: .string("client_document")),
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "reason", value: .string("remover dado sensível incorreto"))
    ]
    let traits: [MCPToolTrait] = [.writesState]
}
