import Foundation

enum IssueRepositoryError: Error {
    case issueNotFound(String)
    case issueFinished(String)
}

final class FirestoreIssueRepository: FirestoreRepository<Issue> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "Issue",
            path: .profileScoped(scope: scope, collection: "Issues"),
        )
    }

    func getActiveIssues() async throws -> [Issue] {
        try await query(
            matching: ["finished": false],
            sortedBy: [FirestoreRepositorySort(field: "_updatedAt", descending: true)]
        )
    }

    func listAllIssues() async throws -> [Issue] {
        try await query(
            sortedBy: [FirestoreRepositorySort(field: "_updatedAt", descending: true)]
        )
    }

    func validateIssueId(_ issueId: String) async throws -> Issue {
        guard let issue = try await getById(issueId) else {
            throw IssueRepositoryError.issueNotFound(issueId)
        }

        guard !issue.finished else {
            throw IssueRepositoryError.issueFinished(issueId)
        }

        return issue
    }
}
