import Foundation

private enum ChatMessageField {
    static let chatId = "chatId"
    static let dateTime = "dateTime"
    static let handled = "handled"
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

    func listUnhandledChats(limit: Int? = nil) async throws -> [Chat] {
        let effectiveLimit = max(1, limit ?? 10)
        let pendingMessages = try await messageStore.query(
            matching: [ChatMessageField.handled: false],
            sortedBy: [
                FirestoreRepositorySort(field: "_createdAt", descending: true),
                FirestoreRepositorySort(field: ChatMessageField.dateTime, descending: true)
            ],
            limit: 200
        )

        var orderedChatIds: [String] = []
        var seen = Set<String>()
        for message in pendingMessages {
            if seen.insert(message.chatId).inserted {
                orderedChatIds.append(message.chatId)
            }
            if orderedChatIds.count >= effectiveLimit {
                break
            }
        }

        var chats: [Chat] = []
        chats.reserveCapacity(orderedChatIds.count)
        for chatId in orderedChatIds {
            if let chat = try await getChat(id: chatId) {
                chats.append(chat)
            }
        }
        return chats
    }

    func listMessages(chatId: String, limit: Int? = nil) async throws -> [ChatMessage] {
        let effectiveLimit = max(1, limit ?? 10)
        let messages = try await messageStore.query(
            matching: [ChatMessageField.chatId: chatId],
            sortedBy: [
                FirestoreRepositorySort(field: "_createdAt", descending: true),
                FirestoreRepositorySort(field: ChatMessageField.dateTime, descending: true)
            ],
            limit: effectiveLimit
        )
        return Array(messages.reversed())
    }

    func insertMessages(_ messages: [ChatMessage]) async throws {
        guard !messages.isEmpty else {
            return
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

        try await messageStore.saveAll(newMessages)
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

}
