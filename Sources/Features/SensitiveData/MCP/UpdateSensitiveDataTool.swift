import Foundation

struct UpdateSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "update_sensitive_data",
        icon: "pencil",
        description: """
        Updates an existing sensitive data entry by key.

        `kind` may only be one of the allowed broad categories: document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.
        """,
        group: .sensitiveData,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "key": .object(["type": .string("string")]),
                "kind": .object([
                    "type": .string("string"),
                    "enum": .array(SensitiveDataKind.allCases.map { .string($0.rawValue) }),
                    "description": .string("Broad sensitive data category. Allowed values: document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.")
                ]),
                "value": .object(["type": .string("string")]),
                "issueId": .object(["type": .string("string")]),
                "reason": .object(["type": .string("string")])
            ]),
            "required": .array([.string("issueId"), .string("reason"), .string("key")])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("client_document")),
            .init(name: "kind", value: .string("document")),
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "reason", value: .string("corrigir o dado sensível salvo anteriormente"))
        ],
        traits: [.writesState]
    )

    init() {}
}
