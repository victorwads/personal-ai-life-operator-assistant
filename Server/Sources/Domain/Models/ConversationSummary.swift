import Foundation

struct ConversationSummary: Identifiable, Codable, Equatable {
    let id: String
    let accessibilityPath: [Int]
    let name: String
    let unreadCount: Int
    let isPinned: Bool
    let isSelected: Bool
    let lastMessagePreview: String?
    let lastMessageAtText: String?
    let lastMessageDirection: MessageDirection
    let lastMessageStatus: MessageStatus
    let isTyping: Bool

    func replacing(id: String) -> ConversationSummary {
        ConversationSummary(
            id: id,
            accessibilityPath: accessibilityPath,
            name: name,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isSelected: isSelected,
            lastMessagePreview: lastMessagePreview,
            lastMessageAtText: lastMessageAtText,
            lastMessageDirection: lastMessageDirection,
            lastMessageStatus: lastMessageStatus,
            isTyping: isTyping
        )
    }

    var listSignature: String {
        [
            name,
            lastMessagePreview ?? "",
            lastMessageAtText ?? "",
            "\(unreadCount)",
            lastMessageDirection.rawValue,
//            lastMessageStatus.rawValue
        ].joined(separator: "|")
    }
}
