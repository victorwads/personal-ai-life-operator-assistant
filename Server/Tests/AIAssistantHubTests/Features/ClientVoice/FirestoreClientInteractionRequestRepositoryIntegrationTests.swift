import XCTest
@testable import AIAssistantHub

final class FirestoreClientInteractionRequestRepositoryIntegrationTests: FirestoreIntegrationTestCase {
    func testCreateAndListRequestsUsesRealFirestoreOrdering() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        try await fixtureBuilder.importFixture(named: "client-interaction-request-basic.json")

        let first = try await repository.createRequest(
            issueId: "issue-1",
            kind: .ask,
            status: .waitingUser,
            promptText: "First"
        )
        try await Task.sleep(for: .milliseconds(20))
        let second = try await repository.createRequest(
            issueId: "issue-2",
            kind: .speak,
            status: .initialized,
            promptText: "Second"
        )

        let requests = try await repository.listRequests()

        XCTAssertEqual(
            requests.compactMap(\.id),
            ["request-1", try XCTUnwrap(second.id), try XCTUnwrap(first.id)]
        )
    }

    func testLifecycleTransitionsPersistStatusAndResponseText() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        try await fixtureBuilder.importFixture(named: "client-interaction-request-basic.json")

        let created = try await repository.createRequest(
            issueId: nil,
            kind: .ask,
            status: .initialized,
            promptText: "Need response"
        )
        let requestId = try XCTUnwrap(created.id)

        let waitingAgent = try await repository.markWaitingAgent(
            id: requestId,
            responseText: "Answer"
        )
        XCTAssertEqual(waitingAgent.status, .waitingAgent)
        XCTAssertEqual(waitingAgent.responseText, "Answer")
        XCTAssertEqual(waitingAgent.device, .desktop)

        let waitingUser = try await repository.markWaitingUser(id: requestId)
        XCTAssertEqual(waitingUser.status, .waitingUser)
        XCTAssertEqual(waitingUser.responseText, "Answer")

        let completed = try await repository.markCompleted(id: requestId)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.device, .desktop)
    }

    func testObserveRequestsReceivesLiveFirestoreUpdates() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        try await fixtureBuilder.importFixture(named: "client-interaction-request-basic.json")
        let expectation = expectation(description: "Observed persisted request")
        expectation.assertForOverFulfill = false

        let token = repository.observeRequests { requests in
            if requests.contains(where: { $0.promptText == "Observed" && $0.status == .waitingUser }) {
                expectation.fulfill()
            }
        }
        defer {
            token.cancel()
        }

        _ = try await repository.createRequest(
            issueId: nil,
            kind: .ask,
            status: .waitingUser,
            promptText: "Observed"
        )

        await fulfillment(of: [expectation], timeout: 10.0)
    }
}
