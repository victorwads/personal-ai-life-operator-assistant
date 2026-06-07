import XCTest
@testable import AIAssistantHub

final class ListChatMessagesToolTests: XCTestCase {
    func testExecuteReturnsPlainTextMessagesInRepositoryOrder() async throws {
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
                handled: true,
                sentByAssistant: true
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
                handled: true,
                sentByAssistant: false
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
            ),
            ChatMessage(
                id: "ignored",
                chatId: "chat-1",
                author: nil,
                text: nil,
                kind: .unknown,
                direction: .received,
                listOrder: 8,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            ),
            ChatMessage(
                id: "img1",
                chatId: "chat-1",
                author: "Other",
                text: "Cardapio de hoje",
                kind: .image,
                direction: .received,
                listOrder: 7,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            ),
            ChatMessage(
                id: "sticker1",
                chatId: "chat-1",
                author: nil,
                text: nil,
                kind: .sticker,
                direction: .received,
                listOrder: 6,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Jarvis" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: [
            "chatId": .string("chat-1"),
            "limit": .int(6)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-1",
            lastChatMessageId: "sticker1"
        )

        XCTAssertEqual(repository.listMessagesLimit, 6)
        XCTAssertEqual(
            result,
            .string(
                """
                readReceipt: \(readReceipt)

                <message received>
                <sticker>without description</sticker>
                </message>

                <message received by="Other">
                Cardapio de hoje
                </message>

                <message received by="Other">
                9
                </message>

                <message sent by="Client">
                10
                </message>

                <message sent by="Jarvis">
                11
                </message>

                To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
    }

    func testExecuteRaisesRequestedLimitToUnhandledMessageMinimum() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-2",
            title: "Chat 2",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            unhandledCount: 20,
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
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: [
            "chatId": .string("chat-2"),
            "limit": .int(10)
        ])
        _ = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(repository.markedHandledIds, [])
        XCTAssertNil(repository.updatedUnhandledCountChatId)
        XCTAssertEqual(repository.listMessagesLimit, 25)
    }

    func testExecuteFormatsDateFallbackAuthorAndReplyContext() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-4",
            title: "Chat 4",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-4"
        )
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 5
        components.hour = 1
        components.minute = 31
        components.second = 0

        repository.messagesToReturn = [
            ChatMessage(
                id: "m1",
                chatId: "chat-4",
                author: nil,
                text: "Olá boa noite",
                kind: .text,
                direction: .received,
                listOrder: 1,
                dateTime: try XCTUnwrap(components.date),
                quotedMessageText: "Mensagem anterior",
                quotedMessageAuthor: "DRAKE PIZZAS",
                handled: true
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-4")])
        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-4",
            lastChatMessageId: "m1"
        )

        XCTAssertEqual(
            result,
            .string(
                """
                readReceipt: \(readReceipt)

                <message received when="22:31, 04/06/2026">
                Olá boa noite
                </message>

                To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
    }

    func testExecuteReturnsEmptyMessageWhenNoTextMessagesExist() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-5",
            title: "Chat 5",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-5"
        )
        repository.messagesToReturn = [
            ChatMessage(
                id: "m1",
                chatId: "chat-5",
                author: nil,
                text: nil,
                kind: .unknown,
                direction: .received,
                listOrder: 1,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-5")])
        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-5",
            lastChatMessageId: "m1"
        )

        XCTAssertEqual(
            result,
            .string(
                """
                readReceipt: \(readReceipt)

                No supported messages found.

                To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
    }

    func testExecuteReturnsEmptyReceiptWhenNoMessagesExist() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-5b",
            title: "Chat 5b",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-5b"
        )
        repository.messagesToReturn = []

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-5b")])
        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(result, .string("No supported messages found."))
    }

    func testExecuteUsesAssistantNameForAssistantSentMessages() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-6",
            title: "Chat 6",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-6"
        )
        repository.messagesToReturn = [
            ChatMessage(
                id: "m1",
                chatId: "chat-6",
                author: "Some Raw Author",
                text: "Posso te ajudar em algo mais?",
                kind: .text,
                direction: .sent,
                listOrder: 1,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true,
                sentByAssistant: true
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Drake Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-6")])
        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-6",
            lastChatMessageId: "m1"
        )

        XCTAssertEqual(
            result,
            .string(
                """
                readReceipt: \(readReceipt)

                <message sent by="Drake Assistant">
                Posso te ajudar em algo mais?
                </message>

                To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
    }

    func testExecuteFormatsImageAndStickerFallbackBodies() async throws {
        let repository = ChatRepositorySpy()
        repository.chatToReturn = Chat(
            id: "chat-7",
            title: "Chat 7",
            permission: nil,
            listOrder: nil,
            lastMessagePreview: nil,
            lastMessageTimeText: nil,
            unreadCount: 0,
            stateHash: "hash-7"
        )
        repository.messagesToReturn = [
            ChatMessage(
                id: "m1",
                chatId: "chat-7",
                author: nil,
                text: nil,
                kind: .image,
                direction: .sent,
                listOrder: 2,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true,
                sentByAssistant: false
            ),
            ChatMessage(
                id: "m2",
                chatId: "chat-7",
                author: nil,
                text: "Bom dia",
                kind: .sticker,
                direction: .sent,
                listOrder: 1,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                handled: true,
                sentByAssistant: true
            )
        ]

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Drake Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-7")])
        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-7",
            lastChatMessageId: "m2"
        )

        XCTAssertEqual(
            result,
            .string(
                """
                readReceipt: \(readReceipt)

                <message sent by="Drake Assistant">
                Bom dia
                </message>

                <message sent by="Client">
                <image>without description</image>
                </message>

                To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
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
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: ["chatId": .string("chat-3")])

        await XCTAssertThrowsErrorAsync {
            _ = try await tool.execute(call, context: MCPServerContext())
        }
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
    func updateChatPermission(chatId _: String, permission _: ChatPermission?) async throws {}
    func deleteChat(id _: String) async throws {}
    func deleteAllChatsAndMessages() async throws {}
    func listUnhandledChats(limit _: Int?, permissionMode _: ChatPermissionMode) async throws -> [Chat] { [] }
    func listMessages(chatId _: String, limit: Int?) async throws -> [ChatMessage] {
        listMessagesLimit = limit
        return messagesToReturn
    }
    func insertMessages(_: [ChatMessage]) async throws -> [ChatMessage] { [] }
    func markMessagesHandled(ids: [String]) async throws { markedHandledIds = ids }
    func markMessagesHandledThrough(chatId _: String, lastChatMessageId _: String) async throws -> Int { 0 }
    func markMessagesUnhandledFrom(chatId _: String, firstChatMessageId _: String) async throws -> Int { 0 }
    func existingMessageIds(chatId _: String) async throws -> Set<String> { [] }
    func deleteMessage(id _: String) async throws {}
    func deleteChatMessages(chatId _: String) async throws {}
    func deleteChatAndMessages(chatId _: String) async throws {}
    func countUnhandledMessages(chatId _: String) async throws -> Int { 0 }
    func updateUnhandledCount(chatId: String, count _: Int?) async throws { updatedUnhandledCountChatId = chatId }
}
