import XCTest
@testable import AIAssistantHub

final class SendMessageExecutorTests: FirestoreIntegrationTestCase {
    @MainActor
    func testExecutePersistsObservedAssistantMessagesImmediately() async throws {
        try await FirestoreFixture.importFixture(scope, "chat-basic.json")

        let settingsStore = SettingsStore(scope: scope)
        try await settingsStore.start()
        let settings = SentMessagesSettingsWrapper(settings: settingsStore)

        let sentMessageRepository = FirestoreSentMessageRepository(scope: scope)
        let chatRepository = FirestoreChatRepository(scope: scope)

        let observedMessage = ChatMessage(
            id: "wa-msg-1",
            chatId: "chat-1", // Match the fixture chat ID
            author: "Assistant",
            text: "Hello from the assistant",
            kind: .text,
            direction: .sent,
            listOrder: 7,
            dateTime: Date(timeIntervalSince1970: 1_717_000_000),
            handled: false,
            sentByAssistant: false
        )
        let sender = StubWhatsAppMessageSender(
            result: WhatsAppMessageSendResult(
                chatId: "chat-1",
                receipts: [
                    WhatsAppMessageSendReceipt(
                        requestedText: "Hello from the assistant",
                        observedMessage: observedMessage
                    )
                ]
            )
        )

        let executor = SendMessageExecutor(
            repository: sentMessageRepository,
            chatRepositoryProvider: { chatRepository },
            settings: settings,
            senderProvider: { sender }
        )

        let outcome = try await executor.execute(
            issueId: "issue-1",
            chatIdentification: "chat-1",
            messages: ["Hello from the assistant"]
        )

        XCTAssertEqual(
            sender.receivedRequests,
            [
                WhatsAppMessageSendRequest(
                    chatId: "chat-1",
                    phone: nil,
                    messages: ["Hello from the assistant"]
                )
            ]
        )

        XCTAssertEqual(outcome.sentMessage.status, .sent)
        XCTAssertEqual(outcome.sentMessage.chatMessageIds, ["wa-msg-1"])
        XCTAssertEqual(outcome.receiptCount, 1)
        XCTAssertEqual(outcome.missingReceiptCount, 0)

        // Validate executor behavior against real repository persistence.
        let persistedMessages = try await chatRepository.listMessages(chatId: "chat-1", limit: 10)
        let persistedMessage = try XCTUnwrap(persistedMessages.first(where: { $0.id == "wa-msg-1" }))
        XCTAssertEqual(persistedMessage.id, "wa-msg-1")
        XCTAssertEqual(persistedMessage.chatId, "chat-1")
        XCTAssertEqual(persistedMessage.text, "Hello from the assistant")
        XCTAssertEqual(persistedMessage.direction, .sent)
        XCTAssertEqual(persistedMessage.handled, true)
        XCTAssertEqual(persistedMessage.sentByAssistant, true)
        XCTAssertEqual(persistedMessage.dateTime?.timeIntervalSince1970, observedMessage.dateTime?.timeIntervalSince1970)
        XCTAssertEqual(persistedMessage.listOrder, observedMessage.listOrder)

        let sentMessages = try await sentMessageRepository.listAll()
        XCTAssertEqual(sentMessages.count, 1)
        let savedSentMessage = try XCTUnwrap(sentMessages.first)
        XCTAssertEqual(savedSentMessage.status, .sent)
        XCTAssertEqual(savedSentMessage.chatMessageIds, ["wa-msg-1"])

        await settingsStore.stop(flushPendingSaves: false)
    }

    @MainActor
    func testExecuteSkipsChatPersistenceWhenReceiptHasNoObservedMessageId() async throws {
        try await FirestoreFixture.importFixture(scope, "chat-basic.json")

        let settingsStore = SettingsStore(scope: scope)
        try await settingsStore.start()
        let settings = SentMessagesSettingsWrapper(settings: settingsStore)

        let sentMessageRepository = FirestoreSentMessageRepository(scope: scope)
        let chatRepository = FirestoreChatRepository(scope: scope)
        let sender = StubWhatsAppMessageSender(
            result: WhatsAppMessageSendResult(
                chatId: "chat-1",
                receipts: [
                    WhatsAppMessageSendReceipt(
                        requestedText: "Still waiting",
                        observedMessage: nil
                    )
                ]
            )
        )

        let executor = SendMessageExecutor(
            repository: sentMessageRepository,
            chatRepositoryProvider: { chatRepository },
            settings: settings,
            senderProvider: { sender }
        )

        let outcome = try await executor.execute(
            issueId: "issue-1",
            chatIdentification: "chat-1",
            messages: ["Still waiting"]
        )

        XCTAssertEqual(outcome.sentMessage.status, .partiallySent)
        XCTAssertEqual(outcome.sentMessage.chatMessageIds, [])
        XCTAssertEqual(outcome.receiptCount, 1)
        XCTAssertEqual(outcome.missingReceiptCount, 1)

        let persistedMessages = try await chatRepository.listMessages(chatId: "chat-1", limit: 10)
        XCTAssertFalse(persistedMessages.contains(where: { $0.text == "Still waiting" }))

        let sentMessages = try await sentMessageRepository.listAll()
        XCTAssertEqual(sentMessages.count, 1)
        let savedSentMessage = try XCTUnwrap(sentMessages.first)
        XCTAssertEqual(savedSentMessage.status, .partiallySent)
        XCTAssertEqual(savedSentMessage.chatMessageIds, [])

        await settingsStore.stop(flushPendingSaves: false)
    }

    @MainActor
    func testExecuteForwardsOptionalPhoneToWhatsAppSender() async throws {
        try await FirestoreFixture.importFixture(scope, "chat-basic.json")

        let settingsStore = SettingsStore(scope: scope)
        try await settingsStore.start()
        let settings = SentMessagesSettingsWrapper(settings: settingsStore)

        let sentMessageRepository = FirestoreSentMessageRepository(scope: scope)
        let chatRepository = FirestoreChatRepository(scope: scope)
        let sender = StubWhatsAppMessageSender(
            result: WhatsAppMessageSendResult(
                chatId: "chat-1",
                receipts: []
            )
        )

        let executor = SendMessageExecutor(
            repository: sentMessageRepository,
            chatRepositoryProvider: { chatRepository },
            settings: settings,
            senderProvider: { sender }
        )

        _ = try await executor.execute(
            issueId: "issue-1",
            chatIdentification: "5511983227673",
            messages: ["Testing phone selection"]
        )

        XCTAssertEqual(
            sender.receivedRequests,
            [
                WhatsAppMessageSendRequest(
                    chatId: nil,
                    phone: "5511983227673",
                    messages: ["Testing phone selection"]
                )
            ]
        )

        await settingsStore.stop(flushPendingSaves: false)
    }
}

@MainActor
final class StubWhatsAppMessageSender: WhatsAppMessageSending, @unchecked Sendable {
    let result: WhatsAppMessageSendResult
    private(set) var receivedRequests: [WhatsAppMessageSendRequest] = []

    init(result: WhatsAppMessageSendResult) {
        self.result = result
    }

    func sendMessages(_ request: WhatsAppMessageSendRequest) async throws -> WhatsAppMessageSendResult {
        receivedRequests.append(request)
        result
    }
}
