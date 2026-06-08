import Foundation

protocol ChatRepository {
    func getChat(id: String) async throws -> Chat?
    func listChats() async throws -> [Chat]
    func upsertChat(_ chat: Chat) async throws
    func updateChatPermission(chatId: String, permission: ChatPermission?) async throws
    func deleteChat(id: String) async throws
    func deleteAllChatsAndMessages() async throws

    func listUnhandledChats(limit: Int?, permissionMode: ChatPermissionMode) async throws -> [Chat]
    func listMessages(chatId: String, limit: Int?) async throws -> [ChatMessage]
    func insertMessages(_ messages: [ChatMessage]) async throws -> [ChatMessage]
    func markMessagesHandled(ids: [String]) async throws
    func setMessageHandled(chatId: String, messageId: String, handled: Bool) async throws
    func setMessagesHandled(chatId: String, messageIds: [String], handled: Bool) async throws -> Int
    func markAllMessagesHandled(chatId: String) async throws -> Int
    func markMessagesHandledThrough(chatId: String, lastChatMessageId: String) async throws -> Int
    func markMessagesUnhandledFrom(chatId: String, firstChatMessageId: String) async throws -> Int
    func observeMessages(
        chatId: String,
        onChange: @escaping @Sendable () -> Void
    ) -> FirestoreListenerToken
    func existingMessageIds(chatId: String) async throws -> Set<String>
    func deleteMessage(id: String) async throws
    func deleteChatMessages(chatId: String) async throws
    func deleteChatAndMessages(chatId: String) async throws

    func countUnhandledMessages(chatId: String) async throws -> Int
    func updateUnhandledCount(chatId: String, count: Int?) async throws
}
