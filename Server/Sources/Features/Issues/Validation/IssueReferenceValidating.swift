import Foundation

protocol IssueReferenceValidating: Sendable {
    func validateIssueId(_ issueId: String) async throws -> Issue
}
