import Foundation

struct DeleteSensitiveDataTool: MCPToolDefinition {
    let repositories: SensitiveDataRepositories

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

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let reason = try MCPSupport.string("reason", from: call)
        let key = try MCPSupport.string("key", from: call)
        let item = try await repositories.data.item(forKey: key, includeDeleted: false)
        if let item {
            try await repositories.data.delete(repositories.data.documentID(forKey: key), soft: true)
        }
        let usage = try await repositories.usage.save(
            SensitiveDataMCPToolSupport.usage(
                action: .delete,
                key: key,
                issueId: issueId,
                reason: reason
            ),
            merge: false
        )

        return .object([
            "deleted": .bool(item != nil),
            "item": item.map(SensitiveDataMCPToolSupport.itemMetadataObject) ?? .null,
            "usage": SensitiveDataMCPToolSupport.usageObject(usage)
        ])
    }
}
