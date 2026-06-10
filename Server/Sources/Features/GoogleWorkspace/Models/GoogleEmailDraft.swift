import Foundation

struct GoogleEmailDraft: Codable, Equatable, Sendable, Identifiable {
    let draftId: String
    let threadId: String?
    let to: String
    let cc: String?
    let bcc: String?
    let subject: String
    let body: String
    let draftCreatedAt: Date

    var id: String { draftId }
}
