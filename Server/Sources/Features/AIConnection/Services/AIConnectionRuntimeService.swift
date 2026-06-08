import Foundation

@MainActor
final class AIConnectionRuntimeService: ObservableObject {
    @Published private(set) var state: AIConnectionRuntimeState

    private let streamingService: any AIConnectionStreamingServing
    private let requestBuilder: AIConnectionRequestBuilder
    private let conversationBuilder: AIConnectionConversationContextBuilder
    private let memoryBootstrapProvider: @MainActor () async -> AIConversationMessage?
    private let pendingWorkBootstrapProvider: @MainActor () async -> AIConversationMessage?
    private let systemPromptProvider: @MainActor () -> String
    private let providerConfigurationProvider: @MainActor () -> AIConnectionProviderConfiguration
    private let usageTracker: AIConnectionUsageTracker
    private let debugRecorder: AIConnectionRuntimeDebugRecorder
    private let toolCallTracker: AIConnectionToolCallTracker
    private let runtimeLogger: AIConnectionRuntimeLogger
    private let resourceUsageRepository: any AIResourceUsageRepository
    private let eventProcessor: AIConnectionStreamEventProcessor

    private var activeStreamingTask: Task<Void, Never>?
    private var currentRequestLogContext: AIConnectionRequestLogContext?

    private static let interCycleDelayNanoseconds: UInt64 = 500_000_000
    private static let maxCorrectionRetriesPerCycle = 2
    private static let defaultServerLogsService = ServerLogsService(
        repository: SQLiteServerLogRepository(profileId: "ai-connection-default")
    )

    init(
        streamingService: any AIConnectionStreamingServing,
        memoryBootstrapProvider: @escaping @MainActor () async -> AIConversationMessage? = { nil },
        pendingWorkBootstrapProvider: @escaping @MainActor () async -> AIConversationMessage? = { nil },
        systemPromptProvider: @escaping @MainActor () -> String = { AIConnectionRuntimeDefaults.baseSystemPrompt },
        providerConfigurationProvider: @escaping @MainActor () -> AIConnectionProviderConfiguration = {
            AIConnectionProviderConfiguration(
                providerKind: .openRouter,
                baseURL: "",
                apiKey: "",
                model: "",
                temperature: 0.6,
                reasoningEffort: .off,
                maxOutputTokens: nil,
                streamingEnabled: true,
                cacheMode: .automatic
            )
        },
        runtimeLogger: AIConnectionRuntimeLogger? = nil,
        errorLogStore: AIConnectionErrorLogStore = AIConnectionErrorLogStore(),
        resourceUsageRepository: any AIResourceUsageRepository = NoopAIResourceUsageRepository(),
        serverLogsProvider: @escaping @MainActor () -> ServerLogsService = {
            AIConnectionRuntimeService.defaultServerLogsService
        }
    ) {
        self.streamingService = streamingService
        self.requestBuilder = AIConnectionRequestBuilder()
        self.conversationBuilder = AIConnectionConversationContextBuilder()
        self.memoryBootstrapProvider = memoryBootstrapProvider
        self.pendingWorkBootstrapProvider = pendingWorkBootstrapProvider
        self.systemPromptProvider = systemPromptProvider
        self.providerConfigurationProvider = providerConfigurationProvider
        self.usageTracker = AIConnectionUsageTracker()
        self.debugRecorder = AIConnectionRuntimeDebugRecorder(maxEvents: 200)
        self.toolCallTracker = AIConnectionToolCallTracker()
        self.resourceUsageRepository = resourceUsageRepository
        self.runtimeLogger = runtimeLogger ?? AIConnectionRuntimeLogger(
            errorLogStore: errorLogStore,
            serverLogsProvider: serverLogsProvider
        )
        self.eventProcessor = AIConnectionStreamEventProcessor(
            toolCallTracker: toolCallTracker,
            usageTracker: usageTracker,
            debugRecorder: debugRecorder,
            runtimeLogger: self.runtimeLogger
        )
        self.state = .initial(systemPrompt: AIConnectionRuntimeDefaults.baseSystemPrompt)
    }

