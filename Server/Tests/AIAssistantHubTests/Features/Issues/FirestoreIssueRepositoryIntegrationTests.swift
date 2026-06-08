import XCTest
@testable import AIAssistantHub

final class FirestoreIssueRepositoryIntegrationTests: FirestoreIntegrationTestCase {
    func testGetActiveIssuesFiltersFinishedAndKeepsUpdatedOrder() async throws {
        let repository = FirestoreIssueRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        let issues: [Issue] = try await repository.getActiveIssues()

        XCTAssertEqual(issues.compactMap(\.id), ["issue-2", "issue-1"])
    }

    func testValidateIssueIdReflectsPersistedFirestoreState() async throws {
        let repository = FirestoreIssueRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        let resolved = try await repository.validateIssueId("issue-1")
        XCTAssertEqual(resolved.id, "issue-1")

        do {
            _ = try await repository.validateIssueId("issue-3")
            XCTFail("Expected finished issue validation to throw.")
        } catch let error as IssueRepositoryError {
            guard case .issueFinished(let issueId) = error else {
                return XCTFail("Expected issueFinished error, got \(error)")
            }
            XCTAssertEqual(issueId, "issue-3")
        }

        do {
            _ = try await repository.validateIssueId("missing-issue")
            XCTFail("Expected missing issue validation to throw.")
        } catch let error as IssueRepositoryError {
            guard case .issueNotFound(let issueId) = error else {
                return XCTFail("Expected issueNotFound error, got \(error)")
            }
            XCTAssertEqual(issueId, "missing-issue")
        }
    }
}
