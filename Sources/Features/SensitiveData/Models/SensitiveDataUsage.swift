import Foundation

struct SensitiveDataUsage: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var key: String
    var issueId: String
    var reason: String
    var action: SensitiveDataUsageAction
}

enum SensitiveDataUsageAction: String, Codable, CaseIterable, Sendable {
    case save
    case get
    case list
    case search
    case update
    case delete
}
