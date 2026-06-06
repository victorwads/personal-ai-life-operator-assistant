import XCTest
@testable import AIAssistantHub

@MainActor
final class WaitingAgentPendingWorkProviderTests: XCTestCase {
    func testPendingWorkSectionReturnsWaitingAgentRequestsAndConsumesThem() async throws {
        let repository = WaitingAgentPendingWorkRepositorySpy(
            requests: [
                ClientInteractionRequest(
                    id: "ask-1",
                    issueId: "issue-1",
                    kind: .ask,
                    status: .waitingAgent,
                    promptText: "Can I go tomorrow?",
                    responseText: "Yes."
                ),
                ClientInteractionRequest(
                    id: "done-1",
                    issueId: "issue-2",
                    kind: .ask,
                    status: .completed,
                    promptText: "Ignored",
                    responseText: "Ignored"
                )
            ]
        )
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
        XCTAssertEqual(repository.markCompletedCalls, ["ask-1"])
    }

    func testPendingWorkSectionReturnsNilWhenNoWaitingAgentRequestsExist() async throws {
        let repository = WaitingAgentPendingWorkRepositorySpy(
            requests: [
                ClientInteractionRequest(
                    id: "done-1",
                    issueId: "issue-1",
                    kind: .ask,
                    status: .completed,
                    promptText: "Done",
                    responseText: "Done"
                )
            ]
        )
        let provider = WaitingAgentPendingWorkProvider(
            repository: repository,
            issueTitleProvider: { _ in
                XCTFail("issue title provider should not be called when there is no pending work")
                return nil
            }
        )

        let section = try await provider.pendingWorkSection()

        XCTAssertNil(section)
        XCTAssertTrue(repository.markCompletedCalls.isEmpty)
    }

    func testPendingWorkSectionHandlesManualRequestsWithoutIssueId() async throws {
        let repository = WaitingAgentPendingWorkRepositorySpy(
            requests: [
                ClientInteractionRequest(
                    id: "ask-1",
                    issueId: nil,
                    kind: .ask,
                    status: .waitingAgent,
                    promptText: "Eu vi que voce me chamou, o que voce precisa?",
                    responseText: "Preciso que voce veja meu pedido."
                )
            ]
        )
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
        XCTAssertEqual(repository.markCompletedCalls, ["ask-1"])
    }
}

private final class WaitingAgentPendingWorkRepositorySpy: ClientInteractionRequestRepository {
    let requests: [ClientInteractionRequest]
    private(set) var markCompletedCalls: [String] = []

    init(requests: [ClientInteractionRequest]) {
        self.requests = requests
    }

    func listRequests() async throws -> [ClientInteractionRequest] {
        requests
    }

    func observeRequests(_: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }

    func getRequest(id: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound(id)
    }

    func createRequest(
        issueId _: String?,
        kind _: ClientInteractionRequest.Kind,
        status _: ClientInteractionRequest.Status,
        promptText _: String
    ) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func markWaitingAgent(id _: String, responseText _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func markSpeaking(id _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func markWaitingUser(id _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func markCompleted(id: String) async throws -> ClientInteractionRequest {
        markCompletedCalls.append(id)
        guard let request = requests.first(where: { $0.id == id }) else {
            throw ClientInteractionRequestRepositoryError.requestNotFound(id)
        }
        return ClientInteractionRequest(
            id: id,
            issueId: request.issueId,
            kind: request.kind,
            status: .completed,
            promptText: request.promptText,
            responseText: request.responseText
        )
    }

    func markCancelled(id _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }
}
