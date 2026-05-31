import Foundation

struct SentMessage: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var issueId: String
    var chatId: String
    var chatTitle: String?
    var messages: [String]
    var status: SentMessageStatus
    var chatMessageIds: [String]
    var errorMessage: String?
    var sentAt: Date?
}

enum SentMessageStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case sent
    case failed
    case partiallySent
}
