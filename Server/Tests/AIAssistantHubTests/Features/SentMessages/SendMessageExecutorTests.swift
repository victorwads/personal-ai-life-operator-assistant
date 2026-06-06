import XCTest
@testable import AIAssistantHub

final class SendMessageExecutorTests: XCTestCase {
    @MainActor
    func testExecutePersistsObservedAssistantMessagesImmediately() async throws {
        let settings = SentMessagesSettingsWrapper(
            settings: SettingsStore(
                profileId: "profile-1",
                repository: InMemorySettingsRepository()
            )
        )
        let sentMessageRepository = InMemorySentMessageRepository()
        let chatRepository = SpyChatRepository()
        let observedMessage = ChatMessage(
            id: "wa-msg-1",
            chatId: "wa-chat-1",
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
                chatId: "wa-chat-1",
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
            chatId: "wa-chat-1",
            messages: ["Hello from the assistant"]
        )

        XCTAssertEqual(outcome.sentMessage.status, .sent)
        XCTAssertEqual(outcome.sentMessage.chatMessageIds, ["wa-msg-1"])
        XCTAssertEqual(outcome.receiptCount, 1)
        XCTAssertEqual(outcome.missingReceiptCount, 0)

        XCTAssertEqual(chatRepository.insertedMessages.count, 1)
        let persistedMessage = try XCTUnwrap(chatRepository.insertedMessages.first)
        XCTAssertEqual(persistedMessage.id, "wa-msg-1")
        XCTAssertEqual(persistedMessage.chatId, "wa-chat-1")
        XCTAssertEqual(persistedMessage.text, "Hello from the assistant")
        XCTAssertEqual(persistedMessage.direction, .sent)
        XCTAssertEqual(persistedMessage.handled, true)
        XCTAssertEqual(persistedMessage.sentByAssistant, true)
        XCTAssertEqual(persistedMessage.dateTime, observedMessage.dateTime)
        XCTAssertEqual(persistedMessage.listOrder, observedMessage.listOrder)
    }

    @MainActor
    func testExecuteSkipsChatPersistenceWhenReceiptHasNoObservedMessageId() async throws {
        let settings = SentMessagesSettingsWrapper(
            settings: SettingsStore(
                profileId: "profile-1",
                repository: InMemorySettingsRepository()
            )
        )
        let sentMessageRepository = InMemorySentMessageRepository()
        let chatRepository = SpyChatRepository()
        let sender = StubWhatsAppMessageSender(
            result: WhatsAppMessageSendResult(
                chatId: "wa-chat-1",
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
            chatId: "wa-chat-1",
            messages: ["Still waiting"]
        )

        XCTAssertEqual(outcome.sentMessage.status, .partiallySent)
        XCTAssertEqual(outcome.sentMessage.chatMessageIds, [])
        XCTAssertEqual(outcome.receiptCount, 1)
        XCTAssertEqual(outcome.missingReceiptCount, 1)
        XCTAssertTrue(chatRepository.insertedMessages.isEmpty)
    }
}

private final class InMemorySentMessageRepository: SentMessageRepository {
    private(set) var savedMessages: [SentMessage] = []

    func save(_ model: SentMessage, merge _: Bool) async throws -> SentMessage {
        var model = model
        if model.id == nil {
            model.id = "sent-\(savedMessages.count + 1)"
        }

        if let index = savedMessages.firstIndex(where: { $0.id == model.id }) {
            savedMessages[index] = model
        } else {
            savedMessages.append(model)
        }

        return model
    }
}

private final class SpyChatRepository: ChatRepository {
    private(set) var insertedMessages: [ChatMessage] = []

    func insertMessages(_ messages: [ChatMessage]) async throws -> [ChatMessage] {
        insertedMessages.append(contentsOf: messages)
        return messages
    }

    func getChat(id _: String) async throws -> Chat? { nil }
    func listChats() async throws -> [Chat] { [] }
    func upsertChat(_ chat: Chat) async throws {}
    func updateChatPermission(chatId _: String, permission _: ChatPermission?) async throws {}
    func deleteChat(id _: String) async throws {}
    func deleteAllChatsAndMessages() async throws {}
    func listUnhandledChats(limit _: Int?, permissionMode _: ChatPermissionMode) async throws -> [Chat] { [] }
    func listMessages(chatId _: String, limit _: Int?) async throws -> [ChatMessage] { [] }
    func markMessagesHandled(ids _: [String]) async throws {}
    func markMessagesHandledThrough(chatId _: String, lastChatMessageId _: String) async throws -> Int { 0 }
    func markMessagesUnhandledFrom(chatId _: String, firstChatMessageId _: String) async throws -> Int { 0 }
    func existingMessageIds(chatId _: String) async throws -> Set<String> { [] }
    func deleteMessage(id _: String) async throws {}
    func deleteChatMessages(chatId _: String) async throws {}
    func deleteChatAndMessages(chatId _: String) async throws {}
    func countUnhandledMessages(chatId _: String) async throws -> Int { 0 }
    func updateUnhandledCount(chatId _: String, count _: Int?) async throws {}
}

private struct StubWhatsAppMessageSender: WhatsAppMessageSending {
    let result: WhatsAppMessageSendResult

    func sendMessages(_: WhatsAppMessageSendRequest) async throws -> WhatsAppMessageSendResult {
        result
    }
}

private final class InMemorySettingsRepository: SettingsRepository {
    private var documents: [String: SettingsDocument] = [:]

    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        documents[scopeName] ?? SettingsDocument(scopeName: scopeName, values: [:])
    }

    func loadAllScopes() async throws -> [SettingsDocument] {
        Array(documents.values)
    }

    func saveScope(_ scopeName: String, values: [String: String]) async throws {
        documents[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func getValue(scopeName: String, key: String) async throws -> String? {
        documents[scopeName]?.values[key]
    }

    func setValue(scopeName: String, key: String, value: String) async throws {
        var values = documents[scopeName]?.values ?? [:]
        values[key] = value
        documents[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func deleteValue(scopeName: String, key: String) async throws {
        var values = documents[scopeName]?.values ?? [:]
        values.removeValue(forKey: key)
        documents[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func observeScope(_: String, listener _: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }

    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        listener(Array(documents.values))
        return FirestoreListenerToken {}
    }
}
