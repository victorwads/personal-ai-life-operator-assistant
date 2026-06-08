import XCTest
@testable import AIAssistantHub

final class UpdateChatContextToolTests: FirestoreIntegrationTestCase {
    func testExecuteUpdatesOnlyChatContextField() async throws {
        let repository = FirestoreChatRepository(scope: scope)
        try await fixtureBuilder.importFixture(named: "chat-basic.json")

        guard let originalChat = try await repository.getChat(id: "chat-1") else {
            return XCTFail("Expected chat fixture to exist.")
        }
        let tool = UpdateChatContextTool(repository: repository)
        let context = "Alice is the client's mother. Prefer a caring tone, but stay brief on WhatsApp."

        let result = try await tool.execute(
            MCPToolCall(
                name: "update_chat_context",
                arguments: [
                    "chatId": .string("chat-1"),
                    "context": .string(context)
                ]
            ),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .object([
                "chatId": .string("chat-1"),
                "title": .string("Fixture Chat"),
                "chatContext": .string(context),
                "updated": .bool(true)
            ])
        )

        guard let updatedChat = try await repository.getChat(id: "chat-1") else {
            return XCTFail("Expected updated chat to exist.")
        }
        XCTAssertEqual(updatedChat.chatContext, context)
        XCTAssertEqual(updatedChat.title, originalChat.title)
        XCTAssertEqual(updatedChat.lastMessagePreview, originalChat.lastMessagePreview)
        XCTAssertEqual(updatedChat.unhandledCount, originalChat.unhandledCount)
        XCTAssertEqual(updatedChat.stateHash, originalChat.stateHash)
    }
}
