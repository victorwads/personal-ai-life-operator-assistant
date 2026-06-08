import XCTest
@testable import AIAssistantHub

final class ChatMessageRangeSelectorTests: FirestoreIntegrationTestCase {
    func testMarkMessagesHandledThroughUsesReceiptBoundaryAndRealFirestoreState() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")

        let messages = try await repository.listMessages(chatId: "chat-range", limit: 10)
        let selectedIds = try ChatMessageRangeSelector.messageIDs(
            in: messages,
            from: "m6",
            direction: .handledThrough,
            chatId: "chat-range"
        )

        XCTAssertEqual(selectedIds, ["m6", "m5", "m4", "m3", "m2", "m1"])

        let updatedCount = try await repository.markMessagesHandledThrough(
            chatId: "chat-range",
            lastChatMessageId: "m6"
        )

        XCTAssertEqual(updatedCount, 6)

        let after = try await repository.listMessages(chatId: "chat-range", limit: 10)
        XCTAssertEqual(after.filter { selectedIds.contains($0.id ?? "") }.map(\.handled), Array(repeating: true, count: 6))
        let unhandledCountAfterHandling = try await repository.countUnhandledMessages(chatId: "chat-range")
        XCTAssertEqual(unhandledCountAfterHandling, 2)
    }

    func testMarkMessagesUnhandledFromUsesReceiptBoundaryAndRealFirestoreState() async throws {
        let repository = FirestoreChatRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "chat-message-range-selector.json")

        let messages = try await repository.listMessages(chatId: "chat-range", limit: 10)
        let selectedIds = try ChatMessageRangeSelector.messageIDs(
            in: messages,
            from: "m5",
            direction: .unhandledFrom,
            chatId: "chat-range"
        )

        XCTAssertEqual(selectedIds, ["m10", "m9", "m8", "m7", "m6", "m5"])

        let updatedCount = try await repository.markMessagesUnhandledFrom(
            chatId: "chat-range",
            firstChatMessageId: "m5"
        )

        XCTAssertEqual(updatedCount, 6)

        let after = try await repository.listMessages(chatId: "chat-range", limit: 10)
        XCTAssertEqual(after.filter { selectedIds.contains($0.id ?? "") }.map(\.handled), Array(repeating: false, count: 6))
        let unhandledCountAfterUnhandling = try await repository.countUnhandledMessages(chatId: "chat-range")
        XCTAssertEqual(unhandledCountAfterUnhandling, 8)
    }
}
