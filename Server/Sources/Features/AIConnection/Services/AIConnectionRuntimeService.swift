import Foundation

@MainActor
final class AIConnectionRuntimeService: ObservableObject {
    @Published private(set) var state = AIConnectionRuntimeState.initial()

    private let streamingService: any AIConnectionStreamingServing
    private let errorLogStore: AIConnectionErrorLogStore
    private var activeStreamingTask: Task<Void, Never>?
    private var toolCallIndexByID: [String: Int] = [:]

    private static let maxDebugEvents = 200
    private static let interCycleDelayNanoseconds: UInt64 = 500_000_000

    init(
        streamingService: any AIConnectionStreamingServing,
        errorLogStore: AIConnectionErrorLogStore = AIConnectionErrorLogStore()
    ) {
        self.streamingService = streamingService
        self.errorLogStore = errorLogStore
    }

    func loadTools() async {
        guard !state.isLoadingTools else { return }
        state.isLoadingTools = true
        defer { state.isLoadingTools = false }

        let loadedTools = await streamingService.availableTools().sorted { $0.name < $1.name }
        state.availableToolDefinitions = loadedTools
        appendDebug(kind: "tools.loaded", summary: "Loaded \(loadedTools.count) tool definition(s).")
    }

    func startRun(userPrompt: String) {
        guard state.canStart, activeStreamingTask == nil else {
            state.errors.append("A run is already active. Cancel or reset before starting another.")
            appendDebug(kind: "run.start.rejected", summary: "Attempted to start while another run was active.")
            return
        }

        prepareStateForNewRun(userPrompt: userPrompt)

        activeStreamingTask = Task { [weak self] in
            guard let self else { return }
            await self.runContinuousLoop()

            await MainActor.run {
                self.activeStreamingTask = nil
            }
        }
    }

    func cancelRun() {
        guard state.canCancel else { return }
        activeStreamingTask?.cancel()
        markCancelled()
    }

    func resetRun() {
        guard state.canReset else {
            state.errors.append("Reset is not allowed while a run is active. Cancel first.")
            appendDebug(kind: "run.reset.rejected", summary: "Attempted reset while run was active.")
            return
        }

        activeStreamingTask?.cancel()
        activeStreamingTask = nil
        toolCallIndexByID = [:]
        state = .initial(availableToolDefinitions: state.availableToolDefinitions)
    }

