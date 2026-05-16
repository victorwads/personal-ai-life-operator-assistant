import Foundation

struct WhatsAppCurrentConversationReader {
    private let parser = WhatsAppCurrentConversationParser()

    func read(
        from accessibilityObject: AccessibilityObject,
        selectedChatName: String?,
        limit: Int
    ) -> WhatsAppCurrentConversationState {
        parser.parse(from: accessibilityObject, selectedChatName: selectedChatName, limit: limit)
    }
}
