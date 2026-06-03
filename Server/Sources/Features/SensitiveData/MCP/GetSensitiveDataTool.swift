import Foundation

struct GetSensitiveDataTool: MCPToolDefinition {
    let repositories: SensitiveDataRepositories

    let name = "get_sensitive_data"
    let icon = "lock"
    let description = "Fetches one sensitive data entry by exact key. This is the tool that retrieves the actual sensitive value. Use it only when the current issue has a legitimate reason."
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
        .init(name: "reason", value: .string("preencher cadastro no WhatsApp"))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let reason = try MCPSupport.string("reason", from: call)
        let key = try MCPSupport.string("key", from: call)
        let item = try await repositories.data.item(forKey: key, includeDeleted: false)
        let usage = try await repositories.usage.save(
            SensitiveDataMCPToolSupport.usage(
                action: .get,
                key: key,
                issueId: issueId,
                reason: reason
            ),
            merge: false
        )

        return .object([
            "item": item.map(SensitiveDataMCPToolSupport.itemValueObject) ?? .null,
            "usage": SensitiveDataMCPToolSupport.usageObject(usage)
        ])
    }
}
