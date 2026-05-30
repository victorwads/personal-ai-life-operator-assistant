import Foundation

protocol ChatRepository {
    func getChat(id: String) async throws -> Chat?
    func listChats() async throws -> [Chat]
    func upsertChat(_ chat: Chat) async throws
    func deleteChat(id: String) async throws

    func listUnhandledChats(limit: Int?) async throws -> [Chat]
    func listMessages(chatId: String, limit: Int?) async throws -> [ChatMessage]
    func insertMessages(_ messages: [ChatMessage]) async throws
    func markMessagesHandled(ids: [String]) async throws
    func existingMessageIds(chatId: String) async throws -> Set<String>
    func deleteMessage(id: String) async throws
}
