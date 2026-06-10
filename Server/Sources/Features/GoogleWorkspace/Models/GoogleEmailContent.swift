import Foundation

struct GoogleEmailContent: Codable, Equatable, Sendable, Identifiable {
    var id: String { messageId }
    let messageId: String
    let threadId: String
    let historyId: String
    let labelIds: [String]
    let subject: String
    let from: String
    let to: String
    let cc: String?
    let bcc: String?
    let date: String
    let snippet: String
    let plainTextBody: String
    let htmlBody: String
    let attachmentsMetadata: [GoogleAttachmentMetadata]
    let internalDate: String
}
