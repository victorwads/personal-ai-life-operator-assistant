import Foundation

final class FirestoreIssueTimelineRepository: FirestoreRepository<IssueTimelineItem> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "IssueTimelineItem",
            path: .profileScoped(scope: scope, collection: "IssueTimelineItems")
        )
    }

    func listItems(for issueId: String) async throws -> [IssueTimelineItem] {
        try await query(
            matching: ["issueId": issueId],
            sortedBy: [FirestoreRepositorySort(field: "_createdAt")]
        )
    }
}
