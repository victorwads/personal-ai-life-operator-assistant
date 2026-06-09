import Foundation

struct GoogleEmailSummary: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let threadId: String
    let snippet: String
    let from: String
    let to: String
    let subject: String
    let date: String
    let internalDate: String
    let labelIds: [String]
}
