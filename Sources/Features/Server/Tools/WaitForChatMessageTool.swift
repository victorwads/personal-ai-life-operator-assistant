import Foundation

struct WaitForChatMessageTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "wait_for_chat_message",
        description: "Waits until unread messages appear for a specific WhatsApp chat and returns them.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "chatId": .object(["type": .string("string")])
            ]),
            "required": .array([.string("chatId")])
        ],
        exampleParameters: [
            .init(name: "chatId", value: .string("chat-1"))
        ],
        traits: [.blocking]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let arguments = MCPToolArguments(values: call.arguments)
        guard let chatId = arguments.string(for: "chatId", "chat_id") else {
            return .failure(MCPServerError.missingParameter("chatId"))
        }

        let result = await waitForUnreadMessages(chatId: chatId, context: context, timeoutSeconds: 110)
        guard let result else {
            return .success(.object(["timedOut": .bool(true)]))
        }

        let chat = await MainActor.run {
            result.first.flatMap { message in
                context.memoryStore.chatState(for: message.chatId)?.chat
                    ?? context.memoryStore.conversation(for: message.chatId)
            }
        }

        guard let chat else {
            return .success(.object([
                "timedOut": .bool(false),
                "chat": .null,
                "messages": .array(result.map(context.messageJSONValue))
            ]))
        }

        return .success(.object([
            "timedOut": .bool(false),
            "chat": context.conversationJSONValue(chat),
            "messages": .array(result.map(context.messageJSONValue))
        ]))
    }

    static func waitForUnreadMessages(
        chatId: String,
        context: MCPServerContext,
        timeoutSeconds: Int
    ) async -> [Message]? {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while Date() < deadline {
            let consumed = await MainActor.run {
                context.memoryStore.consumeUnreadMessages(chatId: chatId)
            }
            if !consumed.isEmpty {
                return consumed
            }

            try? await Task.sleep(for: .milliseconds(350))
        }

        return nil
    }
}
