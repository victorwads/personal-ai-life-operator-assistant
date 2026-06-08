import Foundation

private enum ChatMessageField {
    static let chatId = "chatId"
    static let listOrder = "listOrder"
    static let handled = "handled"
}

enum ChatMessageRangeOperation {
    case handledThrough
    case unhandledFrom
}

private enum ChatField {
    static let permission = "permission"
    static let stateHash = "stateHash"
    static let unhandledCount = "unhandledCount"
    static let unreadCount = "unreadCount"
    static let lastMessagePreview = "lastMessagePreview"
    static let lastMessageLocalMediaPath = "lastMessageLocalMediaPath"
    static let lastMessageTimeText = "lastMessageTimeText"
}

final class FirestoreChatRepository: ChatRepository {
    private enum MessageSort {
        static let newestFirst = [
            FirestoreRepositorySort(field: FirestoreRepositoryMetadataField.createdAt, descending: true),
            FirestoreRepositorySort(field: ChatMessageField.listOrder, descending: true)
        ]
    }

    private final class ChatStore: FirestoreRepository<Chat> {
        init(scope: FirebaseProfileScope) {
            super.init(
                entityName: "Chat",
                path: .profileScoped(scope: scope, collection: "Chats"),
                readSource: .cacheOnly
            )
        }
    }

    private final class MessageStore: FirestoreRepository<ChatMessage> {
        init(scope: FirebaseProfileScope) {
            super.init(
                entityName: "ChatMessage",
                path: .profileScoped(scope: scope, collection: "ChatMessages"),
                readSource: .cacheOnly
            )
        }
    }

    private let chatStore: ChatStore
    private let messageStore: MessageStore

    init(scope: FirebaseProfileScope) {
        self.chatStore = ChatStore(scope: scope)
        self.messageStore = MessageStore(scope: scope)
    }

    func getChat(id: String) async throws -> Chat? {
        try await chatStore.getById(id)
    }

    func listChats() async throws -> [Chat] {
        let chats = try await chatStore.query(
            sortedBy: [
                FirestoreRepositorySort(field: "lastDigestedAt", descending: true),
                FirestoreRepositorySort(field: "listOrder", descending: false)
            ],
            includeDeleted: false
        )
        return chats.sorted(by: compareChatsForListOrder)
    }

    func upsertChat(_ chat: Chat) async throws {
        _ = try await chatStore.save(chat, merge: true)
    }

    func updateChatPermission(chatId: String, permission: ChatPermission?) async throws {
        try await chatStore.update(
            id: chatId,
            data: [
                ChatField.permission: permission?.rawValue ?? NSNull(),
                ChatField.stateHash: ""
            ]
        )
    }

    func deleteChat(id: String) async throws {
        try await chatStore.delete(id)
    }

    func deleteAllChatsAndMessages() async throws {
        let messageIds = try await messageStore.existingIds(matching: [:])
        try await messageStore.deleteAll(ids: Array(messageIds))

        let chatIds = try await chatStore.existingIds(matching: [:])
        try await chatStore.deleteAll(ids: Array(chatIds))
    }

    func listUnhandledChats(limit: Int? = nil, permissionMode: ChatPermissionMode) async throws -> [Chat] {
        let chats = try await listChats()
        let filtered = chats.filter {
            $0.unhandledCount > 0 && ChatPermissionResolver.isChatAllowed($0, mode: permissionMode)
        }
        guard let limit else { return filtered }
        return Array(filtered.prefix(max(1, limit)))
    }

    func listMessages(chatId: String, limit: Int? = nil) async throws -> [ChatMessage] {
        let effectiveLimit = max(1, limit ?? 10)
        return try await messageStore.query(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: MessageSort.newestFirst,
            limit: effectiveLimit
        )
    }

    func insertMessages(_ messages: [ChatMessage]) async throws -> [ChatMessage] {
        guard !messages.isEmpty else {
            return []
        }

        let chatIds = Set(messages.map(\.chatId))
        var existingIds = Set<String>()
        for chatId in chatIds {
            existingIds.formUnion(try await existingMessageIds(chatId: chatId))
        }

        let newMessages = messages.filter { message in
            guard let id = message.id else {
                return true
            }
            return !existingIds.contains(id)
        }

        if newMessages.isEmpty {
            return []
        }

        try await messageStore.saveAll(newMessages)
        let affectedChatIds = Set(newMessages.map(\.chatId))
        for chatId in affectedChatIds {
            if try await getChat(id: chatId) != nil {
                try await updateUnhandledCount(chatId: chatId, count: nil)
            }
        }
        return newMessages
    }

