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
        let call = MCPToolCall(name: "list_chat_messages", arguments: [
            "chatId": .string("chat-1"),
            "limit": .int(6)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-1",
            lastChatMessageId: "m2"
        )

        XCTAssertEqual(
            result,
            .string(
                """
                readReceipt: \(readReceipt)

                <message received by="Other" when="07:02, 08/06/2026">
                2-old
                </message>

                <message received by="Other" when="07:03, 08/06/2026">
                3-old
                </message>

                <message received by="Other" when="07:04, 08/06/2026">
                4-old
                </message>

                <message received by="Other" when="07:05, 08/06/2026">
                5-old
                </message>

                <message received by="Other" when="07:06, 08/06/2026">
                6-old
                </message>

                <message received by="Other" when="07:07, 08/06/2026">
                7-old
                </message>

                <message received by="Other" when="07:08, 08/06/2026">
                8-old
                </message>

                <message received by="Other" when="07:09, 08/06/2026">
                9-old
                </message>

                <message received by="Other" when="07:10, 08/06/2026">
                10-old
                </message>

                <message received by="Other" when="07:11, 08/06/2026">
                11-old
                </message>

                <message received by="Other" when="07:12, 08/06/2026">
                12
                </message>

                <message received by="Other" when="07:13, 08/06/2026">
                13
                </message>

                <message received by="Other" when="07:14, 08/06/2026">
                14
                </message>

                <message received by="Other" when="07:15, 08/06/2026">
                15
                </message>

                <message received by="Other" when="07:16, 08/06/2026">
                16
                </message>

                <message received by="Other" when="07:17, 08/06/2026">
                17
                </message>

                <message received by="Other" when="07:18, 08/06/2026">
                18
                </message>

                <message received by="Other" when="07:19, 08/06/2026">
                19
                </message>

                <message received by="Other" when="07:20, 08/06/2026">
                20
                </message>

                <message received when="07:21, 08/06/2026">
                <sticker>without description</sticker>
                </message>

                <message received by="Other" when="07:22, 08/06/2026">
                Cardapio de hoje
                </message>

                <message received by="Other" when="07:24, 08/06/2026">
                9
                </message>

                <message sent by="Client" when="07:25, 08/06/2026">
                10
                </message>

                <message sent by="Jarvis" when="07:26, 08/06/2026">
                11
                </message>

                To mark these messages as handled, call mark_chat_messages_as_handled with this readReceipt and an issueId.
                """
            )
        )
    }

    func testExecuteRaisesRequestedLimitToUnhandledMessageMinimum() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-messages.json")

        let tool = ListChatMessagesTool(
            repository: repository,
            permissionModeProvider: { .allowAllExceptDenied },
            assistantNameProvider: { "Assistant" }
        )
        let call = MCPToolCall(name: "list_chat_messages", arguments: [
            "chatId": .string("chat-1"),
            "limit": .int(10)
        ])

        let result = try await tool.execute(call, context: MCPServerContext())
        let readReceipt = try ChatMessagesReadReceiptCoder.encode(
            chatId: "chat-1",
            lastChatMessageId: "m2"
        )

        guard case let .string(text) = result else {
            return XCTFail("Expected string response.")
        }

        XCTAssertTrue(text.contains("readReceipt: \(readReceipt)"))
    }

    func testExecuteFormatsDateFallbackAuthorAndReplyContext() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-list-messages-date.json")

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
}
