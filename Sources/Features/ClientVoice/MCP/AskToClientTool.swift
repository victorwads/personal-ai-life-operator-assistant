import Foundation

struct AskToClientTool: MCPToolDefinition {
    let name = "ask_to_client"
    let icon = "questionmark.bubble"
    let description = "Used when the assistant needs a decision, missing information, permission, or clarification from the client. Voice and language settings come from Settings, not from this MCP call."
    let group = "clientVoice"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")])
        ]),
        "required": .array([.string("issueId"), .string("text")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "text", value: .string("Testing ask_to_client in English. Please answer briefly."))
    ]
    let traits: [MCPToolTrait] = [.sideEffect, .blocking]
}
