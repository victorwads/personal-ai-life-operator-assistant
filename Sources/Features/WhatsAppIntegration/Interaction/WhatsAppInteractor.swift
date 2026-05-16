import Foundation

@MainActor
struct WhatsAppInteractor {
    private let selectionHandler = WhatsAppConversationSelectionHandler()
    private let messageSendHandler = WhatsAppMessageSendHandler()

    @MainActor
    func selectConversation(_ conversation: ConversationSummary, using accessibility: AccessibilityService) throws {
        try selectionHandler.selectConversation(conversation, using: accessibility)
    }

    @MainActor
    func clearComposeIfNeeded(using accessibility: AccessibilityService) throws {
        try messageSendHandler.clearComposeIfNeeded(using: accessibility)
    }

    @MainActor
    func sendMessageConfirmed(
        _ text: String,
        expectedChatName: String,
        using accessibility: AccessibilityService,
        parser: WhatsAppAppParser
    ) async throws -> (snapshot: WhatsAppSnapshot, state: WhatsAppScreenState) {
        try await messageSendHandler.sendMessageConfirmed(
            text,
            expectedChatName: expectedChatName,
            using: accessibility,
            parser: parser
        )
    }
}
