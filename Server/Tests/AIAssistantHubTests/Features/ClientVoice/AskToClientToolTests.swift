import XCTest
@testable import AIAssistantHub

final class AskToClientToolTests: XCTestCase {
    func testReturnsPendingMessageWhenUnlockedWithoutResponse() async throws {
        let repository = AskToClientRepositorySpy()
        let sharedLocks = SharedLockRegistry()
        let tool = AskToClientTool(
            repository: repository,
            sharedLocks: sharedLocks,
            isClientPresentProvider: { true }
        )

        let task = Task {
            try await tool.execute(
                MCPToolCall(
                    name: "ask_to_client",
                    arguments: [
                        "issueId": .string("issue-1"),
                        "text": .string("Can you answer?")
                    ]
                ),
                context: MCPServerContext()
            )
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        await sharedLocks.unlock(id: "ask_to_client:ask-1")
        let result = try await task.value

        XCTAssertEqual(
            result,
            .string("pending: question registered for the client. The client could not answer now. Continue autonomously if possible or wait for an event. You will be notified when the client responds.")
        )
        XCTAssertEqual(repository.markCompletedCallCount, 0)
    }
}

private final class AskToClientRepositorySpy: ClientInteractionRequestRepository {
    private(set) var markCompletedCallCount = 0

    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }

    func getRequest(id: String) async throws -> ClientInteractionRequest {
        ClientInteractionRequest(
            id: id,
            issueId: "issue-1",
            kind: .ask,
            status: .speaking,
            promptText: "Can you answer?",
            responseText: nil
        )
    }

    func createRequest(
        issueId: String,
        kind: ClientInteractionRequest.Kind,
        status: ClientInteractionRequest.Status,
        promptText: String
    ) async throws -> ClientInteractionRequest {
        ClientInteractionRequest(
            id: "ask-1",
            issueId: issueId,
            kind: kind,
            status: status,
            promptText: promptText
        )
    }

    func markWaitingAgent(id: String, responseText: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound(id)
    }

    func markSpeaking(id: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound(id)
    }

    func markWaitingUser(id: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound(id)
    }

    func markCompleted(id: String) async throws -> ClientInteractionRequest {
        markCompletedCallCount += 1
        return ClientInteractionRequest(
            id: id,
            issueId: "issue-1",
            kind: .ask,
            status: .completed,
            promptText: "Can you answer?"
        )
    }

    func markCancelled(id: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound(id)
    }

    func listRequests() async throws -> [ClientInteractionRequest] {
        []
    }
}
