import Foundation

struct WhatsAppConversationListReader {
    private let parser = WhatsAppConversationListParser()

    func read(from accessibilityObject: AccessibilityObject) -> [ConversationSummary] {
        parser.parseConversations(from: accessibilityObject)
    }

    func candidates(from accessibilityObject: AccessibilityObject) -> [RawAXNode] {
        parser.conversationCandidates(from: accessibilityObject)
    }
}
