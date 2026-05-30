import Foundation

struct ListChatMessagesTool: MCPToolDefinition {
    let name = "list_chat_messages"
    let icon = "clock"
    let description = """
    Loads messages from a chat and prioritizes messages not yet handled by the assistant.

    This is the main tool to call after wait_for_event reports chat activity. It always includes at least the unhandled messages for the chat. If the requested limit is larger than the number of unhandled messages, it should include previous messages as context. Messages are returned in useful conversational order. If the assistant needs more context, it should call this tool again with a larger limit.
    """
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "chatId": .object(["type": .string("string")]),
            "limit": .object(["type": .string("number")])
        ]),
        "required": .array([.string("chatId")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "chatId", value: .string("chat-1")),
        .init(name: "limit", value: .integer(5))
    ]
    let traits: [MCPToolTrait] = [.readOnly]
}
