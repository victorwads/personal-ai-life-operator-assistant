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
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async -> MCPToolExecutionResult {
        do {
            let chatId = try MCPToolArguments.requiredString("chatId", from: call)
            let limit = MCPToolArguments.optionalLimit(from: call, default: 10)
            let messages = try await repository.listMessages(chatId: chatId, limit: limit)
            return .success(
                toolName: call.name,
                payload: .object([
                    "chatId": .string(chatId),
                    "count": .int(messages.count),
                    "messages": .array(messages.map(messageJSON))
                ])
            )
        } catch let error as MCPToolArgumentError {
            return .failure(toolName: call.name, error: error.serverError)
        } catch {
            return .failure(
                toolName: call.name,
                error: .executionFailed("Failed to list chat messages: \(error.localizedDescription)")
            )
        }
    }

    private func messageJSON(_ message: ChatMessage) -> MCPJSONValue {
        let iso8601Formatter = ISO8601DateFormatter()
        return .object([
            "id": message.id.map(MCPJSONValue.string) ?? .null,
            "chatId": .string(message.chatId),
            "author": message.author.map(MCPJSONValue.string) ?? .null,
            "text": message.text.map(MCPJSONValue.string) ?? .null,
            "kind": .string(message.kind.rawValue),
            "dateTime": message.dateTime.map { .string(iso8601Formatter.string(from: $0)) } ?? .null,
            "quotedMessageText": message.quotedMessageText.map(MCPJSONValue.string) ?? .null,
            "quotedMessageAuthor": message.quotedMessageAuthor.map(MCPJSONValue.string) ?? .null,
            "handled": .bool(message.handled)
        ])
    }
}
