import XCTest
@testable import AIAssistantHub

final class AskToClientToolTests: FirestoreIntegrationTestCase {
    func testReturnsPendingMessageWhenUnlockedWithoutResponse() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
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

        // Verify request was created in real repository
        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.issueId, "issue-1")
        XCTAssertEqual(request.promptText, "Can you answer?")
        XCTAssertEqual(request.status, .initialized)
        let requestID = try XCTUnwrap(request.id)

        // Unlock the tool execution without setting responseText
        await sharedLocks.unlock(id: "ask_to_client:\(requestID)")
        let result = try await task.value

        XCTAssertEqual(
            result,
            .string("pending: question registered for the client. The client could not answer now. Continue autonomously if possible or wait for an event. You will be notified when the client responds.")
        )

        // Verify request was NOT marked completed because there was no responseText
        let finalRequest = try await repository.getRequest(id: requestID)
        XCTAssertEqual(finalRequest.status, .initialized)
    }

    func testReturnsResponseTextWhenUnlockedWithResponse() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
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

        // Verify request was created
        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        let requestID = try XCTUnwrap(request.id)

        // Set response and lock wait will complete
        _ = try await repository.markWaitingAgent(id: requestID, responseText: "Yes, I can.")

        await sharedLocks.unlock(id: "ask_to_client:\(requestID)")
        let result = try await task.value

        XCTAssertEqual(result, .string("Yes, I can."))

        // Verify request was marked completed
        let finalRequest = try await repository.getRequest(id: requestID)
        XCTAssertEqual(finalRequest.status, .completed)
    }

    func testReturnsPendingMessageWhenClientAbsent() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let tool = AskToClientTool(
            repository: repository,
            sharedLocks: sharedLocks,
            isClientPresentProvider: { false }
        )

        let result = try await tool.execute(
            MCPToolCall(
                name: "ask_to_client",
                arguments: [
                    "issueId": .string("issue-1"),
                    "text": .string("Can you answer?")
                ]
            ),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .string("pending: question registered for the client. The client will answer when available. Continue autonomously if possible or wait for an event. You will be notified when the client responds.")
        )

        // Verify request was created in real repository
        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.issueId, "issue-1")
        XCTAssertEqual(request.promptText, "Can you answer?")
        XCTAssertEqual(request.status, .initialized)
    }
}
