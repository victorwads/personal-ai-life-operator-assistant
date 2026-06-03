import Foundation

struct CrawledMessage: Codable, Equatable, Sendable {
    let rawText: String?
    let rawTimestampText: String?
    let rawAuthorName: String?
    let rawDirection: String?
    let rawKind: String?
    let rawStatus: String?
    let rawPosition: Int?
}
