import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionRuntimeServiceTests: XCTestCase {
    func testStartRunKeepsCyclingWithFreshContextAfterEmptyProviderCompletion() async throws {
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .completed(
                        AIProviderResponse(
                            id: "response-1",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: "",
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .events([
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: "",
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

        service.startRun()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 3
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[1].messages.count, 2)
        XCTAssertEqual(recordedRequests[2].messages.count, 2)
        XCTAssertEqual(recordedRequests[0].messages[1].role, .user)
        XCTAssertTrue(service.state.isRunning)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.completed" }))

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testBootstrapsMemoriesAtSessionStart() async throws {
        let bootstrapMessage = AIConversationMessage(
            role: .user,
            content: """
            # Client memories

            ## key: client_language
            pt-BR
            """
        )
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .waitUntilCancelled
            ]
        )
        let service = AIConnectionRuntimeService(
            streamingService: streamingService,
            memoryBootstrapProvider: { [bootstrapMessage] in bootstrapMessage }
        )

        service.startRun()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 1
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests.count, 1)
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[0].messages[0].role, .system)
        XCTAssertEqual(recordedRequests[0].messages[1].role, .user)
        XCTAssertTrue(recordedRequests[0].messages[1].content?.contains("# Client memories") == true)
        XCTAssertTrue(recordedRequests[0].messages[1].content?.contains("## key: client_language") == true)
        XCTAssertTrue(recordedRequests[0].messages[1].content?.contains("pt-BR") == true)
        XCTAssertEqual(service.state.promptSections.map(\.title), ["System Prompt"])

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testBootstrapsPendingWorkAsUserMessageAtSessionStart() async throws {
        let pendingWorkMessage = AIConversationMessage(
            role: .user,
            content: """
            Pending work is already available at startup.

            Unhandled chats:
            - Family (chatId: wa:123)
            """
        )
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .waitUntilCancelled
            ]
        )
        let service = AIConnectionRuntimeService(
            streamingService: streamingService,
            pendingWorkBootstrapProvider: { [pendingWorkMessage] in pendingWorkMessage }
        )

        service.startRun()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 1
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests.count, 1)
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[0].messages[0].role, .system)
        XCTAssertEqual(recordedRequests[0].messages[1].role, .user)
        XCTAssertTrue(recordedRequests[0].messages[1].content?.contains("Pending work is already available at startup.") == true)
        XCTAssertTrue(recordedRequests[0].messages[1].content?.contains("Family (chatId: wa:123)") == true)
        XCTAssertEqual(service.state.promptSections.map(\.title), ["System Prompt", "Pending Work Bootstrap"])
        XCTAssertEqual(service.state.promptSections.last?.roleLabel, "user")

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testPlainAssistantTextAppendsCorrectionAndRetriesInSameContext() async throws {
        let speakToolCall = AIRequestedToolCall(
            id: "tool-speak",
            name: "announce_to_client",
            argumentsJSON: "{\"message\":\"I am checking now.\"}"
        )
        let invalidAssistantText = "I will tell the client I am checking now."
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .textDelta(invalidAssistantText),
                    .completed(
                        AIProviderResponse(
                            id: "response-1",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: invalidAssistantText,
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .events([
                    .toolCallStarted(id: speakToolCall.id, name: speakToolCall.name),
                    .toolCallCompleted(speakToolCall),
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "tool_calls",
                            text: "",
                            reasoning: "",
                            toolCalls: [speakToolCall],
                            usage: nil
                        )
                    )
                ]),
                .waitUntilCancelled
            ]
        )
        let service = AIConnectionRuntimeService(streamingService: streamingService)

        service.startRun()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 3
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[1].messages.count, 4)
        XCTAssertEqual(recordedRequests[1].messages[2].role, .assistant)
        XCTAssertEqual(recordedRequests[1].messages[2].content, invalidAssistantText)
        XCTAssertEqual(recordedRequests[1].messages[3].role, .user)
        XCTAssertTrue(recordedRequests[1].messages[3].content?.contains("Runtime correction:") == true)
        XCTAssertTrue(recordedRequests[1].messages[3].content?.contains(invalidAssistantText) == true)
        XCTAssertEqual(recordedRequests[2].messages.count, 6)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "assistant.invalid_text.detected" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "assistant.correction.user_message_appended" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "assistant.correction.retry_started" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "assistant.correction.context_preserved" }))

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
                .waitUntilCancelled,
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
                    validationErrors: [],
                    durationMilliseconds: nil
                )
            }
        )
        let service = AIConnectionRuntimeService(streamingService: streamingService)

        service.startRun()

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
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "context.cleared.wait_for_event" }))

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testFailureDoesNotStopRuntimeAndNextCycleStartsAutomatically() async throws {
        let logsDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let followupToolCall = AIRequestedToolCall(
            id: "tool-followup",
            name: "get_current_datetime",
            argumentsJSON: "{\"timezone\":\"UTC\"}"
        )
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
                    .toolCallStarted(id: followupToolCall.id, name: followupToolCall.name),
                    .toolCallCompleted(followupToolCall),
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "tool_calls",
                            text: "",
                            reasoning: "",
                            toolCalls: [followupToolCall],
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

        service.startRun()

        try await waitUntil {
            streamingService.recordedRequestCount() >= 3
        }

        XCTAssertEqual(streamingService.recordedRequestsSnapshot().count, 3)
        XCTAssertTrue(service.state.isRunning)
        XCTAssertEqual(service.state.errors.last, "AI provider request failed with status code 500.")
        XCTAssertEqual(service.state.lastProviderFailure?.statusCode, 500)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "cycle.failed" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "context.cleared.error" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "provider.failed" }))
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

    func testCorrectionRetriesAreCappedAndFreshCycleStartsAfterExhaustion() async throws {
        let invalidAssistantTexts = [
            "I can answer without tools.",
            "I still will not call a tool.",
            "I am ignoring the runtime rules again."
        ]
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .textDelta(invalidAssistantTexts[0]),
                    .completed(
                        AIProviderResponse(
                            id: "response-1",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: invalidAssistantTexts[0],
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .events([
                    .textDelta(invalidAssistantTexts[1]),
                    .completed(
                        AIProviderResponse(
                            id: "response-2",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: invalidAssistantTexts[1],
                            reasoning: "",
                            toolCalls: [],
                            usage: nil
                        )
                    )
                ]),
                .events([
                    .textDelta(invalidAssistantTexts[2]),
                    .completed(
                        AIProviderResponse(
                            id: "response-3",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "stop",
                            text: invalidAssistantTexts[2],
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

        service.startRun()

        try await waitUntil(timeoutNanoseconds: 4_000_000_000) {
            streamingService.recordedRequestCount() >= 4
        }

        let recordedRequests = streamingService.recordedRequestsSnapshot()
        XCTAssertEqual(recordedRequests[0].messages.count, 2)
        XCTAssertEqual(recordedRequests[1].messages.count, 4)
        XCTAssertEqual(recordedRequests[2].messages.count, 6)
        XCTAssertEqual(recordedRequests[3].messages.count, 2)
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "assistant.correction.retry_exhausted" }))
        XCTAssertTrue(service.state.debugEvents.contains(where: { $0.kind == "context.cleared.error" }))
        XCTAssertEqual(
            service.state.errors.last,
            "Model returned invalid plain assistant text after 2 corrective retries: \(invalidAssistantTexts[2])"
        )

        service.cancelRun()

        try await waitUntil {
            service.state.status == .cancelled
        }
    }

    func testPersistsStructuredMilestoneLogs() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("ServerLogs.sqlite", isDirectory: false)
        let repository = SQLiteServerLogRepository(
            profileId: "test-profile",
            databaseURL: databaseURL,
            retentionLimit: 100
        )
        let serverLogsService = ServerLogsService(repository: repository)
        let toolCall = AIRequestedToolCall(
            id: "tool-1",
            name: "get_current_datetime",
            argumentsJSON: "{\"timezone\":\"UTC\"}"
        )
        let memoryBootstrapMessage = AIConversationMessage(
            role: .user,
            content: "# Client memories\n\n## key: timezone\nUTC"
        )
        let pendingWorkMessage = AIConversationMessage(
            role: .user,
            content: "Pending work is already available at startup."
        )
        let streamingService = FakeAIConnectionStreamingService(
            streamPlans: [
                .events([
                    .requestStarted(provider: .openRouter, model: "model-1"),
                    .reasoningDelta("Thinking"),
                    .toolCallStarted(id: toolCall.id, name: toolCall.name),
                    .toolCallCompleted(toolCall),
                    .completed(
                        AIProviderResponse(
                            id: "response-1",
                            model: "model-1",
                            provider: .openRouter,
                            finishReason: "tool_calls",
                            text: "Need a timestamp.",
                            reasoning: "Thinking",
                            toolCalls: [toolCall],
                            usage: nil
                        )
                    )
                ]),
                .waitUntilCancelled
            ],
            executeToolCallHandler: { toolCall in
                AIToolExecutionResult(
                    toolName: toolCall.name,
                    success: true,
                    payload: .object(["timestamp": .string("2026-06-03T12:00:00Z")]),
                    errorMessage: nil,
                    suggestedAction: nil,
                    validationErrors: [],
                    durationMilliseconds: 18
                )
            }
        )
        let service = AIConnectionRuntimeService(
            streamingService: streamingService,
            memoryBootstrapProvider: { memoryBootstrapMessage },
            pendingWorkBootstrapProvider: { pendingWorkMessage },
            serverLogsProvider: { serverLogsService }
        )

        service.startRun()

        try await waitUntil {
            let entries = try? await repository.list(ServerLogQuery(limit: 20))
            guard let entries else { return false }
            let kinds = Set(entries.map(\.kind))
            return kinds.contains(.sessionStarted)
                && kinds.contains(.promptProcessingCompleted)
                && kinds.contains(.reasoningCompleted)
                && kinds.contains(.assistantOutputCompleted)
                && kinds.contains(.toolCallCompleted)
        }

        let entries = try await repository.list(ServerLogQuery(limit: 20))
        XCTAssertTrue(entries.contains(where: {
            $0.kind == .toolCallCompleted
                && $0.toolCallId == "tool-1"
                && $0.toolName == "get_current_datetime"
                && $0.durationMilliseconds == 18
                && $0.success == true
                && $0.outputPayload?.contains("Tool: get_current_datetime") == true
                && $0.outputPayload?.contains("Status: success") == true
                && $0.outputPayload?.contains("2026-06-03T12:00:00Z") == true
        }))
        XCTAssertTrue(entries.contains(where: {
            $0.kind == .sessionStarted
                && $0.inputPayload?.contains("\"role\":\"system\"") == true
                && $0.inputPayload?.contains("\"role\":\"user\"") == true
                && $0.inputPayload?.contains("# Client memories") == true
                && $0.inputPayload?.contains("Pending work is already available at startup.") == true
        }))

        service.cancelRun()
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
                validationErrors: [],
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
