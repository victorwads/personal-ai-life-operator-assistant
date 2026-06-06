import XCTest
@testable import AIAssistantHub

final class ListChatsBySearchToolTests: XCTestCase {
    func testExecuteReturnsTextualMatchesFromTitleAndLastMessagePreview() async throws {
        let repository = ChatRepositorySpy()
        repository.chatsToReturn = [
            makeChat(
                id: "chat-1",
                title: "Leonardo",
                preview: "Tudo certo por aqui"
            ),
            makeChat(
                id: "chat-2",
                title: "Padaria da esquina",
                preview: "Fala com Leonardo depois"
            ),
            makeChat(
                id: "chat-3",
                title: "Outros",
                preview: "Sem relação"
            )
        ]

        let tool = ListChatsBySearchTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "list_chats_by_search", arguments: [
            "query": .string("leonardo"),
            "limit": .int(10)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(
            result,
            .string(
                """
                Status: 2 chats encontrados para "leonardo"

                1. Leonardo | chat-1
                2. Padaria da esquina | chat-2
                """
            )
        )
    }

    func testExecuteFallsBackToLatestTenChatsWhenNoMatchesAreFound() async throws {
        let repository = ChatRepositorySpy()
        repository.chatsToReturn = (1...12).map { index in
            makeChat(
                id: "chat-\(index)",
                title: "Chat \(index)",
                preview: "Mensagem \(index)"
            )
        }

        let tool = ListChatsBySearchTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "list_chats_by_search", arguments: [
            "query": .string("sem-resultado")
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        let expectedListing = repository.chatsToReturn.prefix(10).enumerated().map { index, chat in
            "\(index + 1). \(chat.title) | \(chat.id ?? "")"
        }.joined(separator: "\n")

        XCTAssertEqual(
            result,
            .string(
                """
                Status: nenhum chat encontrado para "sem-resultado"

                Últimas 10 conversas:
                \(expectedListing)
                """
            )
        )
    }

    private func makeChat(id: String, title: String, preview: String?) -> Chat {
        Chat(
            id: id,
            title: title,
            permission: nil,
            listOrder: nil,
            lastMessagePreview: preview,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-\(id)"
        )
    }
}

private final class ChatRepositorySpy: ChatRepository {
    var chatsToReturn: [Chat] = []

    func getChat(id _: String) async throws -> Chat? { nil }
    func listChats() async throws -> [Chat] { chatsToReturn }
    func upsertChat(_: Chat) async throws {}
    func updateChatPermission(chatId _: String, permission _: ChatPermission?) async throws {}
    func deleteChat(id _: String) async throws {}
    func deleteAllChatsAndMessages() async throws {}
    func listUnhandledChats(limit _: Int?, permissionMode _: ChatPermissionMode) async throws -> [Chat] { [] }
    func listMessages(chatId _: String, limit _: Int?) async throws -> [ChatMessage] { [] }
    func insertMessages(_: [ChatMessage]) async throws -> [ChatMessage] { [] }
    func markMessagesHandled(ids _: [String]) async throws {}
    func markMessagesHandledThrough(chatId _: String, lastChatMessageId _: String) async throws -> Int { 0 }
    func markMessagesUnhandledFrom(chatId _: String, firstChatMessageId _: String) async throws -> Int { 0 }
    func existingMessageIds(chatId _: String) async throws -> Set<String> { [] }
    func deleteMessage(id _: String) async throws {}
    func deleteChatMessages(chatId _: String) async throws {}
    func deleteChatAndMessages(chatId _: String) async throws {}
    func countUnhandledMessages(chatId _: String) async throws -> Int { 0 }
    func updateUnhandledCount(chatId _: String, count _: Int?) async throws {}
}
