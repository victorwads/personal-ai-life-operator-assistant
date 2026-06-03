import Foundation

struct AIConnectionRuntimeState {
    var runId: UUID?
    var status: AIConnectionRuntimeStatus
    var startedAt: Date?
    var endedAt: Date?
    var currentPhaseStartedAt: Date?

    var systemPrompt: String
    var userPrompt: String
    var assistantText: String
    var reasoningText: String

    var availableToolDefinitions: [AIToolDefinition]
    var toolCalls: [AIRunToolCallState]
    var usage: AIRunUsageState
    var errors: [String]
    var lastProviderFailure: AIProviderFailure?
    var debugEvents: [AIRunDebugEventState]
    var isLoadingTools: Bool

    var isRunning: Bool {
        status.isRunningLike
    }

    var canStart: Bool {
        !isRunning
    }

    var canCancel: Bool {
        isRunning
    }

    var canReset: Bool {
        !isRunning
    }

    static func initial(
        systemPrompt: String,
        availableToolDefinitions: [AIToolDefinition] = []
    ) -> Self {
        Self(
            runId: nil,
            status: .stopped,
            startedAt: nil,
            endedAt: nil,
            currentPhaseStartedAt: nil,
            systemPrompt: systemPrompt,
            userPrompt: "",
            assistantText: "",
            reasoningText: "",
            availableToolDefinitions: availableToolDefinitions,
            toolCalls: [],
            usage: AIRunUsageState(),
            errors: [],
            lastProviderFailure: nil,
            debugEvents: [],
            isLoadingTools: false
        )
    }
}
