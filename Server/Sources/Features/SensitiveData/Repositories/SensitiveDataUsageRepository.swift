import Foundation

final class FirestoreSensitiveDataUsageRepository: FirestoreRepository<SensitiveDataUsage> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "SensitiveDataUsage",
            path: .profileScoped(scope: scope, collection: "SensitiveDataUsage")
        )
    }

    func listUsage(for key: String) async throws -> [SensitiveDataUsage] {
        try await query(
            matching: ["key": key],
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)]
        )
    }

    func listUsage(issueId: String) async throws -> [SensitiveDataUsage] {
        try await query(
            matching: ["issueId": issueId],
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)]
        )
    }

    func listRecentUsage(limit: Int = 50) async throws -> [SensitiveDataUsage] {
        try await query(
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)],
            limit: limit
        )
    }
}
