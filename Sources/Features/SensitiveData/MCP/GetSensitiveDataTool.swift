import Foundation

struct GetSensitiveDataTool: MCPToolDefinition {
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
}
