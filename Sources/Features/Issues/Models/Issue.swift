import Foundation

struct Issue: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var title: String?
    var summary: String?
    var initialRequest: String?
    var priority: Int?
    var resolutionCondition: String?
    var status: IssueStatus
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

enum IssueStatus: String, Codable, Equatable, Sendable {
    case open
    case inProgress
    case blocked
    case resolved
    case cancelled
}
