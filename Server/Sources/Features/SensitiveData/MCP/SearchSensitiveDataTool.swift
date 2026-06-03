import Foundation

struct SearchSensitiveDataTool: MCPToolDefinition {
    let repositories: SensitiveDataRepositories

    let name = "search_sensitive_data"
    let icon = "magnifyingglass"
    let description = "Searches safe metadata for sensitive data by textual similarity and returns the best matches. The actual value must still be retrieved with get_sensitive_data."
    let group = "sensitiveData"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object(["type": .string("string")]),
            "issueId": .object(["type": .string("string")]),
            "reason": .object(["type": .string("string")]),
            "kinds": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("string"),
                    "enum": MCPSupport.defineEnum(SensitiveDataKind.self)
                ]),
                "description": .string("Optional list of sensitive data categories to include. If omitted or empty, all non-deleted sensitive data records are searched.")
            ])
        ]),
        "required": .array([.string("query"), .string("issueId"), .string("reason")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "query", value: .string("CPF")),
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "reason", value: .string("encontrar o dado correto para preencher a consulta")),
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
        let query = try MCPSupport.string("query", from: call)
        let issueId = try MCPSupport.string("issueId", from: call)
        let reason = try MCPSupport.string("reason", from: call)
        let kinds = try SensitiveDataMCPToolSupport.parseKinds(from: call)
        let items = try await repositories.data.search(query: query, kinds: kinds)
        let usage = try await repositories.usage.save(
            SensitiveDataMCPToolSupport.usage(
                action: .search,
                key: SensitiveDataMCPToolSupport.searchAuditKey(for: query),
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
