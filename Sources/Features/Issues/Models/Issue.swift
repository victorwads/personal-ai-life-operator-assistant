import Foundation

struct Issue: Codable, Equatable, Sendable {
    let id: String
    let title: String?
    let summary: String?
    let initialRequest: String?
    let priority: Int?
    let resolutionCondition: String?
    let status: IssueStatus
}

enum IssueStatus: String, Codable, Equatable, Sendable {
    case open
    case inProgress
    case blocked
    case done
    case cancelled
}
