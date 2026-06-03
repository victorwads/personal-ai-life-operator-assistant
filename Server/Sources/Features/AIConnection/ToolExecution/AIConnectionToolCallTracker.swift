import Foundation

final class AIConnectionToolCallTracker {
    private var toolCallIndexByID: [String: Int] = [:]

    func reset() {
        toolCallIndexByID = [:]
    }

    func upsertToolCallStarted(
        id: String,
        name: String,
        at time: Date,
        availableToolDefinitions: [AIToolDefinition],
        state: inout AIConnectionRuntimeState
    ) {
        if let index = toolCallIndexByID[id] {
            state.toolCalls[index].name = name
            state.toolCalls[index].status = .started
            return
        }

        let call = AIRunToolCallState(
            id: id,
            name: name,
            icon: toolDefinition(named: name, in: availableToolDefinitions)?.icon,
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

    func upsertToolCallArgumentsDelta(
        id: String,
        delta: String,
        state: inout AIConnectionRuntimeState
    ) {
        guard let index = toolCallIndexByID[id] else { return }
        state.toolCalls[index].argumentsJSON += delta
        state.toolCalls[index].status = .argumentsStreaming
    }

    func upsertToolCallCompleted(
        toolCall: AIRequestedToolCall,
        at time: Date,
        availableToolDefinitions: [AIToolDefinition],
        state: inout AIConnectionRuntimeState
    ) {
        if let index = toolCallIndexByID[toolCall.id] {
            state.toolCalls[index].name = toolCall.name
            state.toolCalls[index].argumentsJSON = toolCall.argumentsJSON
            state.toolCalls[index].status = .argumentsReady
            state.toolCalls[index].endedAt = nil
            state.toolCalls[index].icon = toolDefinition(named: toolCall.name, in: availableToolDefinitions)?.icon
            state.toolCalls[index].rawEventSummary = "tool call arguments ready"
            return
        }

        let call = AIRunToolCallState(
            id: toolCall.id,
            name: toolCall.name,
            icon: toolDefinition(named: toolCall.name, in: availableToolDefinitions)?.icon,
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

    func finalizeArgumentsIfNeeded(state: inout AIConnectionRuntimeState) {
        for index in state.toolCalls.indices {
            if state.toolCalls[index].status == .argumentsStreaming || state.toolCalls[index].status == .started {
                state.toolCalls[index].status = .argumentsReady
            }
        }
    }

    func finalizeAsCancelledIfNeeded(at time: Date, state: inout AIConnectionRuntimeState) {
        for index in state.toolCalls.indices
        where state.toolCalls[index].status != .completed && state.toolCalls[index].status != .failed {
            state.toolCalls[index].status = .cancelled
            state.toolCalls[index].endedAt = time
        }
    }

    func finalizeAsFailedIfNeeded(
        message: String,
        at time: Date,
        state: inout AIConnectionRuntimeState
    ) {
        for index in state.toolCalls.indices
        where state.toolCalls[index].status != .completed && state.toolCalls[index].status != .failed {
            state.toolCalls[index].status = .failed
            state.toolCalls[index].errorText = message
            state.toolCalls[index].endedAt = time
        }
    }

    func markExecuting(id: String, state: inout AIConnectionRuntimeState) {
        guard let index = toolCallIndexByID[id] else { return }
        state.toolCalls[index].status = .executing
        state.toolCalls[index].rawEventSummary = "tool execution running"
    }

    func applyExecutionResult(
        toolCallID: String,
        result: AIToolExecutionResult,
        responseText: String,
        completedAt: Date,
        state: inout AIConnectionRuntimeState
    ) -> AIRunToolCallState? {
        guard let index = toolCallIndexByID[toolCallID] else { return nil }

        state.toolCalls[index].status = result.success ? .completed : .failed
        state.toolCalls[index].responseText = responseText
        state.toolCalls[index].errorText = result.success ? nil : result.errorMessage
        state.toolCalls[index].endedAt = completedAt
        return state.toolCalls[index]
    }

    func statusForExecution(
        named toolName: String,
        availableToolDefinitions: [AIToolDefinition]
    ) -> AIConnectionRuntimeStatus {
        guard let tool = toolDefinition(named: toolName, in: availableToolDefinitions) else {
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

    private func toolDefinition(named name: String, in availableToolDefinitions: [AIToolDefinition]) -> AIToolDefinition? {
        availableToolDefinitions.first(where: { $0.name == name })
    }
}
