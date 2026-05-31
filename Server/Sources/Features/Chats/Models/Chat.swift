import Foundation

struct Chat: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var title: String
    var listOrder: Int?
    var lastMessagePreview: String?
    var lastMessageTimeText: String?
    var unreadCount: Int
    var unhandledCount: Int = 0
    var stateHash: String
}
