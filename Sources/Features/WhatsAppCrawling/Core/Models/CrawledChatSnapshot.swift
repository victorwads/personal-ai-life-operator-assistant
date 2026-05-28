import Foundation

struct CrawledChatSnapshot: Equatable, Sendable {
    let header: CrawledChatHeader
    let messages: [CrawledMessage]
}
