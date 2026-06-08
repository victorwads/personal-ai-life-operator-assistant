import Foundation

struct Chat: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var title: String
    var chatContext: String? = nil
    var permission: ChatPermission?
    var listOrder: Int?
    var lastMessagePreview: String?
    var lastMessageLocalMediaPath: String? = nil
    var lastMessageTimeText: String?
    var unreadCount: Int
    var unhandledCount: Int = 0
    var stateHash: String
    var lastDigestedAt: Date? = nil
}
