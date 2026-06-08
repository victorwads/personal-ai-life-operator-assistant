import Foundation

struct IssueTimelineItem: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var issueId: String
    var kind: String
    var description: String
    var reason: String? = nil
    var changedAt: Date? = nil
    var previousStatus: IssueStatus? = nil
    var suspendUntil: Date? = nil
}
