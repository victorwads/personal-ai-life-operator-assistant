import Foundation

struct ListChatMessagesTool: MCPToolDefinition {
    private static let defaultLimit = 10
    private static let emptyResponse = "No messages found."

    private let repository: any ChatRepository
    private let permissionModeProvider: @MainActor () -> ChatPermissionMode
    private let assistantNameProvider: @MainActor () -> String
    private let contactProvider: @Sendable @MainActor (String) async throws -> AssistantContact?

    init(
        repository: any ChatRepository,
        permissionModeProvider: @escaping @MainActor () -> ChatPermissionMode,
        assistantNameProvider: @escaping @MainActor () -> String,
        contactProvider: @escaping @Sendable @MainActor (String) async throws -> AssistantContact? = { _ in nil }
    ) {
        self.repository = repository
        self.permissionModeProvider = permissionModeProvider
        self.assistantNameProvider = assistantNameProvider
        self.contactProvider = contactProvider
    }

    let name = "whatsapp_list_chat_messages"
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
        let totalMessages = try await repository.listMessages(chatId: chatId, limit: nil)
        let messages = Array(totalMessages.prefix(resolvedLimit))
        let renderedMessages = renderMessages(messages.reversed(), assistantName: assistantName)
        let contact = try await contactProvider(chatId)
        let renderedContext = renderChatContext(chat.chatContext, contact: contact)
        guard !messages.isEmpty else {
            return .string(composeContextAndMessages(context: renderedContext, messages: renderedMessages))
        }

        // First is the newer in the repository default order
        guard let lastMessageId = messages.first?.id, !lastMessageId.isEmpty else {
            throw MCPServerError.invalidArguments("Unable to create a read receipt for chat '\(chatId)'.")
        }

        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: chatId,
            lastChatMessageId: lastMessageId
        )
        let responseText = [
            "readReceipt: \(readReceipt)",
            renderedContext,
            renderedMessages,
            summaryText(visibleCount: messages.count, totalCount: totalMessages.count),
            Self.readReceiptInstruction
        ]
        .compactMap { value in
            guard let value else { return nil }
            return value.isEmpty ? nil : value
        }
        .joined(separator: "\n\n")

        return .string(responseText)
    }

    private static let readReceiptInstruction = "To mark these messages as handled, call whatsapp_mark_chat_messages_as_handled with this readReceipt and an issueId."

    private func minLimit(for chat: Chat) -> Int {
        max(1, chat.unhandledCount)
    }

    private func summaryText(visibleCount: Int, totalCount: Int) -> String {
        "Showing the latest \(visibleCount) messages out of \(totalCount) total messages in this chat."
    }

    private func renderChatContext(_ context: String?, contact: AssistantContact?) -> String? {
        var parts: [String] = []

        if let contact = contact {
            let info = """
            Linked Contact Identity:
            - contactId: \(contact.id ?? "")
            - displayName: \(contact.displayName)
            - googlePersonId: \(contact.googlePersonId ?? "")
            - primaryPhone: \(contact.primaryPhone ?? "")
            - primaryEmail: \(contact.primaryEmail ?? "")
            """
            parts.append(info)
        }

        if let context = context?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty {
            parts.append(context)
        }

        guard !parts.isEmpty else { return nil }

        return [
            "<chat_context>",
            parts.joined(separator: "\n\n"),
            "</chat_context>"
        ]
        .joined(separator: "\n")
    }

    private func composeContextAndMessages(
        context: String?,
        messages: String
    ) -> String {
        [context, messages]
            .compactMap { value in
                guard let value else { return nil }
                return value.isEmpty ? nil : value
            }
            .joined(separator: "\n\n")
    }

    private func renderMessages(
        _ messages: [ChatMessage],
        assistantName: String
    ) -> String {
        let rendered = messages.map { renderMessage($0, assistantName: assistantName) }

        guard !rendered.isEmpty else {
            return Self.emptyResponse
        }

        return rendered.joined(separator: "\n\n")
    }

    private func renderMessage(
        _ message: ChatMessage,
        assistantName: String
    ) -> String {
        let attributes = renderMessageAttributes(for: message, assistantName: assistantName)
        let body = formattedBody(for: message)

        return [
            "<message\(attributes)>",
            body,
            "</message>"
        ]
        .joined(separator: "\n")
    }

    private func renderMessageAttributes(
        for message: ChatMessage,
        assistantName: String
    ) -> String {
        var attributes: [String] = []

        if let authorAttribute = messageAuthorAttribute(for: message, assistantName: assistantName) {
            attributes.append(authorAttribute)
        }

        if let date = message.dateTime {
            attributes.append("when=\"\(formattedDateTime(date))\"")
        }

        return " " + attributes.joined(separator: " ")
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func messageAuthorAttribute(
        for message: ChatMessage,
        assistantName: String
    ) -> String? {
        if message.direction == .sent {
            if message.sentByAssistant == true {
                return "sent by=\"\(assistantName)\""
            }

            return "sent by=\"Client\""
        }

        let author = message.author
        if let author, !author.isEmpty {
            return "received by=\"\(author)\""
        }

        return "received"
    }

    private func formattedReplyContext(for message: ChatMessage) -> String? {
        let author = message.quotedMessageAuthor
        let text = message.quotedMessageText

        guard
            let author, !author.isEmpty,
            let text, !text.isEmpty
        else {
            return nil
        }

        return "In reply to \(author): \(text)"
    }

    private func formattedBody(for message: ChatMessage) -> String {
        let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch message.kind {
        case .text:
            return text ?? "empty"
        case .image, .sticker:
            return text ?? "<\(message.kind.rawValue)>\(text ?? "without description")</\(message.kind.rawValue)>"
        default:
            return "<\(message.kind.rawValue)>\(text ?? "without description")</\(message.kind.rawValue)>"
        }
    }
}