    func markMessagesHandled(ids: [String]) async throws {
        try await messageStore.updateAll(
            ids: ids,
            data: [ChatMessageField.handled: true]
        )
    }

    func setMessageHandled(chatId: String, messageId: String, handled: Bool) async throws {
        try await messageStore.update(
            id: messageId,
            data: [ChatMessageField.handled: handled]
        )
        try await updateUnhandledCount(chatId: chatId, count: nil)
    }

    func setMessagesHandled(chatId: String, messageIds: [String], handled: Bool) async throws -> Int {
        let resolvedIds = Array(Set(messageIds.filter { !$0.isEmpty }))
        guard !resolvedIds.isEmpty else {
            return 0
        }

        try await messageStore.updateAll(
            ids: resolvedIds,
            data: [ChatMessageField.handled: handled]
        )
        try await updateUnhandledCount(chatId: chatId, count: nil)
        return resolvedIds.count
    }

    func markAllMessagesHandled(chatId: String) async throws -> Int {
        let ids = try await messageStore.existingIds(
            matching: [
                ChatMessageField.chatId: chatId,
                ChatMessageField.handled: false
            ]
        )

        guard !ids.isEmpty else {
            try await updateUnhandledCount(chatId: chatId, count: 0)
            return 0
        }

        try await messageStore.updateAll(
            ids: Array(ids),
            data: [ChatMessageField.handled: true]
        )
        try await updateUnhandledCount(chatId: chatId, count: 0)
        return ids.count
    }

    func markMessagesHandledThrough(chatId: String, lastChatMessageId: String) async throws -> Int {
        let messages = try await messageStore.query(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: MessageSort.newestFirst
        )

        let ids = try ChatMessageRangeSelector.messageIDs(
            in: messages,
            from: lastChatMessageId,
            direction: .handledThrough,
            chatId: chatId
        )
        try await messageStore.updateAll(
            ids: ids,
            data: [ChatMessageField.handled: true]
        )
        if !ids.isEmpty {
            try await updateUnhandledCount(chatId: chatId, count: nil)
        }
        return ids.count
    }

    func markMessagesUnhandledFrom(chatId: String, firstChatMessageId: String) async throws -> Int {
        let messages = try await messageStore.query(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: MessageSort.newestFirst
        )

        let ids = try ChatMessageRangeSelector.messageIDs(
            in: messages,
            from: firstChatMessageId,
            direction: .unhandledFrom,
            chatId: chatId
        )
        try await messageStore.updateAll(
            ids: ids,
            data: [ChatMessageField.handled: false]
        )
        if !ids.isEmpty {
            try await updateUnhandledCount(chatId: chatId, count: nil)
        }
        return ids.count
    }

    func observeMessages(
        chatId: String,
        onChange: @escaping @Sendable () -> Void
    ) -> FirestoreListenerToken {
        messageStore.observe(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: MessageSort.newestFirst,
            listener: onChange
        )
    }

    func existingMessageIds(chatId: String) async throws -> Set<String> {
        try await messageStore.existingIds(
            matching: [ChatMessageField.chatId: chatId]
        )
    }

    func deleteMessage(id: String) async throws {
        guard let message = try await messageStore.getById(id) else {
            return
        }

        try await messageStore.delete(id)
        try await refreshChatSummary(chatId: message.chatId)
    }

    func deleteChatMessages(chatId: String) async throws {
        let messageIds = try await messageStore.existingIds(
            matching: [ChatMessageField.chatId: chatId]
        )
        try await messageStore.deleteAll(ids: Array(messageIds))
        try await refreshChatSummary(chatId: chatId, resetUnreadCount: true)
    }

    func deleteChatAndMessages(chatId: String) async throws {
        try await deleteChatMessages(chatId: chatId)
        try await chatStore.delete(chatId)
    }

