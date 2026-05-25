import Foundation

struct SearchSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "search_sensitive_data",
        icon: "magnifyingglass",
        description: "Searches safe metadata for sensitive data by textual similarity and returns the best matches. The actual value must still be retrieved with get_sensitive_data.",
        group: .sensitiveData,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object(["type": .string("string")]),
                "issueId": .object(["type": .string("string")]),
                "reason": .object(["type": .string("string")]),
                "kinds": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("string"),
                        "enum": .array(SensitiveDataKind.allCases.map { .string($0.rawValue) })
                    ]),
                    "description": .string("Optional list of sensitive data categories to include. If omitted or empty, all non-deleted sensitive data records are searched.")
                ])
            ]),
            "required": .array([.string("query"), .string("issueId"), .string("reason")])
        ]),
        exampleParameters: [
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
        ],
        traits: [.readOnly]
    )

    init() {}
}
