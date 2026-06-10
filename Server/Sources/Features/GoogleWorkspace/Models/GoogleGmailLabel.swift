import Foundation

struct GoogleGmailLabel: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let type: String
    let messageListVisibility: String?
    let labelListVisibility: String?
}
