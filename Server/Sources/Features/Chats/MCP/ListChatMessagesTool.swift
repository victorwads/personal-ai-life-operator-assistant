import Foundation

struct ListChatMessagesTool: MCPToolDefinition {
    private static let defaultLimit = 10
    private static let emptyResponse = "No supported messages found."

    private let repository: any ChatRepository
    private let permissionModeProvider: @MainActor () -> ChatPermissionMode
    private let assistantNameProvider: @MainActor () -> String

    init(
        repository: any ChatRepository,
        permissionModeProvider: @escaping @MainActor () -> ChatPermissionMode,
        assistantNameProvider: @escaping @MainActor () -> String
    ) {
        self.repository = repository
        self.permissionModeProvider = permissionModeProvider
        self.assistantNameProvider = assistantNameProvider
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
        .init(name: "limit", value: .integer(Self.defaultLimit))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let chatId = try MCPSupport.string("chatId", from: call)
        let limit = MCPSupport.optionalLimit(from: call, default: Self.defaultLimit)
        let mode = await permissionModeProvider()
        let assistantName = await assistantNameProvider()
        guard let chat = try await repository.getChat(id: chatId) else {
            throw MCPServerError.invalidArguments("Chat '\(chatId)' was not found.")
        }
        guard ChatPermissionResolver.isChatAllowed(chat, mode: mode) else {
            throw MCPServerError.invalidArguments("Chat '\(chat.title)' is not allowed by current chat permissions.")
        }
        let resolvedLimit = max(limit, minLimit(for: chat))
        let messages = try await repository.listMessages(chatId: chatId, limit: resolvedLimit)

        // TODO: Disabled for now.
        // Listing messages should not automatically mark them as handled.
        // Handled state must be changed explicitly by a dedicated MCP tool/action.
        // Keep this code here as reference for future behavior.
        // let unhandledIds: [String] = messages
        //     .filter { !$0.handled }
        //     .compactMap { $0.id }
        // if !unhandledIds.isEmpty {
        //     try await repository.markMessagesHandled(ids: unhandledIds)
        //     try await repository.updateUnhandledCount(chatId: chatId, count: nil)
        // }

        let renderedMessages = renderMessages(messages.reversed(), assistantName: assistantName)
        guard !messages.isEmpty else {
            return .string(renderedMessages)
        }

        guard let lastMessageId = messages.last?.id, !lastMessageId.isEmpty else {
            throw MCPServerError.invalidArguments("Unable to create a read receipt for chat '\(chatId)'.")
        }

        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: chatId,
            lastChatMessageId: lastMessageId
        )
        let responseText = [
            "readReceipt: \(readReceipt)",
            renderedMessages,
            Self.readReceiptInstruction
        ]
        .joined(separator: "\n\n")

        return .string(responseText)
    }

    private static let readReceiptInstruction = "To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId."

    private func minLimit(for chat: Chat) -> Int {
        max(0, chat.unhandledCount) + 5
    }

    private func renderMessages(
        _ messages: [ChatMessage],
        assistantName: String
    ) -> String {
        let rendered = messages
            .filter(isSupportedMessage)
            .map { renderMessage($0, assistantName: assistantName) }

        guard !rendered.isEmpty else {
            return Self.emptyResponse
        }

        return rendered.joined(separator: "\n\n---\n\n")
    }

    private func renderMessage(
        _ message: ChatMessage,
        assistantName: String
    ) -> String {
        let header = "\(formattedDateTime(message.dateTime))\(displayAuthor(for: message, assistantName: assistantName)):"
        let replyContext = formattedReplyContext(for: message)
        let body = formattedBody(for: message)

        if let replyContext {
            return "\(header)\n\(replyContext)\n\(body)"
        }

        return "\(header)\n\(body)"
    }

    private func formattedDateTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return "[\(formatter.string(from: date))] "
    }

    private func displayAuthor(
        for message: ChatMessage,
        assistantName: String
    ) -> String {
        if message.direction == .sent {
            if message.sentByAssistant == true {
                return "\(assistantName) (sent by assistant)"
            }

            return "Client (sent manually by client)"
        }

        let author = message.author?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let author, !author.isEmpty {
            return "\(author) (received)"
        }

        return "Client (received)"
    }

    private func formattedReplyContext(for message: ChatMessage) -> String? {
        let author = message.quotedMessageAuthor?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = message.quotedMessageText?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let author, !author.isEmpty,
            let text, !text.isEmpty
        else {
            return nil
        }

        return "In reply to \(author): \(text)"
    }

    private func isSupportedMessage(_ message: ChatMessage) -> Bool {
        switch message.kind {
        case .text, .image, .sticker, .audio, .video:
            return true
        default:
            return false
        }
    }

    private func formattedBody(for message: ChatMessage) -> String {
        let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch message.kind {
        case .text:
            return text ?? "empty"
        case .image:
            if let text, !text.isEmpty {
                return "Image: \(text)"
            }
            return "Image without description"
        case .audio:
            if let text, !text.isEmpty {
                return "Transcribed audio: \(text)"
            }
            return "Audio Message"
        case .sticker:
            if let text, !text.isEmpty {
                return "Sticker: \(text)"
            }
            return "Sticker without description"
        default:
            return message.kind.rawValue
        }
    }
}
