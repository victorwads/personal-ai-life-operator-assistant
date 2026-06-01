import Foundation

struct ListChatMessagesTool: MCPToolDefinition {
    private let repository: any ChatRepository

    init(repository: any ChatRepository) {
        self.repository = repository
    }

    let name = "list_chat_messages"
    let icon = "clock"
    let description = "Loads persisted messages from a chat in conversational order."
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
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let chatId = try MCPSupport.string("chatId", from: call)
        let limit = MCPSupport.optionalLimit(from: call, default: 10)
        let messages = try await repository.listMessages(chatId: chatId, limit: limit)

        let unhandledIds: [String] = messages
            .filter { !$0.handled }
            .compactMap { $0.id }
        if !unhandledIds.isEmpty {
            try await repository.markMessagesHandled(ids: unhandledIds)
            try await repository.updateUnhandledCount(chatId: chatId, count: nil)
        }

        return .object([
            "chatId": .string(chatId),
            "count": .int(messages.count),
            "messages": .array(messages.map(messageJSON))
        ])
    }

    // ListChatMessagesTool
    // TODO remove null fields from info, end refactor to make the tool response por "human"
    // - send a text plain response for all mcp tools
    // - group per _createAt date (date from crawnled) + time insiede message
    // - make clear about "sent/received" and sent from client/ from assistant
    private func messageJSON(_ message: ChatMessage) -> MCPJSONValue {
        let iso8601Formatter = ISO8601DateFormatter()
        return .object([
            "id": message.id.map(MCPJSONValue.string) ?? .null,
            "chatId": .string(message.chatId),
            "author": message.author.map(MCPJSONValue.string) ?? .null,
            "text": message.text.map(MCPJSONValue.string) ?? .null,
            "kind": .string(message.kind.rawValue),
            "direction": .string(message.direction.rawValue),
            "listOrder": .int(message.listOrder),
            "dateTime": message.dateTime.map { .string(iso8601Formatter.string(from: $0)) } ?? .null,
            "quotedMessageText": message.quotedMessageText.map(MCPJSONValue.string) ?? .null,
            "quotedMessageAuthor": message.quotedMessageAuthor.map(MCPJSONValue.string) ?? .null,
            "handled": .bool(message.handled)
        ])
    }
}
