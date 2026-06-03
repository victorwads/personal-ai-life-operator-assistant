import Foundation

struct UpdateSensitiveDataTool: MCPToolDefinition {
    let repositories: SensitiveDataRepositories

    let name = "update_sensitive_data"
    let icon = "pencil"
    let description = """
    Updates an existing sensitive data entry by key.

    `kind` may only be one of the allowed broad categories: document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.
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
        "required": .array([.string("issueId"), .string("reason"), .string("key")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "key", value: .string("client_document")),
        .init(name: "kind", value: .string("document")),
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "reason", value: .string("corrigir o dado sensível salvo anteriormente"))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let reason = try MCPSupport.string("reason", from: call)
        let key = try MCPSupport.string("key", from: call)
        guard let existingItem = try await repositories.data.item(forKey: key, includeDeleted: false) else {
            let usage = try await repositories.usage.save(
                SensitiveDataMCPToolSupport.usage(
                    action: .update,
                    key: key,
                    issueId: issueId,
                    reason: reason
                ),
                merge: false
            )

            return .object([
                "updated": .bool(false),
                "item": .null,
                "usage": SensitiveDataMCPToolSupport.usageObject(usage)
            ])
        }

        let kind: SensitiveDataKind
        if let rawKind = MCPSupport.optionalString("kind", from: call) {
            guard let parsedKind = SensitiveDataKind(rawValue: rawKind) else {
                throw SensitiveDataMCPToolError.invalidArguments("Invalid sensitive data kind.")
            }
            kind = parsedKind
        } else {
            kind = existingItem.kind
        }

        let updatedItem = try await repositories.data.save(
            SensitiveDataItem(
                id: existingItem.id,
                key: existingItem.key,
                kind: kind,
                value: MCPSupport.optionalString("value", from: call) ?? existingItem.value,
                issueId: issueId
            )
        )

        let usage = try await repositories.usage.save(
            SensitiveDataMCPToolSupport.usage(
                action: .update,
                key: key,
                issueId: issueId,
                reason: reason
            ),
            merge: false
        )

        return .object([
            "updated": .bool(true),
            "item": SensitiveDataMCPToolSupport.itemMetadataObject(updatedItem),
            "usage": SensitiveDataMCPToolSupport.usageObject(usage)
        ])
    }
}
