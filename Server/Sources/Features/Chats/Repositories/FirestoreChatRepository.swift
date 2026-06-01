import Foundation

private enum ChatMessageField {
    static let chatId = "chatId"
    static let listOrder = "listOrder"
    static let handled = "handled"
}

private enum ChatField {
    static let unhandledCount = "unhandledCount"
}

final class FirestoreChatRepository: ChatRepository {
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
        try await chatStore.query(
            sortedBy: [
                FirestoreRepositorySort(field: "_updatedAt", descending: true),
                FirestoreRepositorySort(field: "listOrder", descending: false)
            ],
            includeDeleted: false
        )
    }

    func upsertChat(_ chat: Chat) async throws {
        _ = try await chatStore.save(chat, merge: true)
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

    func listUnhandledChats(limit: Int? = nil) async throws -> [Chat] {
        let chats = try await listChats()
        let filtered = chats.filter { $0.unhandledCount > 0 }
        guard let limit else { return filtered }
        return Array(filtered.prefix(max(1, limit)))
    }

    func listMessages(chatId: String, limit: Int? = nil) async throws -> [ChatMessage] {
        let effectiveLimit = max(1, limit ?? 10)
        let messages = try await messageStore.query(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: [
                FirestoreRepositorySort(field: "_createdAt", descending: true),
                FirestoreRepositorySort(field: ChatMessageField.listOrder, descending: true)
            ],
            limit: effectiveLimit
        )
        return messages
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

    func existingMessageIds(chatId: String) async throws -> Set<String> {
        try await messageStore.existingIds(
            matching: [ChatMessageField.chatId: chatId]
        )
    }

    func deleteMessage(id: String) async throws {
        try await messageStore.delete(id)
    }

    func deleteChatAndMessages(chatId: String) async throws {
        let messageIds = try await messageStore.existingIds(
            matching: [ChatMessageField.chatId: chatId]
        )
        try await messageStore.deleteAll(ids: Array(messageIds))
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
}
