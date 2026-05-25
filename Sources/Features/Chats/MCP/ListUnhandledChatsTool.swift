import Foundation

struct ListUnhandledChatsTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_unhandled_chats",
        icon: "envelope.badge",
        description: """
        Lists chats that still have messages or events not yet handled by the assistant.

        Unread means unread in the source app, such as WhatsApp. Unhandled means the assistant has not processed or handled the content yet. This is the assistant-oriented pending chat queue.
        """,
        group: .chats,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ]),
        exampleParameters: [],
        traits: [.readOnly]
    )

    init() {}
}
