import Foundation

struct SendMessageTool: MCPToolDefinition {
    let name = "send_message"
    let icon = "paperplane"
    let description = "Deferred placeholder for outbound transport. Real send flow will later validate issueId, compose with SentMessages settings, and audit send status."
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "chatId": .object(["type": .string("string")]),
            "messages": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ])
        ]),
        "required": .array([.string("issueId"), .string("chatId"), .string("messages")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "chatId", value: .string("chat-1")),
        .init(name: "messages", value: .array([
            .string("Testing send_message from the tools browser."),
            .string("Another batch message")
        ]))
    ]
    let traits: [MCPToolTrait] = [.writesState, .sideEffect]
}
