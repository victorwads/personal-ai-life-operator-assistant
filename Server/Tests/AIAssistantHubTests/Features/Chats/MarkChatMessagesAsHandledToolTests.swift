import XCTest
@testable import AIAssistantHub

final class MarkChatMessagesAsHandledToolTests: FirestoreIntegrationTestCase {
    func testExecuteMarksMessagesAndReturnsIssueAwareMessageUsingRealFirestoreState() async throws {
        let repository = FirestoreChatRepository(scope: scope)
        let issueRepository = FirestoreIssueRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")
        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        let tool = MarkChatMessagesAsHandledTool(
            repository: repository,
            issueRepositoryProvider: { issueRepository }
        )
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("issue-1"),
            "readReceipt": .string(try ChatMessagesReadReceiptCoder.encode(
                chatId: "chat-range",
                lastChatMessageId: "m6"
            ))
        ])

        let result = try await tool.execute(call, context: MCPServerContext())

        XCTAssertEqual(result, .string("Marked 6 chat messages as handled for issue issue-1."))

        let updatedMessages = try await repository.listMessages(chatId: "chat-range", limit: 10)
        XCTAssertEqual(updatedMessages.filter { ["m6", "m5", "m4", "m3", "m2", "m1"].contains($0.id ?? "") }.map(\.handled), Array(repeating: true, count: 6))

        let loadedIssue = try await issueRepository.getById("issue-1")
        let issue = try XCTUnwrap(loadedIssue)
        XCTAssertEqual(issue.relatedChatIds, ["chat-range"])
    }

    func testExecuteThrowsForInvalidReadReceipt() async {
        let repository = FirestoreChatRepository(scope: scope)
        let issueRepository = FirestoreIssueRepository(scope: scope)
        let tool = MarkChatMessagesAsHandledTool(
            repository: repository,
            issueRepositoryProvider: { issueRepository }
        )
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("issue-42"),
            "readReceipt": .string("invalid")
        ])

        await XCTAssertThrowsErrorAsync {
            _ = try await tool.execute(call, context: MCPServerContext())
        }
    }

    func testExecuteThrowsForEmptyIssueId() async throws {
        let repository = FirestoreChatRepository(scope: scope)
        let issueRepository = FirestoreIssueRepository(scope: scope)
        let tool = MarkChatMessagesAsHandledTool(
            repository: repository,
            issueRepositoryProvider: { issueRepository }
        )
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-range",
            lastChatMessageId: "m6"
        )
        let call = MCPToolCall(name: "mark_chat_messages_as_handled", arguments: [
            "issueId": .string("   "),
            "readReceipt": .string(readReceipt)
        ])

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
