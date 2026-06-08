import Foundation

struct Issue: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var initialRequest: String
    var resolutionCondition: String
    var priority: IssuePriority
    var status: IssueStatus
    var finished: Bool
    var suspendUntil: Date?
    var relatedChatIds: [String]? = nil
}

enum IssueStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case suspended
    case resolved
    case cancelled
}

enum IssuePriority: Int, Codable, Equatable, Sendable, CaseIterable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case high = 4
    case urgent = 5
}
