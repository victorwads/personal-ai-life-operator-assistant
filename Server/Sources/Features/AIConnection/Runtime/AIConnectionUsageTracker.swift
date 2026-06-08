import Foundation

struct AIConnectionUsageTracker {
    private let tokenEstimator = AITokenEstimator()

    func recordFirstTokenIfNeeded(at time: Date, state: inout AIConnectionRuntimeState) {
        guard state.usage.timeToFirstToken == nil else { return }
        if let runStartedAt = state.usage.runStartedAt ?? state.startedAt {
            state.usage.timeToFirstToken = time.timeIntervalSince(runStartedAt)
        }
    }

    func applyEstimatedInputTokens(
        for request: AIProviderRequest,
        at time: Date,
        state: inout AIConnectionRuntimeState
    ) {
        let estimatedTokens = tokenEstimator.estimateInputTokens(for: request)
        state.usage.inputTokens = estimatedTokens
        state.usage.isInputTokensEstimated = true
        state.usage.lastUpdatedAt = time
        if let outputTokens = state.usage.outputTokens {
            state.usage.totalTokens = estimatedTokens + outputTokens
        }
        updateLiveMetrics(at: time, state: &state)
    }

    func updateEstimatedOutputTokens(at time: Date, state: inout AIConnectionRuntimeState) {
        guard state.usage.outputTokens == nil else {
            updateLiveMetrics(at: time, state: &state)
            return
        }

        let estimatedTokens = tokenEstimator.estimateOutputTokens(text: state.assistantText + state.reasoningText)
        state.usage.outputTokens = estimatedTokens
        state.usage.isOutputTokensEstimated = true

        if let inputTokens = state.usage.inputTokens {
            state.usage.totalTokens = inputTokens + estimatedTokens
        }

        state.usage.lastUpdatedAt = time
        updateLiveMetrics(at: time, state: &state)
    }

    func applyProviderUsage(_ usage: AIUsage, at time: Date, state: inout AIConnectionRuntimeState) {
        state.usage.inputTokens = usage.promptTokens
        state.usage.outputTokens = usage.completionTokens
        state.usage.reasoningTokens = usage.reasoningTokens
        state.usage.cachedInputTokens = usage.cachedInputTokens
        state.usage.totalTokens = usage.totalTokens ?? fallbackTotalTokens(for: usage)
        state.usage.isInputTokensEstimated = false
        state.usage.isOutputTokensEstimated = false
        state.usage.lastUpdatedAt = time
        updateLiveMetrics(at: time, state: &state)
    }

    func updateLiveMetrics(at time: Date, state: inout AIConnectionRuntimeState) {
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

    func finalize(at time: Date, state: inout AIConnectionRuntimeState) {
        updateLiveMetrics(at: time, state: &state)
    }

    private func fallbackTotalTokens(for usage: AIUsage) -> Int? {
        let input = usage.promptTokens ?? 0
        let output = usage.completionTokens ?? 0
        let reasoning = usage.reasoningTokens ?? 0
        let total = input + output + reasoning
        return total > 0 ? total : nil
    }
}
