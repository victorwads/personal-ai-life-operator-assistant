import Foundation

struct SendMessageTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "send_message",
        icon: "paperplane",
        description: "Sends external chat messages. This tool must be attached to an Issue, and the send action should later be auditable through the Issue timeline or history.",
        group: .chats,
        inputSchema: .object([
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
        ]),
        exampleParameters: [
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "chatId", value: .string("chat-1")),
            .init(name: "messages", value: .array([
                .string("Testing send_message from the tools browser."),
                .string("Another batch message")
            ]))
        ],
        traits: [.writesState, .sideEffect]
    )

    init() {}
}
