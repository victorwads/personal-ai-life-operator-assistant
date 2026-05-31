import Foundation

struct ListSensitiveDataTool: MCPToolDefinition {
    let repositories: SensitiveDataRepositories

    let name = "list_sensitive_data"
    let icon = "lock"
    let description = """
    Lists safe metadata for sensitive data entries only.

    This tool must not return the sensitive value. Use get_sensitive_data to retrieve the actual value.
    Optional kinds filter broad categories only: document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.
    Returned metadata is keyed only by `key`.
    """
    let group = "sensitiveData"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "reason": .object(["type": .string("string")]),
            "kinds": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("string"),
                    "enum": MCPSupport.defineEnum(SensitiveDataKind.self)
                ]),
                "description": .string("Optional list of sensitive data categories to include. If omitted, all non-deleted sensitive data records are listed.")
            ])
        ]),
        "required": .array([.string("issueId"), .string("reason")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "reason", value: .string("auditar os dados conhecidos do cliente")),
        .init(
            name: "kinds",
            value: .array([
                .string("document"),
                .string("personalInfo")
            ])
        )
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let reason = try MCPSupport.string("reason", from: call)
        let kinds = try SensitiveDataMCPToolSupport.parseKinds(from: call)
        let items = try await repositories.data.list(kinds: kinds, includeDeleted: false)
        let usage = try await repositories.usage.save(
            SensitiveDataMCPToolSupport.usage(
                action: .list,
                key: SensitiveDataMCPToolSupport.listAuditKey,
                issueId: issueId,
                reason: reason
            ),
            merge: false
        )

        return .object([
            "items": SensitiveDataMCPToolSupport.itemListObject(items),
            "usage": SensitiveDataMCPToolSupport.usageObject(usage)
        ])
    }
}
