import Foundation

@testable import AssistantMCPServer

@MainActor
final class FakeWhatsAppInteractor: WhatsAppConversationInteractor {
    private(set) var openedConversationIds: [String] = []
    private(set) var openedConversationNames: [String] = []
    var onOpenConversation: ((ConversationSummary) -> Void)?

    func openConversation(_ conversation: ConversationSummary) async throws {
        openedConversationIds.append(conversation.id)
        openedConversationNames.append(conversation.name)
        onOpenConversation?(conversation)
    }
}

@MainActor
final class FakeWhatsAppParser: WhatsAppConversationParser {
    var conversationsToReturn: [ConversationSummary] = []
    var readMessagesByChatId: [String: [Message]] = [:]
    var selectedChatNameByChatId: [String: String] = [:]
    var activeChatId: String?

    func listConversations() async throws -> [ConversationSummary] {
        conversationsToReturn
    }

    func readMessages(limit: Int) async throws -> (selectedChatName: String?, flow: String?, messages: [Message], composeFocused: Bool, canSendText: Bool) {
        let chatId = activeChatId
        let messages = chatId.flatMap { readMessagesByChatId[$0] } ?? []
        let selectedName = chatId.flatMap { selectedChatNameByChatId[$0] }
        return (selectedChatName: selectedName, flow: nil, messages: Array(messages.prefix(limit)), composeFocused: false, canSendText: true)
    }
}

@MainActor
final class FakeWhatsAppProvider: WhatsAppIntegrationProvider {
    let kind: WhatsAppIntegrationMode
    let parser: WhatsAppConversationParser
    let interactor: WhatsAppConversationInteractor

    init(kind: WhatsAppIntegrationMode, parser: WhatsAppConversationParser, interactor: WhatsAppConversationInteractor) {
        self.kind = kind
        self.parser = parser
        self.interactor = interactor
    }
}
