import Foundation

struct CrawledChatHeader: Codable, Equatable, Sendable {
    let rawTitle: String?
    let rawSubtitle: String?
    let rawContextText: String?
}
