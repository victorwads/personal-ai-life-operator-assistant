import XCTest
@testable import AIAssistantHub

final class ListChatMessagesToolTests: FirestoreIntegrationTestCase {
    func testExecuteReturnsPlainTextMessagesInRepositoryOrder() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-messages.json")

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Jarvis" }
        )
        let call = MCPToolCall(name: "whatsapp_list_chat_messages", arguments: [
            "chatId": .string("chat-1"),
            "limit": .int(6)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-1",
            lastChatMessageId: "m26"
        )
        guard case let .string(text) = result else {
            return XCTFail("Expected string response.")
        }

        XCTAssertTrue(text.contains("readReceipt: \(readReceipt)"))
        XCTAssertTrue(text.contains("<chat_context>"))
        XCTAssertTrue(text.contains("Rene is a close family contact."))
        XCTAssertTrue(text.contains("<message received by=\"Other\" when=\"07:07, 08/06/2026\">\n7-old\n</message>"))
        XCTAssertTrue(text.contains("<message sent by=\"Jarvis\" when=\"07:26, 08/06/2026\">\n11\n</message>"))
        XCTAssertTrue(text.contains("<unknown>without description</unknown>"))
        XCTAssertTrue(text.contains("Showing the latest 20 messages out of 26 total messages in this chat."))
        XCTAssertTrue(text.contains("To mark these messages as handled, call whatsapp_mark_chat_messages_as_handled with this readReceipt and an issueId."))
    }

    func testExecuteRaisesRequestedLimitToUnhandledMessageMinimum() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-messages.json")

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "whatsapp_list_chat_messages", arguments: [
            "chatId": .string("chat-1"),
            "limit": .int(10)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-1",
            lastChatMessageId: "m26"
        )

        guard case let .string(text) = result else {
            return XCTFail("Expected string response.")
        }

        XCTAssertTrue(text.contains("readReceipt: \(readReceipt)"))
        XCTAssertTrue(text.contains("Showing the latest 20 messages out of 26 total messages in this chat."))
    }

    func testExecuteFormatsDateFallbackAuthorAndReplyContext() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-messages-date.json")

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "whatsapp_list_chat_messages", arguments: ["chatId": .string("chat-4")])
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

                Showing the latest 1 messages out of 1 total messages in this chat.

                To mark these messages as handled, call whatsapp_mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
    }
}
