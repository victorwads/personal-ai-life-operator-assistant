import XCTest
@testable import AIAssistantHub

@MainActor
final class WaitingAgentPendingWorkProviderTests: FirestoreIntegrationTestCase {
    func testPendingWorkSectionReturnsWaitingAgentRequestsAndConsumesThem() async throws {
        try await FirestoreFixture.importFixture(scope, "waiting-agent-pending-work-basic.json")

        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let provider = WaitingAgentPendingWorkProvider(
            repository: repository,
            issueTitleProvider: { issueId in
                XCTAssertEqual(issueId, "issue-1")
                return "Trip"
            }
        )

        let section = try await provider.pendingWorkSection()

        XCTAssertEqual(
            section,
            PendingWorkSection(
                title: "Client interaction requests waiting for agent",
                lines: [
                    "issueId: issue-1 | issueTitle: Trip | prompt: Can I go tomorrow? | response: Yes."
                ]
            )
        )

        // Verify that the request has been marked as completed in real repository
        let updatedRequest = try await repository.getRequest(id: "ask-1")
        XCTAssertEqual(updatedRequest.status, .completed)
    }

    func testPendingWorkSectionReturnsNilWhenNoWaitingAgentRequestsExist() async throws {
        try await FirestoreFixture.importFixture(scope, "waiting-agent-pending-work-empty.json")

        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let provider = WaitingAgentPendingWorkProvider(
            repository: repository,
            issueTitleProvider: { _ in
                XCTFail("issue title provider should not be called when there is no pending work")
                return nil
            }
        )

        let section = try await provider.pendingWorkSection()

        XCTAssertNil(section)
    }

    func testPendingWorkSectionHandlesManualRequestsWithoutIssueId() async throws {
        try await FirestoreFixture.importFixture(scope, "waiting-agent-pending-work-no-issue.json")

        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let provider = WaitingAgentPendingWorkProvider(
            repository: repository,
            issueTitleProvider: { _ in
                XCTFail("issue title provider should not be called for manual requests without issue id")
                return nil
            }
        )

        let section = try await provider.pendingWorkSection()

        XCTAssertEqual(
            section,
            PendingWorkSection(
                title: "Client interaction requests waiting for agent",
                lines: [
                    "issueId: none | issueTitle: No issue linked | prompt: Eu vi que voce me chamou, o que voce precisa? | response: Preciso que voce veja meu pedido."
                ]
            )
        )

        // Verify request was marked as completed
        let updatedRequest = try await repository.getRequest(id: "ask-1")
        XCTAssertEqual(updatedRequest.status, .completed)
    }
}
