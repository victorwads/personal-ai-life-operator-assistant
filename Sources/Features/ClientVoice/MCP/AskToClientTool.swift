import Foundation

struct AskToClientTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "ask_to_client",
        icon: "questionmark.bubble",
        description: "Used when the assistant needs a decision, missing information, permission, or clarification from the client. Voice and language settings come from Settings, not from this MCP call.",
        group: .clientVoice,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "text": .object(["type": .string("string")])
            ]),
            "required": .array([.string("issueId"), .string("text")])
        ]),
        exampleParameters: [
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "text", value: .string("Testing ask_to_client in English. Please answer briefly."))
        ],
        traits: [.sideEffect, .blocking]
    )

    init() {}
}
