import Foundation

struct ListUnhandledChatsTool: MCPToolDefinition {
    private let repository: any ChatRepository

    init(repository: any ChatRepository) {
        self.repository = repository
    }

    let name = "list_unhandled_chats"
    let icon = "envelope.badge"
    let description = """
    Lists chats that still have messages or events not yet handled by the assistant.

    Unread means unread in the source app, such as WhatsApp. Unhandled means the assistant has not processed or handled the content yet. This is the assistant-oriented pending chat queue.
    """
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "limit": .object(["type": .string("number")])
        ])
    ])
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let limit = MCPSupport.optionalLimit(from: call, default: 10)
        let chats = try await repository.listUnhandledChats(limit: limit)
        return .object([
            "count": .int(chats.count),
            "chats": .array(chats.map(chatJSON))
        ])
    }

    private func chatJSON(_ chat: Chat) -> MCPJSONValue {
        .object([
            "chatId": chat.id.map(MCPJSONValue.string) ?? .string(""),
            "title": .string(chat.title),
            "lastMessagePreview": chat.lastMessagePreview.map(MCPJSONValue.string) ?? .null,
            "lastMessageTimeText": chat.lastMessageTimeText.map(MCPJSONValue.string) ?? .null,
            "unreadCount": .int(chat.unreadCount),
            "unhandledCount": .int(chat.unhandledCount)
        ])
    }
}
