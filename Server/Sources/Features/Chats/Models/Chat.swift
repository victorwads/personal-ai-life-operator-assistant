import Foundation

struct Chat: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var title: String
    var permission: ChatPermission?
    var listOrder: Int?
    var lastMessagePreview: String?
    var lastMessageTimeText: String?
    var unreadCount: Int
    var unhandledCount: Int = 0
    var stateHash: String

    var _createdAt: Date? = nil
    var _updatedAt: Date? = nil
}
