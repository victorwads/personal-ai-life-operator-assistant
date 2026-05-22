import Foundation

struct WaitNextEventTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "wait_for_event",
        icon: "bell.badge",
        description: "Waits until any unread WhatsApp messages are available or the client provides a prompt. Returns lightweight chat identifiers for affected chats.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:])
        ],
        exampleParameters: [],
        traits: [.blocking]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let waitId = await context.beginClientPromptWait()
        defer {
            Task { await context.endClientPromptWait(id: waitId) }
        }

        while true {
            if Task.isCancelled {
                return .failure(CancellationError())
            }

            if let prompt = await context.consumeClientPrompt() {
                return .success(.object([
                    "timedOut": .bool(false),
                    "events": .array([
                        .object([
                            "type": .string("client_prompt"),
                            "prompt": .string(prompt)
                        ])
                    ])
                ]))
            }

            let unreadMessages = await MainActor.run {
                context.memoryStore.unreadMessages(chatId: nil)
            }
            let grouped = Dictionary(grouping: unreadMessages, by: \.chatId)
            var events: [JSONValue] = []
            for chatId in grouped.keys.sorted() {
                guard let messages = grouped[chatId], !messages.isEmpty else {
                    continue
                }

                let chat = await MainActor.run {
                    context.memoryStore.chatState(for: chatId)?.chat
                        ?? context.memoryStore.conversation(for: chatId)
                }

                if let chat, context.isBlocked(chat.name) {
                    continue
                }

                await MainActor.run {
                    context.memoryStore.markMessagesHandled(messageIds: Set(messages.map(\.id)), chatId: chatId)
                }

                if let chat {
                    events.append(
                        .object([
                            "type": .string("chat_messages"),
                            "chat": .object([
                                "id": .string(chat.id),
                                "name": .string(chat.name)
                            ]),
                            "chatId": .null
                        ])
                        .pruningNulls()
                    )
                } else {
                    events.append(
                        .object([
                            "type": .string("chat_messages"),
                            "chat": .null,
                            "chatId": .string(chatId)
                        ])
                        .pruningNulls()
                    )
                }
            }

            if !events.isEmpty {
                return .success(.object([
                    "timedOut": .bool(false),
                    "events": .array(events)
                ]))
            }

            try? await Task.sleep(for: .milliseconds(350))
        }
    }
}