    func countUnhandledMessages(chatId: String) async throws -> Int {
        try await messageStore.count(
            matching: [
                ChatMessageField.chatId: chatId,
                ChatMessageField.handled: false
            ]
        )
    }

    func updateUnhandledCount(chatId: String, count: Int?) async throws {
        let resolvedCount: Int
        if let count {
            resolvedCount = count
        } else {
            resolvedCount = try await countUnhandledMessages(chatId: chatId)
        }
        try await chatStore.updateAll(
            ids: [chatId],
            data: [ChatField.unhandledCount: max(0, resolvedCount)]
        )
    }

    func setMessageSentByAssistant(chatId: String, messageId: String, sentByAssistant: Bool) async throws {
        try await messageStore.update(
            id: messageId,
            data: ["sentByAssistant": sentByAssistant]
        )
    }

    private func refreshChatSummary(chatId: String, resetUnreadCount: Bool = false) async throws {
        let remainingMessages = try await messageStore.query(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: MessageSort.newestFirst,
            limit: 1
        )
        let latestMessage = remainingMessages.first
        let preview = latestMessage.map(previewText(for:))
        let mediaPath = latestMessage?.localMediaPaths.first
        let timeText = latestMessage?.dateTime?.formatted(date: .abbreviated, time: .shortened)
        let unhandledCount = try await countUnhandledMessages(chatId: chatId)

        var data: [String: Any] = [
            ChatField.stateHash: "",
            ChatField.unhandledCount: max(0, unhandledCount),
            ChatField.lastMessagePreview: preview ?? NSNull(),
            ChatField.lastMessageLocalMediaPath: mediaPath ?? NSNull(),
            ChatField.lastMessageTimeText: timeText ?? NSNull()
        ]

        if resetUnreadCount {
            data[ChatField.unreadCount] = 0
        }

        try await chatStore.update(id: chatId, data: data)
    }

    private func previewText(for message: ChatMessage) -> String? {
        switch message.kind {
        case .image:
            return "[Image]"
        case .sticker:
            return "[Sticker]"
        default:
            let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let text, !text.isEmpty {
                return text
            }
            return "[\(message.kind.rawValue)]"
        }
    }

    private func compareChatsForListOrder(_ lhs: Chat, _ rhs: Chat) -> Bool {
        switch (lhs.lastDigestedAt, rhs.lastDigestedAt) {
        case let (left?, right?):
            if left != right {
                return left > right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        let leftOrder = lhs.listOrder ?? Int.max
        let rightOrder = rhs.listOrder ?? Int.max
        if leftOrder != rightOrder {
            return leftOrder < rightOrder
        }

        let leftId = lhs.id ?? ""
        let rightId = rhs.id ?? ""
        return leftId < rightId
    }
}

enum ChatMessageRangeSelector {
    static func messageIDs(
        in messages: [ChatMessage],
        from messageId: String,
        direction: ChatMessageRangeOperation,
        chatId: String
    ) throws -> [String] {
        guard let boundaryIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            throw ChatMessageRangeOperationError.messageNotFound(
                chatId: chatId,
                messageId: messageId,
                operation: direction
            )
        }

        switch direction {
        case .handledThrough:
            return try messageIDs(in: messages[boundaryIndex...])
        case .unhandledFrom:
            return try messageIDs(in: messages[0...boundaryIndex])
        }
    }

    private static func messageIDs(in messages: ArraySlice<ChatMessage>) throws -> [String] {
        try messages.map { message in
            guard let id = message.id, !id.isEmpty else {
                throw ChatMessageRangeOperationError.missingMessageID
            }
            return id
        }
    }
}

enum ChatMessageRangeOperationError: LocalizedError {
    case messageNotFound(chatId: String, messageId: String, operation: ChatMessageRangeOperation)
    case missingMessageID

    var errorDescription: String? {
        switch self {
        case let .messageNotFound(chatId, messageId, operation):
            let description: String
            switch operation {
            case .handledThrough:
                description = "No unhandled chat message with id '\(messageId)' was found in chat '\(chatId)'."
            case .unhandledFrom:
                description = "No handled chat message with id '\(messageId)' was found in chat '\(chatId)'."
            }
            return description
        case .missingMessageID:
            return "Chat message id is missing."
        }
    }
}
