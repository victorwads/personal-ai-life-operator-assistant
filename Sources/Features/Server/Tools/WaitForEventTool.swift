import Foundation

struct WaitForEventTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "wait_for_event",
        description: "Waits until any unread WhatsApp messages are available and returns them grouped by chat.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:])
        ],
        exampleParameters: [],
        traits: [.blocking]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let result = await waitForAnyUnreadMessages(context: context, timeoutSeconds: 110)
        guard let result else {
            return .success(.object([
                "timedOut": .bool(true),
                "events": .array([])
            ]))
        }

        let grouped = Dictionary(grouping: result, by: \.chatId)
        var events: [JSONValue] = []
        for chatId in grouped.keys.sorted() {
            guard let messages = grouped[chatId], !messages.isEmpty else {
                continue
            }

            let chat = await MainActor.run {
                context.memoryStore.chatState(for: chatId)?.chat
                    ?? context.memoryStore.conversation(for: chatId)
            }

            if let chat {
                events.append(context.chatMessagesEventJSONValue(chat: chat, messages: messages))
            } else {
                events.append(.object([
                    "type": .string("chat_messages"),
                    "chat": .null,
                    "messages": .array(messages.map(context.messageJSONValue))
                ]))
            }
        }

        return .success(.object([
            "timedOut": .bool(false),
            "events": .array(events)
        ]))
    }

    static func waitForAnyUnreadMessages(
        context: MCPServerContext,
        timeoutSeconds: Int
    ) async -> [Message]? {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while Date() < deadline {
            let consumed = await MainActor.run {
                context.memoryStore.consumeUnreadMessages(chatId: nil)
            }
            if !consumed.isEmpty {
                return consumed
            }

            try? await Task.sleep(for: .milliseconds(350))
        }

        return nil
    }
}
