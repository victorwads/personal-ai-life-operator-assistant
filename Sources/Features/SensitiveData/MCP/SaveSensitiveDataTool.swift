import Foundation

struct SaveSensitiveDataTool: MCPToolDefinition {
    let repositories: SensitiveDataRepositories

    let name = "save_sensitive_data"
    let icon = "lock"
    let description = """
    Creates or updates a sensitive data entry keyed by `key`.

    Use this for durable sensitive values grouped into broad categories only. `kind` must be one of:
    document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.
    """
    let group = "sensitiveData"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "key": .object(["type": .string("string")]),
            "kind": .object([
                "type": .string("string"),
                "enum": MCPSupport.defineEnum(SensitiveDataKind.self),
                "description": .string("Broad sensitive data category. Allowed values: document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.")
            ]),
            "value": .object(["type": .string("string")]),
            "issueId": .object(["type": .string("string")]),
            "reason": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("issueId"),
            .string("reason"),
            .string("key"),
            .string("kind"),
            .string("value")
        ])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "key", value: .string("client_document")),
        .init(name: "kind", value: .string("document")),
        .init(name: "value", value: .string("123.456.789-00")),
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "reason", value: .string("cadastrar um dado sensível recebido do cliente"))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let reason = try MCPSupport.string("reason", from: call)
        let key = try MCPSupport.string("key", from: call)
        let value = try MCPSupport.string("value", from: call)
        let kindRawValue = try MCPSupport.string("kind", from: call)

        guard let kind = SensitiveDataKind(rawValue: kindRawValue) else {
            throw SensitiveDataMCPToolError.invalidArguments("Invalid sensitive data kind.")
        }

        let existingItem = try await repositories.data.item(forKey: key, includeDeleted: true)
        let savedItem = try await repositories.data.save(
            SensitiveDataItem(
                id: existingItem?.id ?? repositories.data.documentID(forKey: key),
                key: key,
                kind: kind,
                value: value,
                issueId: issueId
            )
        )

        let usage = try await repositories.usage.save(
            SensitiveDataMCPToolSupport.usage(
                action: .save,
                key: key,
                issueId: issueId,
                reason: reason
            ),
            merge: false
        )

        return .object([
            "item": SensitiveDataMCPToolSupport.itemMetadataObject(savedItem),
            "usage": SensitiveDataMCPToolSupport.usageObject(usage)
        ])
    }
}
