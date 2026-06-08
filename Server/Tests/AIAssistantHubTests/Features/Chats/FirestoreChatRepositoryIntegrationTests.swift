import XCTest
@testable import AIAssistantHub

final class FirestoreChatRepositoryIntegrationTests: FirestoreIntegrationTestCase {
    func testImportFixtureAndMarkMessagesHandledThroughUsesRealFirestoreData() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-basic.json")

        let before = try await repository.listMessages(chatId: "chat-1", limit: 10)
        let unhandledBefore = try await repository.countUnhandledMessages(chatId: "chat-1")
        XCTAssertEqual(before.compactMap(\.id), ["message-3", "message-2", "message-1"])
        XCTAssertEqual(unhandledBefore, 2)

        let updatedCount = try await repository.markMessagesHandledThrough(
            chatId: "chat-1",
            lastChatMessageId: "message-2"
        )

        XCTAssertEqual(updatedCount, 2)

        let after = try await repository.listMessages(chatId: "chat-1", limit: 10)
        XCTAssertEqual(after.filter { !$0.handled }.map(\.id), ["message-3"])

        let chat = try await repository.getChat(id: "chat-1")
        XCTAssertEqual(chat?.unhandledCount, 1)
    }

    func testListChatsUsesScopedProductionPathAndDoesNotLeakAcrossProfiles() async throws {
        let repository = FirestoreChatRepository(scope: scope)
        let otherBuilder = FirestoreFixtureBuilder()
        let otherRepository = FirestoreChatRepository(scope: otherBuilder.scope)

        try await fixtureBuilder.importFixture(named: "chat-scope-local.json")
        try await otherBuilder.importFixture(named: "chat-scope-other.json")

        let localChats = try await repository.listChats()
        let otherChats = try await otherRepository.listChats()

        XCTAssertEqual(localChats.compactMap(\.id), ["chat-local"])
        XCTAssertEqual(otherChats.compactMap(\.id), ["chat-other"])

        try await otherBuilder.clearFixture()
    }

    func testDeleteChatAndMessagesRemovesBothCollections() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-basic.json")

        try await repository.deleteChatAndMessages(chatId: "chat-1")

        let deletedChat = try await repository.getChat(id: "chat-1")
        let remainingMessages = try await repository.listMessages(chatId: "chat-1", limit: 10)
        XCTAssertNil(deletedChat)
        XCTAssertEqual(remainingMessages, [])
    }

    func testDeleteMessageRefreshesChatSummaryFromRemainingMessages() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-basic.json")

        try await repository.deleteMessage(id: "message-3")

        let remainingMessages = try await repository.listMessages(chatId: "chat-1", limit: 10)
        let chat = try await repository.getChat(id: "chat-1")

        XCTAssertEqual(remainingMessages.compactMap(\.id), ["message-2", "message-1"])
        XCTAssertEqual(chat?.stateHash, "")
        XCTAssertEqual(chat?.unhandledCount, 1)
        XCTAssertEqual(chat?.lastMessagePreview, "Middle")
        XCTAssertEqual(chat?.lastMessageLocalMediaPath, nil)
        XCTAssertFalse(chat?.lastMessageTimeText?.isEmpty ?? true)
    }
}
