import Foundation

struct SaveSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "save_sensitive_data",
        icon: "lock",
        description: """
        Creates or updates a sensitive data entry keyed by `key`.

        Use this for durable sensitive values grouped into broad categories only. `kind` must be one of:
        document, email, personalInfo, bankInformation, healthInformation, relationshipInfo, other.
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
            "required": .array([
                .string("issueId"),
                .string("reason"),
                .string("key"),
                .string("kind"),
                .string("value")
            ])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("client_document")),
            .init(name: "kind", value: .string("document")),
            .init(name: "value", value: .string("123.456.789-00")),
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "reason", value: .string("cadastrar um dado sensível recebido do cliente"))
        ],
        traits: [.writesState]
    )

    init() {}
}
