import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionProfileRuntimeServiceTests: XCTestCase {
    func testStartTriggersRuntimeLoop() async throws {
        let streamingService = IdleAIConnectionStreamingService()
        let runtimeService = AIConnectionRuntimeService(streamingService: streamingService)
        let service = AIConnectionProfileRuntimeService(
            id: "ai.connection",
            title: "AI Connection",
            runtimeService: runtimeService
        )

        await service.start()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 1 && runtimeService.state.isRunning
        }

        XCTAssertEqual(service.state, .running)
        XCTAssertTrue(runtimeService.state.isRunning)

        await service.stop()

        try await waitUntil {
            runtimeService.state.status == .cancelled
        }

        XCTAssertEqual(service.state, .stopped)
    }
}

private final class IdleAIConnectionStreamingService: AIConnectionStreamingServing, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [AIProviderRequest] = []

    func streamEvents(
        for request: AIProviderRequest,
        overrideConfiguration: AIConnectionProviderConfiguration?
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()

        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.textDelta("auto-start"))
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                continuation.finish(throwing: CancellationError())
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func availableTools() async -> [AIToolDefinition] { [] }

    func executeToolCall(_ toolCall: AIRequestedToolCall) async -> AIToolExecutionResult {
        AIToolExecutionResult(
            toolName: toolCall.name,
            success: true,
            payload: nil,
            errorMessage: nil,
            suggestedAction: nil,
            validationErrors: [],
            durationMilliseconds: nil
        )
    }

    func recordedRequestCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests.count
    }
}

private extension XCTestCase {
    func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollNanoseconds: UInt64 = 25_000_000,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))

        while ContinuousClock.now < deadline {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollNanoseconds)
        }

        XCTFail("Condition was not met before timeout.")
    }
}
