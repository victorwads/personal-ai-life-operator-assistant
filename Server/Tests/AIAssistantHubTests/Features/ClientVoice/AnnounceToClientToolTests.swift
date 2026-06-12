import XCTest
@testable import AIAssistantHub

final class AnnounceToClientToolTests: FirestoreIntegrationTestCase {
    func testReturnsQuestionHintWhenClientIsPresent() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let tool = AnnounceToClientTool(
            repository: repository,
            sharedLocks: sharedLocks,
            isClientPresentProvider: { true }
        )

        let task = Task {
            try await tool.execute(
                MCPToolCall(
                    name: "announce_to_client",
                    arguments: [
                        "issueId": .string("issue-1"),
                        "text": .string("Can you confirm?")
                    ]
                ),
                context: MCPServerContext()
            )
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.issueId, "issue-1")
        XCTAssertEqual(request.promptText, "Can you confirm?")
        XCTAssertEqual(request.status, .initialized)
        let requestID = try XCTUnwrap(request.id)

        await sharedLocks.unlock(id: "announce_to_client:\(requestID)")
        let result = try await task.value

        XCTAssertEqual(
            result,
            .string("warning: this message contains a question mark; prefer ask_to_client(...) when you need a client answer. The client will not be able to answer you with announce_to_client(...). The message was delivered to the client. You may continue.")
        )
    }

    func testReturnsQuestionHintWhenClientIsAbsent() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let tool = AnnounceToClientTool(
            repository: repository,
            sharedLocks: sharedLocks,
            isClientPresentProvider: { false }
        )

        let result = try await tool.execute(
            MCPToolCall(
                name: "announce_to_client",
                arguments: [
                    "issueId": .string("issue-1"),
                    "text": .string("Can you confirm?")
                ]
            ),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .string("warning: this message contains a question mark; prefer ask_to_client(...) when you need a client answer. The client will not be able to answer you with announce_to_client(...). The message was registered and will be delivered when the client is available. You may continue.")
        )

        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.issueId, "issue-1")
        XCTAssertEqual(request.promptText, "Can you confirm?")
        XCTAssertEqual(request.status, .initialized)
    }

    func testKeepsInformationalMessageClean() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let tool = AnnounceToClientTool(
            repository: repository,
            sharedLocks: sharedLocks,
            isClientPresentProvider: { true }
        )

        let task = Task {
            try await tool.execute(
                MCPToolCall(
                    name: "announce_to_client",
                    arguments: [
                        "issueId": .string("issue-1"),
                        "text": .string("The migration is ready.")
                    ]
                ),
                context: MCPServerContext()
            )
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        let requestID = try XCTUnwrap(request.id)

        await sharedLocks.unlock(id: "announce_to_client:\(requestID)")
        let result = try await task.value

        XCTAssertEqual(result, .string("ok: message delivered to the client."))
    }
}
