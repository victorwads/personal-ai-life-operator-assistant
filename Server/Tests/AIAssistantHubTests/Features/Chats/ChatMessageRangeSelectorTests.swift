import XCTest
@testable import AIAssistantHub

final class ChatMessageRangeSelectorTests: FirestoreIntegrationTestCase {
    func testMarkMessagesHandledThroughUsesReceiptBoundaryAndRealFirestoreState() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")

        let messages = try await repository.listUnhandledMessages(chatId: "chat-range", limit: 10)
        let selectedIds = try ChatMessageRangeSelector.messageIDs(
            in: messages,
            from: "m5",
            direction: .handledThrough,
            chatId: "chat-range"
        )

        XCTAssertEqual(selectedIds, ["m5", "m3", "m1"])

        let updatedCount = try await repository.markMessagesHandledThrough(
            chatId: "chat-range",
            lastChatMessageId: "m5"
        )

        XCTAssertEqual(updatedCount, 3)

        let after = try await repository.listMessages(chatId: "chat-range", limit: 10)
        XCTAssertEqual(after.filter { selectedIds.contains($0.id ?? "") }.map(\.handled), Array(repeating: true, count: 3))
        let unhandledCountAfterHandling = try await repository.countUnhandledMessages(chatId: "chat-range")
        XCTAssertEqual(unhandledCountAfterHandling, 2)
    }

    func testMarkMessagesUnhandledFromUsesReceiptBoundaryAndRealFirestoreState() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")

        let messages = try await repository.listMessages(chatId: "chat-range", limit: 10)
            .filter { $0.handled }
        let selectedIds = try ChatMessageRangeSelector.messageIDs(
            in: messages,
            from: "m6",
            direction: .unhandledFrom,
            chatId: "chat-range"
        )

        XCTAssertEqual(selectedIds, ["m9", "m7", "m6"])

        let updatedCount = try await repository.markMessagesUnhandledFrom(
            chatId: "chat-range",
            firstChatMessageId: "m6"
        )

        XCTAssertEqual(updatedCount, 3)

        let after = try await repository.listMessages(chatId: "chat-range", limit: 10)
        XCTAssertEqual(after.filter { selectedIds.contains($0.id ?? "") }.map(\.handled), Array(repeating: false, count: 3))
        let unhandledCountAfterUnhandling = try await repository.countUnhandledMessages(chatId: "chat-range")
        XCTAssertEqual(unhandledCountAfterUnhandling, 8)
    }

    func testSetMessageHandledUpdatesChatUnhandledCount() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")

        try await repository.setMessageHandled(
            chatId: "chat-range",
            messageId: "m10",
            handled: true
        )

        let chat = try await repository.getChat(id: "chat-range")
        XCTAssertEqual(chat?.unhandledCount, 4)

        let unhandledCount = try await repository.countUnhandledMessages(chatId: "chat-range")
        XCTAssertEqual(unhandledCount, 4)
    }

    func testMarkAllMessagesHandledClearsUnhandledCount() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")

        let changedCount = try await repository.markAllMessagesHandled(chatId: "chat-range")
        XCTAssertEqual(changedCount, 5)

        let chat = try await repository.getChat(id: "chat-range")
        XCTAssertEqual(chat?.unhandledCount, 0)

        let messages = try await repository.listMessages(chatId: "chat-range", limit: 10)
        XCTAssertTrue(messages.allSatisfy(\.handled))
    }

    func testMarkAllUnhandledMessagesHandledUpdatesEveryAffectedChat() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")
        try await fixtureBuilder.importFixture(named: "chat-basic.json")

        let changedCount = try await repository.markAllUnhandledMessagesHandled()
        XCTAssertEqual(changedCount, 7)

        let rangeChat = try await repository.getChat(id: "chat-range")
        let basicChat = try await repository.getChat(id: "chat-1")
        XCTAssertEqual(rangeChat?.unhandledCount, 0)
        XCTAssertEqual(basicChat?.unhandledCount, 0)

        let rangeMessages = try await repository.listMessages(chatId: "chat-range", limit: 20)
        let basicMessages = try await repository.listMessages(chatId: "chat-1", limit: 20)
        XCTAssertTrue(rangeMessages.allSatisfy(\.handled))
        XCTAssertTrue(basicMessages.allSatisfy(\.handled))
    }
}
