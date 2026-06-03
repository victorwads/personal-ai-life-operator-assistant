import Foundation

struct CrawledChat: Codable, Equatable, Sendable {
    let rawTitle: String
    let unreadCount: Int?
    let lastMessageText: String?
    let lastMessageTimeText: String?
    let rawPosition: Int?
}
