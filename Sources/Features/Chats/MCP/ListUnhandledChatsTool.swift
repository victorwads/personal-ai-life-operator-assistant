import Foundation

struct ListUnhandledChatsTool: MCPToolDefinition {
    let name = "list_unhandled_chats"
    let icon = "envelope.badge"
    let description = """
    Lists chats that still have messages or events not yet handled by the assistant.

    Unread means unread in the source app, such as WhatsApp. Unhandled means the assistant has not processed or handled the content yet. This is the assistant-oriented pending chat queue.
    """
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]
}
