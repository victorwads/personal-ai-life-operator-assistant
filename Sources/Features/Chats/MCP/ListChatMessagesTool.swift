import Foundation

struct ListChatMessagesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_chat_messages",
        icon: "clock",
        description: """
        Loads messages from a chat and prioritizes messages not yet handled by the assistant.

        This is the main tool to call after wait_for_event reports chat activity. It always includes at least the unhandled messages for the chat. If the requested limit is larger than the number of unhandled messages, it should include previous messages as context. Messages are returned in useful conversational order. If the assistant needs more context, it should call this tool again with a larger limit.
        """,
        group: .chats,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "chatId": .object(["type": .string("string")]),
                "limit": .object(["type": .string("number")])
            ]),
            "required": .array([.string("chatId")])
        ]),
        exampleParameters: [
            .init(name: "chatId", value: .string("chat-1")),
            .init(name: "limit", value: .integer(5))
        ],
        traits: [.readOnly]
    )

    init() {}
}
