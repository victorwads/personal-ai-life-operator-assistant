import Foundation

struct SensitiveDataUsage: Codable, Equatable, Sendable {
    let key: String
    let issueId: String?
    let chatId: String?
    let reason: String?
    let usedAt: Date
}
