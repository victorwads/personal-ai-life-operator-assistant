import Foundation

@MainActor
final class AIConnectionRuntimeLogger {
    private let errorLogStore: AIConnectionErrorLogStore
    private let serverLogsProvider: @MainActor () -> ServerLogsService

    init(
        errorLogStore: AIConnectionErrorLogStore,
        serverLogsProvider: @escaping @MainActor () -> ServerLogsService
    ) {
        self.errorLogStore = errorLogStore
        self.serverLogsProvider = serverLogsProvider
    }

    func logSessionStarted(
        state: AIConnectionRuntimeState,
        requestMessages: [AIConversationMessage]
    ) {
        log(
            kind: .sessionStarted,
            severity: .info,
            title: "AI Connection session started",
            summary: "Continuous runtime loop started.",
            sessionId: state.runId?.uuidString,
            runId: state.runId?.uuidString,
            inputPayload: requestMessagesPayload(requestMessages),
            metadataPayload: ServerLogPayloadEncoder.objectString([
                ("availableToolCount", .int(state.availableToolDefinitions.count)),
                ("bootstrapMessageCount", .int(max(0, requestMessages.count - 1)))
            ])
        )
    }

    func logCycleFailure(
        state: AIConnectionRuntimeState,
        cycleNumber: Int,
        message: String,
        providerFailure: AIProviderFailure?,
        requestContext: AIConnectionRequestLogContext?
    ) {
        log(
            kind: .sessionFailed,
            severity: .error,
            title: "AI Connection session failed",
            summary: "Cycle \(cycleNumber) failed: \(message)",
            sessionId: state.runId?.uuidString,
            runId: state.runId?.uuidString,
            cycleNumber: cycleNumber,
            success: false,
            inputPayload: requestContext.flatMap { requestMessagesPayload($0.requestMessages) },
            outputPayload: ServerLogPayloadEncoder.objectString([
                ("assistantText", state.assistantText.isEmpty ? nil : .string(state.assistantText)),
                ("reasoningText", state.reasoningText.isEmpty ? nil : .string(state.reasoningText))
            ]),
            errorPayload: providerFailure.map(ServerLogPayloadEncoder.jsonString) ?? message,
            metadataPayload: ServerLogPayloadEncoder.objectString([
                ("status", .string(state.status.rawValue)),
                ("requestIndex", requestContext.map { .int($0.requestIndex) }),
                ("provider", requestContext?.provider.map { .string($0.rawValue) }),
                ("model", requestContext?.model.map { .string($0) })
            ])
        )
    }

