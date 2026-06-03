import Foundation

struct AIConnectionUsageTracker {
    func recordFirstTokenIfNeeded(at time: Date, state: inout AIConnectionRuntimeState) {
        guard state.usage.timeToFirstToken == nil else { return }
        if let runStartedAt = state.usage.runStartedAt ?? state.startedAt {
            state.usage.timeToFirstToken = time.timeIntervalSince(runStartedAt)
        }
    }

    func updateEstimatedOutputTokens(at time: Date, state: inout AIConnectionRuntimeState) {
        guard state.usage.outputTokens == nil else {
            updateLiveMetrics(at: time, state: &state)
            return
        }

        let estimatedTokens = estimateTokenCount(text: state.assistantText + state.reasoningText)
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
        state.usage.totalTokens = usage.totalTokens
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

    private func estimateTokenCount(text: String) -> Int {
        let chars = max(text.count, 0)
        return max(1, Int((Double(chars) / 4.0).rounded(.up)))
    }
}
