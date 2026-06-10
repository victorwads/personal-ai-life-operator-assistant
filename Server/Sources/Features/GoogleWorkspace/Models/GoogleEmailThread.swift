import Foundation

struct GoogleEmailThread: Codable, Equatable, Sendable, Identifiable {
    var id: String { threadId }
    let threadId: String
    let messages: [GoogleEmailContent]
}