    func persistCycleFailureLog(
        state: AIConnectionRuntimeState,
        cycleNumber: Int,
        message: String
    ) -> Result<URL, Error> {
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
            return .success(try errorLogStore.writeFailureLog(payload))
        } catch {
            return .failure(error)
        }
    }

    func logCancelled(
        state: AIConnectionRuntimeState,
        endedAt: Date,
        requestContext: AIConnectionRequestLogContext?
    ) {
        log(
            kind: .sessionCompleted,
            severity: .success,
            title: "AI Connection session completed",
            summary: "Runtime stopped by user.",
            sessionId: state.runId?.uuidString,
            runId: state.runId?.uuidString,
            durationMilliseconds: state.startedAt.map { endedAt.timeIntervalSince($0) * 1_000 },
            success: true,
            inputPayload: requestContext.flatMap { requestMessagesPayload($0.requestMessages) },
            metadataPayload: ServerLogPayloadEncoder.objectString([
                ("completionReason", .string("cancelled")),
                ("errorCount", .int(state.errors.count)),
                ("requestIndex", requestContext.map { .int($0.requestIndex) }),
                ("provider", requestContext?.provider.map { .string($0.rawValue) }),
                ("model", requestContext?.model.map { .string($0) })
            ])
        )
    }

    func persistPromptProcessingIfNeeded(
        at time: Date,
        runId: String?,
        requestContext: inout AIConnectionRequestLogContext?
    ) {
        guard var context = requestContext, !context.didPersistPromptProcessing else {
            return
        }

        context.didPersistPromptProcessing = true
        requestContext = context
        log(
            kind: .promptProcessingCompleted,
            severity: .info,
            title: "Prompt processing completed",
            summary: "Provider accepted the request and started producing output.",
            sessionId: runId,
            runId: runId,
            cycleNumber: context.cycleNumber,
            durationMilliseconds: time.timeIntervalSince(context.startedAt) * 1_000,
            success: true,
            metadataPayload: ServerLogPayloadEncoder.objectString([
                ("requestIndex", .int(context.requestIndex)),
                ("provider", context.provider.map { .string($0.rawValue) }),
                ("model", context.model.map { .string($0) }),
                ("responseId", context.responseId.map { .string($0) })
            ])
        )
    }

    func logCompletedResponse(
        state: AIConnectionRuntimeState,
        response: AIProviderResponse,
        requestContext: AIConnectionRequestLogContext?
    ) {
        let finalReasoning = response.reasoning.isEmpty ? state.reasoningText : response.reasoning
        if !finalReasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log(
                kind: .reasoningCompleted,
                severity: .success,
                title: "Reasoning completed",
                summary: "Final reasoning payload captured for this provider response.",
                sessionId: state.runId?.uuidString,
                runId: state.runId?.uuidString,
                cycleNumber: requestContext?.cycleNumber,
                success: true,
                outputPayload: finalReasoning,
                metadataPayload: responseMetadataPayload(response, requestContext: requestContext)
            )
        }

        let finalOutput = response.text.isEmpty ? state.assistantText : response.text
        if !finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log(
                kind: .assistantOutputCompleted,
                severity: .success,
                title: "Assistant output completed",
                summary: "Final assistant output captured for this provider response.",
                sessionId: state.runId?.uuidString,
                runId: state.runId?.uuidString,
                cycleNumber: requestContext?.cycleNumber,
                success: true,
                outputPayload: finalOutput,
                metadataPayload: responseMetadataPayload(response, requestContext: requestContext)
            )
        }
    }

    func logCycleCompleted(
        state: AIConnectionRuntimeState,
        outcome: AIConnectionCycleOutcome,
        cycleNumber: Int,
        requestContext: AIConnectionRequestLogContext?
    ) {
        log(
            kind: .sessionCompleted,
            severity: .success,
            title: "AI Connection cycle completed",
            summary: outcome.completedSummary(cycleNumber: cycleNumber),
            sessionId: state.runId?.uuidString,
            runId: state.runId?.uuidString,
            cycleNumber: cycleNumber,
            success: true,
            inputPayload: requestContext.flatMap { requestMessagesPayload($0.requestMessages) },
            metadataPayload: ServerLogPayloadEncoder.objectString([
                ("completionReason", .string(outcome.completionReason)),
                ("status", .string(state.status.rawValue)),
                ("requestIndex", requestContext.map { .int($0.requestIndex) }),
                ("provider", requestContext?.provider.map { .string($0.rawValue) }),
                ("model", requestContext?.model.map { .string($0) })
            ])
        )
    }

    func logToolCallCompleted(
        state: AIConnectionRuntimeState,
        callState: AIRunToolCallState,
        toolCallID: String,
        result: AIToolExecutionResult,
        requestContext: AIConnectionRequestLogContext?
    ) {
        log(
            kind: .toolCallCompleted,
            severity: result.success ? .success : .error,
            title: "Tool call completed",
            summary: result.success
                ? "\(result.toolName) completed successfully."
                : "\(result.toolName) failed: \(result.errorMessage ?? "Unknown error")",
            sessionId: state.runId?.uuidString,
            runId: state.runId?.uuidString,
            cycleNumber: requestContext?.cycleNumber,
            toolCallId: toolCallID,
            toolName: result.toolName,
            durationMilliseconds: result.durationMilliseconds,
            success: result.success,
            inputPayload: callState.argumentsJSON.isEmpty ? nil : callState.argumentsJSON,
            outputPayload: callState.responseText,
            errorPayload: result.errorMessage,
            metadataPayload: ServerLogPayloadEncoder.objectString([
                ("suggestedAction", result.suggestedAction.map { .string($0) }),
                ("responseText", callState.responseText.map { .string($0) }),
                ("toolStatus", .string(callState.status.rawValue))
            ])
        )
    }

    func providerFailureSummary(_ failure: AIProviderFailure) -> String {
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

    private func responseMetadataPayload(
        _ response: AIProviderResponse,
        requestContext: AIConnectionRequestLogContext?
    ) -> String? {
        ServerLogPayloadEncoder.objectString([
            ("requestIndex", requestContext.map { .int($0.requestIndex) }),
            ("provider", .string(response.provider.rawValue)),
            ("model", .string(response.model)),
            ("responseId", response.id.map { .string($0) }),
            ("finishReason", response.finishReason.map { .string($0) }),
            ("toolCallCount", .int(response.toolCalls.count))
        ])
    }

    private func requestMessagesPayload(_ messages: [AIConversationMessage]) -> String? {
        ServerLogPayloadEncoder.objectString([
            (
                "messages",
                .array(
                    messages.map { message in
                        .object(requestMessageObject(for: message))
                    }
                )
            )
        ])
    }

    private func requestMessageObject(for message: AIConversationMessage) -> [String: AIJSONValue] {
        var object: [String: AIJSONValue] = [
            "role": .string(message.role.rawValue)
        ]

        if let content = message.content {
            object["content"] = .string(content)
        }
        if let name = message.name {
            object["name"] = .string(name)
        }
        if let toolCallID = message.toolCallID {
            object["tool_call_id"] = .string(toolCallID)
        }
        if !message.toolCalls.isEmpty {
            object["tool_calls"] = .array(
                message.toolCalls.map { toolCall in
                    .object([
                        "id": .string(toolCall.id),
                        "name": .string(toolCall.name),
                        "arguments": .string(toolCall.argumentsJSON)
                    ])
                }
            )
        }

        return object
    }

    private func log(
        kind: ServerLogKind,
        severity: ServerLogSeverity,
        title: String,
        summary: String,
        sessionId: String? = nil,
        runId: String? = nil,
        cycleNumber: Int? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil,
        durationMilliseconds: Double? = nil,
        success: Bool? = nil,
        inputPayload: String? = nil,
        outputPayload: String? = nil,
        errorPayload: String? = nil,
        metadataPayload: String? = nil
    ) {
        serverLogsProvider().record(
            kind: kind,
            severity: severity,
            title: title,
            summary: summary,
            sessionId: sessionId,
            runId: runId,
            cycleNumber: cycleNumber,
            toolCallId: toolCallId,
            toolName: toolName,
            durationMilliseconds: durationMilliseconds,
            success: success,
            inputPayload: inputPayload,
            outputPayload: outputPayload,
            errorPayload: errorPayload,
            metadataPayload: metadataPayload
        )
    }
}