    func refreshSystemPrompt() {
        state.systemPrompt = systemPromptProvider()
    }

    func loadTools() async {
        guard !state.isLoadingTools else { return }
        state.isLoadingTools = true
        defer { state.isLoadingTools = false }

        let loadedTools = await streamingService.availableTools().sorted { $0.name < $1.name }
        state.availableToolDefinitions = loadedTools
        appendDebug(kind: "tools.loaded", summary: "Loaded \(loadedTools.count) tool definition(s).")
    }

    func startRun() {
        guard state.canStart, activeStreamingTask == nil else {
            state.errors.append("A run is already active. Cancel or reset before starting another.")
            appendDebug(kind: "run.start.rejected", summary: "Attempted to start while another run was active.")
            return
        }

        prepareStateForNewRun()

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
        currentRequestLogContext = nil
        toolCallTracker.reset()
        state = .initial(
            systemPrompt: systemPromptProvider(),
            availableToolDefinitions: state.availableToolDefinitions
        )
    }

    private func runContinuousLoop() async {
        var currentCycle = 0

        while !Task.isCancelled {
            let cycleNumber = currentCycle + 1
            await MainActor.run {
                self.prepareStateForCycle(cycleNumber: cycleNumber)
            }

            let cycleOutcome: AIConnectionCycleOutcome
            do {
                cycleOutcome = try await runSingleCycle(cycleNumber: cycleNumber)
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
                    try await scheduleNextCycle(
                        after: Self.interCycleDelayNanoseconds,
                        reason: .recovery
                    )
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
                    try await scheduleNextCycle(
                        after: Self.interCycleDelayNanoseconds,
                        reason: .recovery
                    )
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
                runtimeLogger.logCycleCompleted(
                    state: state,
                    outcome: cycleOutcome,
                    cycleNumber: cycleNumber,
                    requestContext: currentRequestLogContext
                )
                transitionStatus(.cycleCompleted)
                appendDebug(
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
                try await scheduleNextCycle(
                    after: Self.interCycleDelayNanoseconds,
                    reason: .normalCompletion
                )
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

    private func runSingleCycle(cycleNumber: Int) async throws -> AIConnectionCycleOutcome {
        let memoryBootstrapMessage = await memoryBootstrapProvider()
        let pendingWorkBootstrapMessage = await pendingWorkBootstrapProvider()
        var conversationMessages = await MainActor.run {
            let bootstrapMessages = [memoryBootstrapMessage, pendingWorkBootstrapMessage].compactMap { $0 }
            if state.promptSections.isEmpty {
                let promptSections = buildPromptSections(
                    systemPrompt: state.systemPrompt,
                    pendingWorkBootstrapMessage: pendingWorkBootstrapMessage
                )
                state.promptSections = promptSections
            }
            return conversationBuilder.bootstrapConversationMessages(
                systemPrompt: state.systemPrompt,
                bootstrapMessages: bootstrapMessages
            )
        }
        var requestIndex = 0
        var correctionRetryCount = 0
        var hasCalledTerminalAction = false

        while !Task.isCancelled {
            requestIndex += 1
            let request = await MainActor.run {
                requestBuilder.buildRequest(
                    messages: conversationMessages,
                    availableToolDefinitions: state.availableToolDefinitions,
                    configuration: providerConfigurationProvider()
                )
            }

            let response = try await streamSingleResponse(
                request: request,
                cycleNumber: cycleNumber,
                requestIndex: requestIndex
            )
            let toolCalls = response.toolCalls
            let assistantMessage = await MainActor.run {
                conversationBuilder.assistantConversationMessage(
                    text: response.text,
                    toolCalls: toolCalls
                )
            }
            conversationMessages.append(assistantMessage)

            let terminalActionTools: Set<String> = ["wait_for_event", "ask_to_client", "send_message", "announce_to_client"]

            if !toolCalls.isEmpty {
                if toolCalls.contains(where: { terminalActionTools.contains($0.name) }) {
                    hasCalledTerminalAction = true
                }

                let toolOutcome = await executeToolCalls(
                    toolCalls,
                    conversationMessages: conversationMessages
                )
                conversationMessages = toolOutcome.conversationMessages
                if toolOutcome.endsCycleAtIdleBoundary {
                    return .waitedForEvent
                }
                continue
            }

            if !hasCalledTerminalAction {
                await MainActor.run {
                    appendDebug(
                        kind: "runtime.autocorrection.missing_terminal_action",
                        summary: "The model completed without calling wait_for_event or another terminal action. Continuing same session with correction."
                    )
                }

                if correctionRetryCount >= Self.maxCorrectionRetriesPerCycle {
                    await MainActor.run {
                        appendDebug(
                            kind: "assistant.correction.retry_exhausted",
                            summary: "Cycle \(cycleNumber) exhausted \(Self.maxCorrectionRetriesPerCycle) corrective retr\(Self.maxCorrectionRetriesPerCycle == 1 ? "y" : "ies")."
                        )
                    }
                    throw AIConnectionRuntimeLoopError.missingTerminalAction(
                        retriesExhausted: correctionRetryCount
                    )
                }

                correctionRetryCount += 1
                let correctiveMessage = await MainActor.run {
                    conversationBuilder.missingTerminalActionCorrectionMessage()
                }
                conversationMessages.append(correctiveMessage)

                await MainActor.run {
                    appendDebug(
                        kind: "assistant.correction.context_preserved",
                        summary: "Preserving the current conversation context for corrective retry \(correctionRetryCount)."
                    )
                    appendDebug(
                        kind: "assistant.correction.user_message_appended",
                        summary: "Appended runtime correction message after missing terminal action."
                    )
                    appendDebug(
                        kind: "assistant.correction.retry_started",
                        summary: "Starting corrective retry \(correctionRetryCount) in the same conversation context."
                    )
                }
                continue
            }

            if let invalidAssistantText = conversationBuilder.invalidOperationalAssistantText(in: response) {
                await MainActor.run {
                    appendDebug(
                        kind: "assistant.invalid_text.detected",
                        summary: "Cycle \(cycleNumber), request \(requestIndex) returned plain assistant text without tool calls."
                    )
                }

                if correctionRetryCount >= Self.maxCorrectionRetriesPerCycle {
                    await MainActor.run {
                        appendDebug(
                            kind: "assistant.correction.retry_exhausted",
                            summary: "Cycle \(cycleNumber) exhausted \(Self.maxCorrectionRetriesPerCycle) corrective retr\(Self.maxCorrectionRetriesPerCycle == 1 ? "y" : "ies")."
                        )
                    }
                    throw AIConnectionRuntimeLoopError.invalidAssistantText(
                        invalidAssistantText,
                        retriesExhausted: correctionRetryCount
                    )
                }

                correctionRetryCount += 1
                let correctiveMessage = await MainActor.run {
                    conversationBuilder.runtimeCorrectionMessage(for: invalidAssistantText)
                }
                conversationMessages.append(correctiveMessage)

                await MainActor.run {
                    appendDebug(
                        kind: "assistant.correction.context_preserved",
                        summary: "Preserving the current conversation context for corrective retry \(correctionRetryCount)."
                    )
                    appendDebug(
                        kind: "assistant.correction.user_message_appended",
                        summary: "Appended runtime correction message after invalid assistant text."
                    )
                    appendDebug(
                        kind: "assistant.correction.retry_started",
                        summary: "Starting corrective retry \(correctionRetryCount) in the same conversation context."
                    )
                }
                continue
            }

            return .completed
        }

        throw CancellationError()
    }

    private func prepareStateForNewRun() {
        let runStartedAt = Date()
        let runId = UUID()
        state.runId = runId
        state.startedAt = runStartedAt
        state.endedAt = nil
        state.systemPrompt = systemPromptProvider()
        state.userPrompt = ""
        state.promptSections = []
        state.assistantText = ""
        state.reasoningText = ""
        state.toolCalls = []
        state.usage = AIRunUsageState()
        state.usage.runStartedAt = runStartedAt
        state.errors = []
        state.lastProviderFailure = nil
        state.debugEvents = []
        state.currentPhaseStartedAt = runStartedAt

        resourceUsageRepository.clearSessionUse()
        currentRequestLogContext = nil
        toolCallTracker.reset()

        appendDebug(kind: "runtime.started", summary: "Continuous runtime loop started.")
        transitionStatus(.initializing)
    }

    private func buildPromptSections(
        systemPrompt: String,
        pendingWorkBootstrapMessage: AIConversationMessage?
    ) -> [AIRunPromptSection] {
        var sections = [
            AIRunPromptSection(
                title: "System Prompt",
                roleLabel: AIConversationMessage.Role.system.rawValue,
                content: systemPrompt
            )
        ]

        if let content = pendingWorkBootstrapMessage?.content, !content.isEmpty {
            sections.append(
                AIRunPromptSection(
                    title: "Pending Work Bootstrap",
                    roleLabel: pendingWorkBootstrapMessage?.role.rawValue ?? AIConversationMessage.Role.user.rawValue,
                    content: content
                )
            )
        }

        return sections
    }

    private func prepareStateForCycle(cycleNumber: Int) {
        let cycleStartedAt = Date()
        state.assistantText = ""
        state.reasoningText = ""
        state.toolCalls = []
        state.usage = AIRunUsageState()
        state.usage.runStartedAt = cycleStartedAt
        currentRequestLogContext = nil
        toolCallTracker.reset()

        transitionStatus(.initializing)
        appendDebug(kind: "cycle.started", summary: "Cycle \(cycleNumber) started.")
    }

    private func streamSingleResponse(
        request: AIProviderRequest,
        cycleNumber: Int,
        requestIndex: Int
    ) async throws -> AIProviderResponse {
        await MainActor.run {
            currentRequestLogContext = AIConnectionRequestLogContext(
                cycleNumber: cycleNumber,
                requestIndex: requestIndex,
                startedAt: Date(),
                requestMessages: request.messages
            )
            usageTracker.applyEstimatedInputTokens(
                for: request,
                at: Date(),
                state: &state
            )
            appendDebug(
                kind: "usage.input.estimated",
                summary: "Estimated input tokens before streaming."
            )
            if cycleNumber == 1 && requestIndex == 1 {
                runtimeLogger.logSessionStarted(
                    state: state,
                    requestMessages: request.messages
                )
            }
            transitionStatus(.promptProcessing)
            appendDebug(
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
                if let response = eventProcessor.handle(
                    event,
                    state: &state,
                    requestContext: &currentRequestLogContext
                ) {
                    completedResponse = response
                }
            }
        }

        if let completedResponse {
            await resourceUsageRepository.add(
                AIResourceUsageAddition(
                    pool: .assistant,
                    provider: completedResponse.provider,
                    model: completedResponse.model,
                    usage: state.usage.normalizedAIUsage(),
                    success: true
                )
            )
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
    ) async -> AIConnectionToolExecutionOutcome {
        var updatedConversationMessages = conversationMessages

        for toolCall in toolCalls {
            if Task.isCancelled {
                return AIConnectionToolExecutionOutcome(
                    conversationMessages: updatedConversationMessages,
                    endsCycleAtIdleBoundary: false
                )
            }

            await MainActor.run {
                transitionStatus(
                    toolCallTracker.statusForExecution(
                        named: toolCall.name,
                        availableToolDefinitions: state.availableToolDefinitions
                    )
                )
                toolCallTracker.markExecuting(id: toolCall.id, state: &state)
                appendDebug(kind: "tool.execution.start", summary: "\(toolCall.name) id=\(toolCall.id)")
            }

            let result = await streamingService.executeToolCall(toolCall)
            let toolMessage = conversationBuilder.toolResultMessage(result: result)

            await MainActor.run {
                let completedCallState = toolCallTracker.applyExecutionResult(
                    toolCallID: toolCall.id,
                    result: result,
                    responseText: toolMessage,
                    completedAt: Date(),
                    state: &state
                )

                if completedCallState != nil {
                    appendDebug(
                        kind: result.success ? "tool.execution.success" : "tool.execution.failed",
                        summary: result.success
                            ? "\(result.toolName) executed."
                            : "\(result.toolName) failed: \(result.errorMessage ?? "unknown error")"
                    )
                }

                if let completedCallState {
                    runtimeLogger.logToolCallCompleted(
                        state: state,
                        callState: completedCallState,
                        toolCallID: toolCall.id,
                        result: result,
                        requestContext: currentRequestLogContext
                    )
                }
            }

            if toolCall.name == "wait_for_event", result.success {
                await MainActor.run {
                    appendDebug(
                        kind: "cycle.idle_boundary",
                        summary: "wait_for_event returned; the next cycle will start with fresh context."
                    )
                    appendDebug(
                        kind: "context.cleared.wait_for_event",
                        summary: "Clearing conversation context because wait_for_event reached the idle boundary."
                    )
                }
                return AIConnectionToolExecutionOutcome(
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

        return AIConnectionToolExecutionOutcome(
            conversationMessages: updatedConversationMessages,
            endsCycleAtIdleBoundary: false
        )
    }

    private func transitionStatus(_ status: AIConnectionRuntimeStatus) {
        guard state.status != status else { return }
        state.status = status
        state.currentPhaseStartedAt = Date()
    }

    private func handleCycleFailure(
        cycleNumber: Int,
        message: String,
        providerFailure: AIProviderFailure? = nil
    ) {
        if let providerFailure {
            state.lastProviderFailure = providerFailure
        }
        state.errors.append(message)
        appendDebug(kind: "cycle.failed", summary: "Cycle \(cycleNumber) failed: \(message)")
        appendDebug(
            kind: "context.cleared.error",
            summary: "Clearing conversation context because cycle \(cycleNumber) failed."
        )
        if let providerFailure {
            appendDebug(kind: "provider.failed", summary: runtimeLogger.providerFailureSummary(providerFailure))
        }

        runtimeLogger.logCycleFailure(
            state: state,
            cycleNumber: cycleNumber,
            message: message,
            providerFailure: providerFailure,
            requestContext: currentRequestLogContext
        )

        switch runtimeLogger.persistCycleFailureLog(
            state: state,
            cycleNumber: cycleNumber,
            message: message
        ) {
        case let .success(fileURL):
            appendDebug(kind: "cycle.failure_log.saved", summary: "Saved failure log to \(fileURL.path).")
        case let .failure(error):
            appendDebug(
                kind: "cycle.failure_log.failed",
                summary: "Failed to persist cycle failure log: \(error.localizedDescription)"
            )
        }

        toolCallTracker.finalizeAsFailedIfNeeded(message: message, at: Date(), state: &state)
        usageTracker.finalize(at: Date(), state: &state)
        currentRequestLogContext = nil
        transitionStatus(.recovering)
    }

    private func markCancelled() {
        guard state.status.isRunningLike else { return }
        appendDebug(kind: "runtime.stopped", summary: "Runtime stopped/cancelled.")
        appendDebug(kind: "stream.cancelled", summary: "Run was cancelled.")
        let endedAt = Date()
        toolCallTracker.finalizeAsCancelledIfNeeded(at: endedAt, state: &state)
        usageTracker.finalize(at: endedAt, state: &state)
        state.endedAt = endedAt
        runtimeLogger.logCancelled(
            state: state,
            endedAt: endedAt,
            requestContext: currentRequestLogContext
        )
        currentRequestLogContext = nil
        transitionStatus(.cancelled)
    }

    private func scheduleNextCycle(
        after delayNanoseconds: UInt64,
        reason: AIConnectionNextCycleReason
    ) async throws {
        await MainActor.run {
            appendDebug(
                kind: "cycle.scheduled",
                summary: reason.summary(delayMilliseconds: delayNanoseconds / 1_000_000)
            )
        }
        try await Task.sleep(nanoseconds: delayNanoseconds)
    }

    private func appendDebug(kind: String, summary: String) {
        debugRecorder.append(kind: kind, summary: summary, to: &state)
    }
}
