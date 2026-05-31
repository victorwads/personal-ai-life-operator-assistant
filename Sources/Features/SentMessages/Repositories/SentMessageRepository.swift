import Foundation

final class FirestoreSentMessageRepository: FirestoreRepository<SentMessage> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "SentMessage",
            path: .profileScoped(scope: scope, collection: "SentMessages")
        )
    }

    func listAll(limit: Int? = nil) async throws -> [SentMessage] {
        try await query(
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)],
            limit: limit
        )
    }

    func listByIssueId(_ issueId: String) async throws -> [SentMessage] {
        try await query(
            matching: ["issueId": issueId],
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)]
        )
    }

    func listByChatId(_ chatId: String) async throws -> [SentMessage] {
        try await query(
            matching: ["chatId": chatId],
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)]
        )
    }
}
