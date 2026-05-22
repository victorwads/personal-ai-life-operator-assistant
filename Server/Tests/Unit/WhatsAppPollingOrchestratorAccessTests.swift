import XCTest

@testable import AssistantMCPServer

@MainActor
final class WhatsAppPollingOrchestratorAccessTests: XCTestCase {
    func test_refresh_filtersBlockedConversations_andDoesNotOpenThem() async {
        let defaults = TestContextFactory.makeDefaults()
        let sendPrefixRepository = MCPSendPrefixRepository(defaults: defaults)
        let memoryStore = WhatsAppMemoryStore(sendPrefixRepository: sendPrefixRepository)

        let blockedName = "Blocked Chat"
        let allowedName = "Allowed Chat"

        let blockedRaw = ConversationSummary(
            id: "chat-blocked",
            accessibilityPath: [],
            name: blockedName,
            unreadCount: 1,
            isPinned: false,
            isSelected: false,
            lastMessagePreview: "nope",
            lastMessageAtText: "10:00",
            lastMessageDirection: .incoming,
            lastMessageStatus: .unknown,
            isTyping: false
        )
        let allowedRaw = ConversationSummary(
            id: "chat-allowed",
            accessibilityPath: [],
            name: allowedName,
            unreadCount: 1,
            isPinned: false,
            isSelected: false,
            lastMessagePreview: "ok",
            lastMessageAtText: "10:01",
            lastMessageDirection: .incoming,
            lastMessageStatus: .unknown,
            isTyping: false
        )

        // Pre-seed the store with the blocked conversation to validate removal behavior.
        memoryStore.replaceConversations([blockedRaw])
        let canonicalBlockedId = memoryStore.conversations.first(where: { $0.name == blockedName })?.id ?? blockedRaw.id

        let blocked = blockedRaw.replacing(id: canonicalBlockedId)
        let allowed = allowedRaw

        let parser = FakeWhatsAppParser()
        parser.conversationsToReturn = [blocked, allowed]
        parser.selectedChatNameByChatId = [
            blocked.id: blocked.name,
            allowed.id: allowed.name
        ]
        parser.readMessagesByChatId = [
            blocked.id: [makeIncomingMessage(id: "m1", chatId: blocked.id)],
            allowed.id: [makeIncomingMessage(id: "m2", chatId: allowed.id)]
        ]

        let interactor = FakeWhatsAppInteractor()
        interactor.onOpenConversation = { conversation in
            parser.activeChatId = conversation.id
        }

        let provider = FakeWhatsAppProvider(kind: .web, parser: parser, interactor: interactor)

        let orchestrator = WhatsAppPollingOrchestrator(
            memoryStore: memoryStore,
            isBlocked: { $0 == blockedName },
            appendLog: { _, _ in }
        )

        await orchestrator.refresh(provider: provider, messageLimit: 10)

        // Blocked conversation is removed from the memory store and never opened.
        XCTAssertFalse(memoryStore.conversations.contains(where: { $0.name == blockedName }))
        XCTAssertFalse(interactor.openedConversationNames.contains(blockedName))

        // Allowed conversation is present and was opened.
        XCTAssertTrue(memoryStore.conversations.contains(where: { $0.name == allowedName }))
        XCTAssertTrue(interactor.openedConversationNames.contains(allowedName))
    }
}

private func makeIncomingMessage(id: String, chatId: String) -> Message {
    Message(
        id: id,
        chatId: chatId,
        direction: .incoming,
        kind: .text,
        text: "hi",
        durationSeconds: nil,
        timestamp: Date(),
        status: .unknown,
        rawAccessibilityText: "hi"
    )
}
