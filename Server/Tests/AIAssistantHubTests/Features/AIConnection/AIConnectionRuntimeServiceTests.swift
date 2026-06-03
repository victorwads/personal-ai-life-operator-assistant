import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionRuntimeServiceTests: XCTestCase {
    func testStartRunKeepsCyclingAfterNormalCompletion() async throws {
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .textDelta("First cycle"),
                    .completed(
                        AIProviderResponse(
                            id: "response-1",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: "First cycle",
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .events([
                    .textDelta("Second cycle"),
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: "Second cycle",
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .waitUntilCancelled
            ]
        )
        let service = AIConnectionRuntimeService(streamingService: streamingService)

        service.startRun(userPrompt: "start your job")

        try await waitUntil {
            streamingService.recordedRequestCount() >= 3
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[1].messages.last?.role, .assistant)
        XCTAssertEqual(recordedRequests[1].messages.last?.content, "First cycle")
        XCTAssertEqual(recordedRequests[2].messages.last?.role, .assistant)
        XCTAssertEqual(recordedRequests[2].messages.last?.content, "Second cycle")
        XCTAssertTrue(service.state.isRunning)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.completed" }))

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }
}

private final class FakeAIConnectionStreamingService: AIConnectionStreamingServing, @unchecked Sendable {
    enum StreamPlan {
        case events([AIStreamEvent])
        case waitUntilCancelled
    }

    private let streamPlans: [StreamPlan]
    private let lock = NSLock()
    private var recordedRequests: [AIProviderRequest] = []
    private var nextIndex = 0

    init(streamPlans: [StreamPlan]) {
        self.streamPlans = streamPlans
    }

    func streamEvents(for request: AIProviderRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        lock.lock()
        recordedRequests.append(request)
        let plan = streamPlanForNextRequest()
        lock.unlock()

        return AsyncThrowingStream { continuation in
            let task = Task {
                switch plan {
                case let .events(events):
                    for event in events {
                        continuation.yield(event)
                    }
                    continuation.finish()
                case .waitUntilCancelled:
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    continuation.finish(throwing: CancellationError())
                }
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
            durationMilliseconds: nil
        )
    }

    func recordedRequestCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests.count
    }

    func recordedRequestsSnapshot() -> [AIProviderRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    private func streamPlanForNextRequest() -> StreamPlan {
        guard nextIndex < streamPlans.count else {
            return .waitUntilCancelled
        }

        let plan = streamPlans[nextIndex]
        nextIndex += 1
        return plan
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
