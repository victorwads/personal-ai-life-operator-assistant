import Foundation

protocol IssueTimelineSaving {
    func save(_ item: IssueTimelineItem) async throws -> IssueTimelineItem
}

final class FirestoreIssueTimelineRepository: FirestoreRepository<IssueTimelineItem> {
    init(
        scope: FirebaseProfileScope,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        super.init(
            entityName: "IssueTimelineItem",
            path: .profileScoped(scope: scope, collection: "IssueTimelineItems"),
            dateProvider: dateProvider
        )
    }

    func listItems(for issueId: String) async throws -> [IssueTimelineItem] {
        try await query(
            matching: ["issueId": issueId],
            sortedBy: [FirestoreRepositorySort(field: "_createdAt")]
        )
    }

    @discardableResult
    func save(_ item: IssueTimelineItem) async throws -> IssueTimelineItem {
        try await super.save(item)
    }
}

extension FirestoreIssueTimelineRepository: IssueTimelineSaving {}