    private func runContinuousLoop() async {
        var currentCycle = 0

        while !Task.isCancelled {
            let cycleNumber = currentCycle + 1
            await MainActor.run {
                self.prepareStateForCycle(cycleNumber: cycleNumber)
            }

            let cycleOutcome: CycleOutcome
            do {
                cycleOutcome = try await self.runSingleCycle(cycleNumber: cycleNumber)
            } catch is CancellationError {
                return
            } catch let AIConnectionRuntimeLoopError.providerFailure(failure) {
                await MainActor.run {
                    self.handleCycleFailure(
                        cycleNumber: cycleNumber,
                        message: failure.message,
                        providerFailure: failure
                    )
                }

                currentCycle += 1
                if Task.isCancelled {
                    return
                }
                do {
                    try await self.scheduleNextCycle(after: Self.interCycleDelayNanoseconds, reason: .recovery)
                } catch is CancellationError {
                    return
                } catch {
                    await MainActor.run {
                        self.handleCycleFailure(cycleNumber: cycleNumber, message: error.localizedDescription)
                    }
                    return
                }
                continue
            } catch {
                await MainActor.run {
                    self.handleCycleFailure(cycleNumber: cycleNumber, message: error.localizedDescription)
                }

                currentCycle += 1
                if Task.isCancelled {
                    return
                }
                do {
                    try await self.scheduleNextCycle(after: Self.interCycleDelayNanoseconds, reason: .recovery)
                } catch is CancellationError {
                    return
                } catch {
                    await MainActor.run {
                        self.handleCycleFailure(cycleNumber: cycleNumber, message: error.localizedDescription)
                    }
                    return
                }
                continue
            }

            await MainActor.run {
                self.transitionStatus(.cycleCompleted)
                self.appendDebug(
                    kind: "cycle.completed",
                    summary: cycleOutcome.completedSummary(cycleNumber: cycleNumber)
                )
            }

            currentCycle += 1
            if Task.isCancelled {
                return
            }

            guard cycleOutcome == .completed else {
                continue
            }

            do {
                try await self.scheduleNextCycle(after: Self.interCycleDelayNanoseconds, reason: .normalCompletion)
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.handleCycleFailure(cycleNumber: cycleNumber, message: error.localizedDescription)
                }
                return
            }
        }
    }

    private func runSingleCycle(cycleNumber: Int) async throws -> CycleOutcome {
        var conversationMessages = await MainActor.run {
            self.bootstrapConversationMessages()
        }
        var requestIndex = 0

        while !Task.isCancelled {
            requestIndex += 1
            let request = await MainActor.run {
                AIProviderRequest(
                    model: "",
                    messages: conversationMessages,
                    tools: self.state.availableToolDefinitions,
                    temperature: 0.7,
                    maxOutputTokens: nil,
                    cacheMode: .automatic
                )
            }

            let response = try await self.streamSingleResponse(
                request: request,
                cycleNumber: cycleNumber,
                requestIndex: requestIndex
            )
            let toolCalls = response.toolCalls
            conversationMessages.append(
                await MainActor.run {
                    self.assistantConversationMessage(text: response.text, toolCalls: toolCalls)
                }
            )

            guard !toolCalls.isEmpty else {
                return .completed
            }

            let toolOutcome = await self.executeToolCalls(toolCalls, conversationMessages: conversationMessages)
            conversationMessages = toolOutcome.conversationMessages
            if toolOutcome.endsCycleAtIdleBoundary {
                return .waitedForEvent
            }
        }

        throw CancellationError()
    }

    private func prepareStateForNewRun(userPrompt: String) {
        let runStartedAt = Date()
        state.runId = UUID()
        state.startedAt = runStartedAt
        state.endedAt = nil
        state.systemPrompt = AIConnectionRuntimeService.systemPrompt
        state.userPrompt = userPrompt
        state.assistantText = ""
        state.reasoningText = ""
        state.toolCalls = []
        state.usage = AIRunUsageState()
        state.usage.runStartedAt = runStartedAt
        state.errors = []
        state.lastProviderFailure = nil
        state.debugEvents = []
        state.currentPhaseStartedAt = runStartedAt

        toolCallIndexByID = [:]

        appendDebug(kind: "runtime.started", summary: "Continuous runtime loop started.")
        transitionStatus(.initializing)
    }

    private func prepareStateForCycle(cycleNumber: Int) {
        let cycleStartedAt = Date()
        state.assistantText = ""
        state.reasoningText = ""
        state.toolCalls = []
        state.usage = AIRunUsageState()
        state.usage.runStartedAt = cycleStartedAt
        toolCallIndexByID = [:]

        transitionStatus(.initializing)
        appendDebug(kind: "cycle.started", summary: "Cycle \(cycleNumber) started.")
    }

    private func bootstrapConversationMessages() -> [AIConversationMessage] {
        [
            AIConversationMessage(role: .system, content: state.systemPrompt),
            AIConversationMessage(role: .user, content: state.userPrompt)
        ]
    }

    private func streamSingleResponse(
        request: AIProviderRequest,
        cycleNumber: Int,
        requestIndex: Int
    ) async throws -> AIProviderResponse {
        await MainActor.run {
            self.transitionStatus(.promptProcessing)
            self.appendDebug(
                kind: "tool.loop.request",
                summary: "Streaming cycle \(cycleNumber), request \(requestIndex)."
            )
        }

        var completedResponse: AIProviderResponse?
        for try await event in streamingService.streamEvents(for: request) {
            if Task.isCancelled {
                throw CancellationError()
            }
            if case let .failed(failure) = event {
                throw AIConnectionRuntimeLoopError.providerFailure(failure)
            }
            await MainActor.run {
                if let response = self.handle(event: event) {
                    completedResponse = response
                }
            }
        }

        if let completedResponse {
            return completedResponse
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        throw AIConnectionRuntimeLoopError.missingCompletedResponse
    }

    private func executeToolCalls(
        _ toolCalls: [AIRequestedToolCall],
        conversationMessages: [AIConversationMessage]
    ) async -> ToolExecutionOutcome {
        var updatedConversationMessages = conversationMessages

        for toolCall in toolCalls {
            if Task.isCancelled {
                return ToolExecutionOutcome(
                    conversationMessages: updatedConversationMessages,
                    endsCycleAtIdleBoundary: false
                )
            }

            await MainActor.run {
                self.transitionStatus(self.statusForToolExecution(named: toolCall.name))
                self.markToolCallExecuting(id: toolCall.id)
                self.appendDebug(kind: "tool.execution.start", summary: "\(toolCall.name) id=\(toolCall.id)")
            }

            let result = await streamingService.executeToolCall(toolCall)
            let toolMessage = await MainActor.run {
                self.toolResultMessage(result: result)
            }

            await MainActor.run {
                self.applyToolExecutionResult(toolCallID: toolCall.id, result: result)
            }

            if toolCall.name == "wait_for_event", result.success {
                await MainActor.run {
                    self.appendDebug(
                        kind: "cycle.idle_boundary",
                        summary: "wait_for_event returned; the next cycle will start with fresh context."
                    )
                }
                return ToolExecutionOutcome(
                    conversationMessages: updatedConversationMessages,
                    endsCycleAtIdleBoundary: true
                )
            }

            updatedConversationMessages.append(
                AIConversationMessage(
                    role: .tool,
                    content: toolMessage,
                    name: toolCall.name,
                    toolCallID: toolCall.id
                )
            )
        }

        return ToolExecutionOutcome(
            conversationMessages: updatedConversationMessages,
            endsCycleAtIdleBoundary: false
        )
    }

    private func handle(event: AIStreamEvent) -> AIProviderResponse? {
        let now = Date()
        switch event {
        case let .requestStarted(provider, model):
            appendDebug(kind: "stream.request_started", summary: "\(provider.displayName) / \(model)")
        case let .responseStarted(id):
            appendDebug(kind: "stream.response_started", summary: "responseId=\(id ?? "nil")")
        case let .textDelta(delta):
            transitionStatus(.receivingOutput)
            state.assistantText += delta
            recordFirstTokenIfNeeded(at: now)
            updateUsageEstimates(at: now)
        case let .reasoningDelta(delta):
            transitionStatus(.reasoning)
            state.reasoningText += delta
            recordFirstTokenIfNeeded(at: now)
            updateUsageEstimates(at: now)
        case let .toolCallStarted(id, name):
            transitionStatus(.executingTool)
            upsertToolCallStarted(id: id, name: name, at: now)
        case let .toolCallArgumentsDelta(id, delta):
            transitionStatus(.executingTool)
            upsertToolCallArgumentsDelta(id: id, delta: delta)
        case let .toolCallCompleted(toolCall):
            transitionStatus(.executingTool)
            upsertToolCallCompleted(toolCall: toolCall, at: now)
        case let .usage(usage):
            state.usage.inputTokens = usage.promptTokens
            state.usage.outputTokens = usage.completionTokens
            state.usage.totalTokens = usage.totalTokens
            state.usage.isOutputTokensEstimated = false
            state.usage.lastUpdatedAt = now
            updateUsageLiveMetrics(at: now)
        case let .completed(response):
            if !response.reasoning.isEmpty && state.reasoningText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.reasoningText = response.reasoning
            }
            if let usage = response.usage {
                state.usage.inputTokens = usage.promptTokens
                state.usage.outputTokens = usage.completionTokens
                state.usage.totalTokens = usage.totalTokens
                state.usage.isOutputTokensEstimated = false
            }
            finalizeToolCallsArgumentsIfNeeded()
            state.usage.lastUpdatedAt = now
            updateUsageLiveMetrics(at: now)
            appendDebug(kind: "stream.completed", summary: "finishReason=\(response.finishReason ?? "nil"), toolCalls=\(response.toolCalls.count)")
            transitionStatus(.waitingUser)
            return response
        case .failed:
            break
        }
        return nil
    }

    private func transitionStatus(_ status: AIConnectionRuntimeStatus) {
        guard state.status != status else { return }
        state.status = status
        state.currentPhaseStartedAt = Date()
    }

    private func handleCycleFailure(cycleNumber: Int, message: String, providerFailure: AIProviderFailure? = nil) {
        if let providerFailure {
            state.lastProviderFailure = providerFailure
        }
        state.errors.append(message)
        appendDebug(kind: "cycle.failed", summary: "Cycle \(cycleNumber) failed: \(message)")
        if let providerFailure {
            appendDebug(kind: "provider.failed", summary: providerFailureSummary(providerFailure))
        }
        persistCycleFailureLog(cycleNumber: cycleNumber, message: message)
        finalizeToolCallsAsFailedIfNeeded(message: message)
        finalizeUsageOnCycleEnd()
        transitionStatus(.recovering)
    }

    private func markCancelled() {
        guard state.status.isRunningLike else { return }
        appendDebug(kind: "runtime.stopped", summary: "Runtime stopped/cancelled.")
        appendDebug(kind: "stream.cancelled", summary: "Run was cancelled.")
        finalizeToolCallsAsCancelledIfNeeded()
        finalizeUsageOnCycleEnd()
        transitionStatus(.cancelled)
        state.endedAt = Date()
    }

    private func upsertToolCallStarted(id: String, name: String, at time: Date) {
        if let index = toolCallIndexByID[id] {
            state.toolCalls[index].name = name
            state.toolCalls[index].status = .started
            return
        }

        let call = AIRunToolCallState(
            id: id,
            name: name,
            icon: toolDefinition(named: name)?.icon,
            argumentsJSON: "",
            responseText: nil,
            errorText: nil,
            status: .started,
            startedAt: time,
            endedAt: nil,
            rawEventSummary: "tool call started"
        )

        state.toolCalls.append(call)
        toolCallIndexByID[id] = state.toolCalls.count - 1
    }

    private func upsertToolCallArgumentsDelta(id: String, delta: String) {
        guard let index = toolCallIndexByID[id] else { return }
        state.toolCalls[index].argumentsJSON += delta
        state.toolCalls[index].status = .argumentsStreaming
    }

    private func upsertToolCallCompleted(toolCall: AIRequestedToolCall, at time: Date) {
        if let index = toolCallIndexByID[toolCall.id] {
            state.toolCalls[index].name = toolCall.name
            state.toolCalls[index].argumentsJSON = toolCall.argumentsJSON
            state.toolCalls[index].status = .argumentsReady
            state.toolCalls[index].endedAt = nil
            state.toolCalls[index].icon = toolDefinition(named: toolCall.name)?.icon
            state.toolCalls[index].rawEventSummary = "tool call arguments ready"
            return
        }

        let call = AIRunToolCallState(
            id: toolCall.id,
            name: toolCall.name,
            icon: toolDefinition(named: toolCall.name)?.icon,
            argumentsJSON: toolCall.argumentsJSON,
            responseText: nil,
            errorText: nil,
            status: .argumentsReady,
            startedAt: time,
            endedAt: nil,
            rawEventSummary: "tool call arguments ready"
        )
        state.toolCalls.append(call)
        toolCallIndexByID[toolCall.id] = state.toolCalls.count - 1
    }

    private func finalizeToolCallsArgumentsIfNeeded() {
        for index in state.toolCalls.indices {
            if state.toolCalls[index].status == .argumentsStreaming || state.toolCalls[index].status == .started {
                state.toolCalls[index].status = .argumentsReady
            }
        }
    }

    private func finalizeToolCallsAsCancelledIfNeeded() {
        let now = Date()
        for index in state.toolCalls.indices where state.toolCalls[index].status != .completed && state.toolCalls[index].status != .failed {
            state.toolCalls[index].status = .cancelled
            state.toolCalls[index].endedAt = now
        }
    }

    private func finalizeToolCallsAsFailedIfNeeded(message: String) {
        let now = Date()
        for index in state.toolCalls.indices where state.toolCalls[index].status != .completed && state.toolCalls[index].status != .failed {
            state.toolCalls[index].status = .failed
            state.toolCalls[index].errorText = message
            state.toolCalls[index].endedAt = now
        }
    }

    private func recordFirstTokenIfNeeded(at time: Date) {
        guard state.usage.timeToFirstToken == nil else { return }
        if let runStartedAt = state.usage.runStartedAt ?? state.startedAt {
            state.usage.timeToFirstToken = time.timeIntervalSince(runStartedAt)
        }
    }

    private func updateUsageEstimates(at time: Date) {
        guard state.usage.outputTokens == nil else {
            updateUsageLiveMetrics(at: time)
            return
        }

        let estimatedTokens = Self.estimateTokenCount(text: state.assistantText + state.reasoningText)
        state.usage.outputTokens = estimatedTokens
        state.usage.isOutputTokensEstimated = true

        if let input = state.usage.inputTokens {
            state.usage.totalTokens = input + estimatedTokens
        }

        state.usage.lastUpdatedAt = time
        updateUsageLiveMetrics(at: time)
    }

    private func updateUsageLiveMetrics(at time: Date) {
        guard let runStartedAt = state.usage.runStartedAt ?? state.startedAt else { return }
        state.usage.runDuration = time.timeIntervalSince(runStartedAt)

        if let outputTokens = state.usage.outputTokens,
           let timeToFirstToken = state.usage.timeToFirstToken {
            let firstTokenAt = runStartedAt.addingTimeInterval(timeToFirstToken)
            if time > firstTokenAt {
                let elapsed = time.timeIntervalSince(firstTokenAt)
                state.usage.tokensPerSecond = elapsed > 0 ? Double(outputTokens) / elapsed : nil
            }
        }
    }

    private func finalizeUsageOnCycleEnd() {
        updateUsageLiveMetrics(at: Date())
    }

    private func persistCycleFailureLog(cycleNumber: Int, message: String) {
        let payload = AIConnectionErrorLogStore.FailureLogPayload(
            recordedAt: Date(),
            runId: state.runId?.uuidString,
            cycleNumber: cycleNumber,
            message: message,
            status: state.status.rawValue,
            userPrompt: state.userPrompt,
            assistantText: state.assistantText,
            reasoningText: state.reasoningText,
            accumulatedErrors: state.errors,
            providerFailure: state.lastProviderFailure.map {
                AIConnectionErrorLogStore.ProviderFailurePayload(
                    message: $0.message,
                    provider: $0.provider?.rawValue,
                    model: $0.model,
                    endpoint: $0.endpoint,
                    statusCode: $0.statusCode,
                    responseHeaders: $0.responseHeaders,
                    responseBody: $0.responseBody,
                    requestBody: $0.requestBody,
                    requestMessageCount: $0.requestMessageCount,
                    requestToolCount: $0.requestToolCount,
                    underlyingError: $0.underlyingError
                )
            },
            toolCalls: state.toolCalls.map {
                AIConnectionErrorLogStore.ToolCallPayload(
                    id: $0.id,
                    name: $0.name,
                    status: $0.status.rawValue,
                    argumentsJSON: $0.argumentsJSON,
                    responseText: $0.responseText,
                    errorText: $0.errorText,
                    startedAt: $0.startedAt,
                    endedAt: $0.endedAt
                )
            },
            debugEvents: state.debugEvents.map {
                AIConnectionErrorLogStore.DebugEventPayload(
                    kind: $0.kind,
                    summary: $0.summary,
                    timestamp: $0.timestamp
                )
            }
        )

        do {
            let fileURL = try errorLogStore.writeFailureLog(payload)
            appendDebug(kind: "cycle.failure_log.saved", summary: "Saved failure log to \(fileURL.path).")
        } catch {
            appendDebug(kind: "cycle.failure_log.failed", summary: "Failed to persist cycle failure log: \(error.localizedDescription)")
        }
    }

    private func scheduleNextCycle(after delayNanoseconds: UInt64, reason: NextCycleReason) async throws {
        await MainActor.run {
            self.appendDebug(
                kind: "cycle.scheduled",
                summary: reason.summary(delayMilliseconds: delayNanoseconds / 1_000_000)
            )
        }
        try await Task.sleep(nanoseconds: delayNanoseconds)
    }

    private func toolDefinition(named name: String) -> AIToolDefinition? {
        state.availableToolDefinitions.first(where: { $0.name == name })
    }

    private func assistantConversationMessage(
        text: String,
        toolCalls: [AIRequestedToolCall]
    ) -> AIConversationMessage {
        AIConversationMessage(
            role: .assistant,
            content: text.isEmpty ? nil : text,
            toolCalls: toolCalls
        )
    }

    private func statusForToolExecution(named toolName: String) -> AIConnectionRuntimeStatus {
        guard let tool = toolDefinition(named: toolName) else {
            return .executingTool
        }

        if toolName == "wait_for_event" {
            return .waitingEvent
        }

        if tool.traits.contains(.blocking) {
            return .waitingUser
        }

        return .executingTool
    }

    private static func estimateTokenCount(text: String) -> Int {
        let chars = max(text.count, 0)
        return max(1, Int((Double(chars) / 4.0).rounded(.up)))
    }

    private enum CycleOutcome: Equatable {
        case completed
        case waitedForEvent

        func completedSummary(cycleNumber: Int) -> String {
            switch self {
            case .completed:
                return "Cycle \(cycleNumber) completed normally."
            case .waitedForEvent:
                return "Cycle \(cycleNumber) ended at the wait_for_event idle boundary."
            }
        }
    }

    private enum NextCycleReason {
        case normalCompletion
        case recovery

        func summary(delayMilliseconds: UInt64) -> String {
            switch self {
            case .normalCompletion:
                return "Next cycle scheduled after \(delayMilliseconds)ms."
            case .recovery:
                return "Next cycle scheduled after \(delayMilliseconds)ms to recover from failure."
            }
        }
    }

    private struct ToolExecutionOutcome {
        let conversationMessages: [AIConversationMessage]
        let endsCycleAtIdleBoundary: Bool
    }

    private func appendDebug(kind: String, summary: String) {
        state.debugEvents.append(
            AIRunDebugEventState(
                kind: kind,
                summary: summary,
                timestamp: Date()
            )
        )

        if state.debugEvents.count > Self.maxDebugEvents {
            state.debugEvents.removeFirst(state.debugEvents.count - Self.maxDebugEvents)
        }
    }

    private func providerFailureSummary(_ failure: AIProviderFailure) -> String {
        var parts: [String] = [failure.message]
        if let statusCode = failure.statusCode {
            parts.append("status=\(statusCode)")
        }
        if let endpoint = failure.endpoint {
            parts.append("endpoint=\(endpoint)")
        }
        if let body = failure.responseBody?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            let compactBody = body.count > 240 ? String(body.prefix(240)) + "..." : body
            parts.append("body=\(compactBody)")
        }
        return parts.joined(separator: " | ")
    }

    private func markToolCallExecuting(id: String) {
        guard let index = toolCallIndexByID[id] else { return }
        state.toolCalls[index].status = .executing
        state.toolCalls[index].rawEventSummary = "tool execution running"
    }

    private func applyToolExecutionResult(toolCallID: String, result: AIToolExecutionResult) {
        guard let index = toolCallIndexByID[toolCallID] else { return }

        if result.success {
            state.toolCalls[index].status = .completed
            state.toolCalls[index].responseText = toolResultMessage(result: result)
            state.toolCalls[index].errorText = nil
            appendDebug(kind: "tool.execution.success", summary: "\(result.toolName) executed.")
        } else {
            state.toolCalls[index].status = .failed
            state.toolCalls[index].responseText = toolResultMessage(result: result)
            state.toolCalls[index].errorText = result.errorMessage
            appendDebug(kind: "tool.execution.failed", summary: "\(result.toolName) failed: \(result.errorMessage ?? "unknown error")")
        }
        state.toolCalls[index].endedAt = Date()
    }

    private func toolResultMessage(result: AIToolExecutionResult) -> String {
        var response: [String: AIJSONValue] = [
            "toolName": .string(result.toolName),
            "success": .bool(result.success)
        ]

        if let payload = result.payload {
            response["payload"] = payload
        } else {
            response["payload"] = .null
        }

        if let errorMessage = result.errorMessage {
            response["errorMessage"] = .string(errorMessage)
        }

        if let suggestedAction = result.suggestedAction {
            response["suggestedAction"] = .string(suggestedAction)
        }

        if let durationMilliseconds = result.durationMilliseconds {
            response["durationMilliseconds"] = .double(durationMilliseconds)
        }

        return (try? AIJSONValue.object(response).jsonString(prettyPrinted: false)) ?? "{\"success\":false}"
    }

    static let systemPrompt = loadSystemPrompt()

    private static func loadSystemPrompt() -> String {
        if let url = Bundle.main.url(forResource: "AssistantSystemPrompt", withExtension: "md"),
           let contents = try? String(contentsOf: url, encoding: .utf8),
           !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return contents
        }

        return """
        You are running inside the AI Connection Playground of a local-first macOS personal assistant app.

        Failed to load bundled AssistantSystemPrompt.md.
        Return a short diagnostic response acknowledging this fallback.
        """
    }
}

private enum AIConnectionRuntimeLoopError: LocalizedError {
    case missingCompletedResponse
    case providerFailure(AIProviderFailure)

    var errorDescription: String? {
        switch self {
        case .missingCompletedResponse:
            return "Provider stream ended without a completed response event."
        case let .providerFailure(failure):
            return failure.message
        }
    }
}
