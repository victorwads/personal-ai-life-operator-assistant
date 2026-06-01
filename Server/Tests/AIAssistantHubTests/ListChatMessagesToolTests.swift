import XCTest
@testable import AIAssistantHub

final class ListChatMessagesToolTests: XCTestCase {
    func testExecuteReturnsMessagesInRepositoryOrderWithDirectionAndListOrder() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-1",
            title: "Chat 1",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-1"
        )
        repository.messagesToReturn = [
            ChatMessage(
                id: "m11",
                chatId: "chat-1",
                author: "Me",
                text: "11",
                kind: .text,
                direction: .sent,
                listOrder: 11,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            ),
            ChatMessage(
                id: "m10",
                chatId: "chat-1",
                author: "Me",
                text: "10",
                kind: .text,
                direction: .sent,
                listOrder: 10,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            ),
            ChatMessage(
                id: "m9",
                chatId: "chat-1",
                author: "Other",
                text: "9",
                kind: .text,
                direction: .received,
                listOrder: 9,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: false
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: [
            "chatId": .string("chat-1"),
            "limit": .int(6)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())
        guard case let .object(payload) = result else {
            XCTFail("Expected object payload")
            return
        }

        XCTAssertEqual(payload["chatId"], .string("chat-1"))
        XCTAssertEqual(payload["count"], .int(3))
        XCTAssertEqual(repository.listMessagesLimit, 6)

        guard case let .array(messages)? = payload["messages"] else {
            XCTFail("Expected messages array")
            return
        }

        XCTAssertEqual(messageField(messages[0], "id"), .string("m11"))
        XCTAssertEqual(messageField(messages[0], "direction"), .string("sent"))
        XCTAssertEqual(messageField(messages[0], "listOrder"), .int(11))

        XCTAssertEqual(messageField(messages[1], "id"), .string("m10"))
        XCTAssertEqual(messageField(messages[1], "direction"), .string("sent"))
        XCTAssertEqual(messageField(messages[1], "listOrder"), .int(10))

        XCTAssertEqual(messageField(messages[2], "id"), .string("m9"))
        XCTAssertEqual(messageField(messages[2], "direction"), .string("received"))
        XCTAssertEqual(messageField(messages[2], "listOrder"), .int(9))
    }

    func testExecuteMarksUnhandledMessagesAsHandled() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-2",
            title: "Chat 2",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-2"
        )
        repository.messagesToReturn = [
            ChatMessage(
                id: "m1",
                chatId: "chat-2",
                author: nil,
                text: "hello",
                kind: .text,
                direction: .received,
                listOrder: 1,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: false
            ),
            ChatMessage(
                id: "m2",
                chatId: "chat-2",
                author: nil,
                text: "done",
                kind: .text,
                direction: .sent,
                listOrder: 2,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-2")])
        _ = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(repository.markedHandledIds, ["m1"])
        XCTAssertEqual(repository.updatedUnhandledCountChatId, "chat-2")
    }

    func testExecuteThrowsWhenChatIsDeniedByPermissions() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-3",
            title: "Chat 3",
            permission: .denied,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-3"
        )

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-3")])

        await XCTAssertThrowsErrorAsync {
            _ = try await tool.execute(call, context: MCPServerContext())
        }
    }

    private func messageField(_ value: MCPJSONValue, _ key: String) -> MCPJSONValue? {
        guard case let .object(object) = value else { return nil }
        return object[key]
    }
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: @escaping () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected error but expression succeeded.", file: file, line: line)
        } catch {}
    }
}

private final class ChatRepositorySpy: ChatRepository {
    var chatToReturn: Chat?
    var messagesToReturn: [ChatMessage] = []
    var listMessagesLimit: Int?
    var markedHandledIds: [String] = []
    var updatedUnhandledCountChatId: String?

    func getChat(id _: String) async throws -> Chat? { chatToReturn }
    func listChats() async throws -> [Chat] { [] }
    func upsertChat(_: Chat) async throws {}
    func deleteChat(id _: String) async throws {}
    func deleteAllChatsAndMessages() async throws {}
    func listUnhandledChats(limit _: Int?) async throws -> [Chat] { [] }
    func listMessages(chatId _: String, limit: Int?) async throws -> [ChatMessage] {
        listMessagesLimit = limit
        return messagesToReturn
    }
    func insertMessages(_: [ChatMessage]) async throws -> [ChatMessage] { [] }
    func markMessagesHandled(ids: [String]) async throws { markedHandledIds = ids }
    func existingMessageIds(chatId _: String) async throws -> Set<String> { [] }
    func deleteMessage(id _: String) async throws {}
    func deleteChatAndMessages(chatId _: String) async throws {}
    func countUnhandledMessages(chatId _: String) async throws -> Int { 0 }
    func updateUnhandledCount(chatId: String, count _: Int?) async throws { updatedUnhandledCountChatId = chatId }
}
