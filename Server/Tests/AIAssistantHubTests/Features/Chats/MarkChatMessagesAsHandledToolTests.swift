import XCTest
@testable import AIAssistantHub

final class MarkChatMessagesAsHandledToolTests: XCTestCase {
    func testExecuteMarksMessagesAndReturnsIssueAwareMessage() async throws {
        let repository = ChatRepositorySpy()
        repository.markedThroughReturnCount = 3

        let tool = MarkChatMessagesAsHandledTool(repository: repository)
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("issue-42"),
            "readReceipt": .string(try ChatMessagesReadReceiptCoder.encode(
                chatId: "chat-1",
                lastChatMessageId: "message-9"
            ))
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(repository.markedThroughChatId, "chat-1")
        XCTAssertEqual(repository.markedThroughLastChatMessageId, "message-9")
        XCTAssertEqual(result, .string("Marked 3 chat messages as handled for issue issue-42."))
    }

    func testExecuteReturnsNoMessagesWhenRepositoryMarksNothing() async throws {
        let repository = ChatRepositorySpy()

        let tool = MarkChatMessagesAsHandledTool(repository: repository)
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("issue-42"),
            "readReceipt": .string(try ChatMessagesReadReceiptCoder.encode(
                chatId: "chat-1",
                lastChatMessageId: "message-9"
            ))
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(result, .string("No chat messages were marked as handled."))
    }

    func testExecuteThrowsForInvalidReadReceipt() async {
        let repository = ChatRepositorySpy()
        let tool = MarkChatMessagesAsHandledTool(repository: repository)
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("issue-42"),
            "readReceipt": .string("invalid")
        ])

        await XCTAssertThrowsErrorAsync {
            _ = try await tool.execute(call, context: MCPServerContext())
        }
    }

    func testExecuteThrowsForEmptyIssueId() async throws {
        let repository = ChatRepositorySpy()
        let tool = MarkChatMessagesAsHandledTool(repository: repository)
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-1",
            lastChatMessageId: "message-9"
        )
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("   "),
            "readReceipt": .string(readReceipt)
        ])

        await XCTAssertThrowsErrorAsync {
            _ = try await tool.execute(call, context: MCPServerContext())
        }
    }

    private final class ChatRepositorySpy: ChatRepository {
        var markedThroughChatId: String?
        var markedThroughLastChatMessageId: String?
        var markedThroughReturnCount: Int = 0

        func markMessagesHandledThrough(chatId: String, lastChatMessageId: String) async throws -> Int {
            markedThroughChatId = chatId
            markedThroughLastChatMessageId = lastChatMessageId
            return markedThroughReturnCount
        }

        func getChat(id _: String) async throws -> Chat? { nil }
        func listChats() async throws -> [Chat] { [] }
        func upsertChat(_: Chat) async throws {}
        func updateChatPermission(chatId _: String, permission _: ChatPermission?) async throws {}
        func deleteChat(id _: String) async throws {}
        func deleteAllChatsAndMessages() async throws {}
        func listUnhandledChats(limit _: Int?, permissionMode _: ChatPermissionMode) async throws -> [Chat] { [] }
        func listMessages(chatId _: String, limit _: Int?) async throws -> [ChatMessage] { [] }
        func insertMessages(_: [ChatMessage]) async throws -> [ChatMessage] { [] }
        func markMessagesHandled(ids _: [String]) async throws {}
        func markMessagesUnhandledFrom(chatId _: String, firstChatMessageId _: String) async throws -> Int { 0 }
        func existingMessageIds(chatId _: String) async throws -> Set<String> { [] }
        func deleteMessage(id _: String) async throws {}
        func deleteChatMessages(chatId _: String) async throws {}
        func deleteChatAndMessages(chatId _: String) async throws {}
        func countUnhandledMessages(chatId _: String) async throws -> Int { 0 }
        func updateUnhandledCount(chatId _: String, count _: Int?) async throws {}
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
