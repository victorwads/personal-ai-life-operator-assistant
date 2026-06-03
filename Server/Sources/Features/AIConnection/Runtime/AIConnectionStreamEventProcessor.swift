import Foundation

@MainActor
final class AIConnectionStreamEventProcessor {
    private let toolCallTracker: AIConnectionToolCallTracker
    private let usageTracker: AIConnectionUsageTracker
    private let debugRecorder: AIConnectionRuntimeDebugRecorder
    private let runtimeLogger: AIConnectionRuntimeLogger

    init(
        toolCallTracker: AIConnectionToolCallTracker,
        usageTracker: AIConnectionUsageTracker,
        debugRecorder: AIConnectionRuntimeDebugRecorder,
        runtimeLogger: AIConnectionRuntimeLogger
    ) {
        self.toolCallTracker = toolCallTracker
        self.usageTracker = usageTracker
        self.debugRecorder = debugRecorder
        self.runtimeLogger = runtimeLogger
    }

    func handle(
        _ event: AIStreamEvent,
        state: inout AIConnectionRuntimeState,
        requestContext: inout AIConnectionRequestLogContext?
    ) -> AIProviderResponse? {
        let now = Date()
        switch event {
        case let .requestStarted(provider, model):
            requestContext?.provider = provider
            requestContext?.model = model
            debugRecorder.append(kind: "stream.request_started", summary: "\(provider.displayName) / \(model)", to: &state)
        case let .responseStarted(id):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            requestContext?.responseId = id
            debugRecorder.append(kind: "stream.response_started", summary: "responseId=\(id ?? "nil")", to: &state)
        case let .textDelta(delta):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            transitionStatus(.receivingOutput, state: &state)
            state.assistantText += delta
            usageTracker.recordFirstTokenIfNeeded(at: now, state: &state)
            usageTracker.updateEstimatedOutputTokens(at: now, state: &state)
        case let .reasoningDelta(delta):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            transitionStatus(.reasoning, state: &state)
            state.reasoningText += delta
            usageTracker.recordFirstTokenIfNeeded(at: now, state: &state)
            usageTracker.updateEstimatedOutputTokens(at: now, state: &state)
        case let .toolCallStarted(id, name):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            transitionStatus(.executingTool, state: &state)
            toolCallTracker.upsertToolCallStarted(
                id: id,
                name: name,
                at: now,
                availableToolDefinitions: state.availableToolDefinitions,
                state: &state
            )
        case let .toolCallArgumentsDelta(id, delta):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            transitionStatus(.executingTool, state: &state)
            toolCallTracker.upsertToolCallArgumentsDelta(id: id, delta: delta, state: &state)
        case let .toolCallCompleted(toolCall):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            transitionStatus(.executingTool, state: &state)
            toolCallTracker.upsertToolCallCompleted(
                toolCall: toolCall,
                at: now,
                availableToolDefinitions: state.availableToolDefinitions,
                state: &state
            )
        case let .usage(usage):
            runtimeLogger.persistPromptProcessingIfNeeded(
                at: now,
                runId: state.runId?.uuidString,
                requestContext: &requestContext
            )
            usageTracker.applyProviderUsage(usage, at: now, state: &state)
        case let .completed(response):
            if !response.reasoning.isEmpty &&
                state.reasoningText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.reasoningText = response.reasoning
            }
            if let usage = response.usage {
                usageTracker.applyProviderUsage(usage, at: now, state: &state)
            } else {
                state.usage.lastUpdatedAt = now
                usageTracker.updateLiveMetrics(at: now, state: &state)
            }
            toolCallTracker.finalizeArgumentsIfNeeded(state: &state)
            debugRecorder.append(
                kind: "stream.completed",
                summary: "finishReason=\(response.finishReason ?? "nil"), toolCalls=\(response.toolCalls.count)",
                to: &state
            )
            runtimeLogger.logCompletedResponse(
                state: state,
                response: response,
                requestContext: requestContext
            )
            requestContext = nil
            transitionStatus(.waitingUser, state: &state)
            return response
        case .failed:
            break
        }
        return nil
    }

    private func transitionStatus(
        _ status: AIConnectionRuntimeStatus,
        state: inout AIConnectionRuntimeState
    ) {
        guard state.status != status else { return }
        state.status = status
        state.currentPhaseStartedAt = Date()
    }
}
