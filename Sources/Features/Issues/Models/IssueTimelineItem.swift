import Foundation

struct IssueTimelineItem: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var issueId: String
    var kind: String
    var description: String
}
