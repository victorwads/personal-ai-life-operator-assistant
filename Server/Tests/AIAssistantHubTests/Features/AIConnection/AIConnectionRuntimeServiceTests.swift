import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionRuntimeServiceTests: XCTestCase {
    func testStartRunKeepsCyclingWithFreshContextAfterNormalCompletion() async throws {
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
        XCTAssertEqual(recordedRequests[1].messages.count, 2)
        XCTAssertEqual(recordedRequests[2].messages.count, 2)
        XCTAssertTrue(service.state.isRunning)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.completed" }))

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testWaitForEventEndsCycleAndRestartsWithFreshContext() async throws {
        let waitController = WaitForEventExecutionController()
        let waitToolCall = AIRequestedToolCall(
            id: "tool-wait",
            name: "wait_for_event",
            argumentsJSON: "{}"
        )
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .toolCallStarted(id: waitToolCall.id, name: waitToolCall.name),
                    .toolCallCompleted(waitToolCall),
                    .completed(
                        AIProviderResponse(
                            id: "response-1",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "tool_calls",
                            text: "",
                            reasoning: "",
                            toolCalls: [waitToolCall],
                            usage: nil
                        )
                    )
                ]),
                .events([
                    .textDelta("Fresh cycle after event"),
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: "Fresh cycle after event",
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .waitUntilCancelled
            ],
            executeToolCallHandler: { toolCall in
                if toolCall.name == "wait_for_event" {
                    await waitController.waitUntilReleased()
                }

                return AIToolExecutionResult(
                    toolName: toolCall.name,
                    success: true,
                    payload: .string("event: something changed. Start a new cycle and inspect active chats, issues, and client interactions."),
                    errorMessage: nil,
                    suggestedAction: nil,
                    durationMilliseconds: nil
                )
            }
        )
        let service = AIConnectionRuntimeService(streamingService: streamingService)

        service.startRun(userPrompt: "stay alive and keep watching")

        try await waitUntil {
            streamingService.recordedRequestCount() >= 1
        }
        XCTAssertEqual(streamingService.recordedRequestsSnapshot().count, 1)

        await waitController.release()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 2
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[1].messages.count, 2)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.idle_boundary" }))

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testFailureDoesNotStopRuntimeAndNextCycleStartsAutomatically() async throws {
        let logsDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .failed(
                        AIProviderFailure(
                            message: "AI provider request failed with status code 500.",
                            provider: .openRouter,
                            model: "model-1",
                            endpoint: "https://provider.example/v1/chat/completions",
                            statusCode: 500,
                            responseHeaders: ["content-type": "application/json"],
                            responseBody: "{\"error\":{\"message\":\"boom\"}}",
                            requestBody: "{\"model\":\"model-1\"}",
                            requestMessageCount: 2,
                            requestToolCount: 0,
                            underlyingError: "server error"
                        )
                    )
                ]),
                .events([
                    .textDelta("Recovered cycle"),
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: "Recovered cycle",
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .waitUntilCancelled
            ]
        )
        let service = AIConnectionRuntimeService(
            streamingService: streamingService,
            errorLogStore: AIConnectionErrorLogStore(logsDirectoryURL: logsDirectoryURL)
        )

        service.startRun(userPrompt: "keep running forever")

        try await waitUntil {
            streamingService.recordedRequestCount() >= 3
        }

        XCTAssertEqual(streamingService.recordedRequestsSnapshot().count, 3)
        XCTAssertTrue(service.state.isRunning)
        XCTAssertEqual(service.state.errors.last, "AI provider request failed with status code 500.")
        XCTAssertEqual(service.state.lastProviderFailure?.statusCode, 500)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.failed" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "provider.failed" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.completed" }))
        XCTAssertNotEqual(service.state.status, .failed)

        let logFiles = try FileManager.default.contentsOfDirectory(
            at: logsDirectoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(logFiles.count, 1)
        let logData = try Data(contentsOf: logFiles[0])
        let logText = try XCTUnwrap(String(data: logData, encoding: .utf8))
        XCTAssertTrue(logText.contains("\"statusCode\" : 500"))
        XCTAssertTrue(logText.contains("provider.example/v1/chat/completions"))
        XCTAssertTrue(logText.contains("\\\"boom\\\""))

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
    private let executeToolCallHandler: @Sendable (AIRequestedToolCall) async -> AIToolExecutionResult
    private let lock = NSLock()
    private var recordedRequests: [AIProviderRequest] = []
    private var nextIndex = 0

    init(
        streamPlans: [StreamPlan],
        executeToolCallHandler: @escaping @Sendable (AIRequestedToolCall) async -> AIToolExecutionResult = { toolCall in
            AIToolExecutionResult(
                toolName: toolCall.name,
                success: true,
                payload: nil,
                errorMessage: nil,
                suggestedAction: nil,
                durationMilliseconds: nil
            )
        }
    ) {
        self.streamPlans = streamPlans
        self.executeToolCallHandler = executeToolCallHandler
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
        await executeToolCallHandler(toolCall)
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

private actor WaitForEventExecutionController {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func waitUntilReleased() async {
        if isReleased {
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        guard !isReleased else { return }
        isReleased = true
        continuation?.resume()
        continuation = nil
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
