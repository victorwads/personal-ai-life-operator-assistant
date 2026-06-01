import Foundation

enum AIConnectionRuntimeStatus: String, CaseIterable {
    case stopped
    case initializing
    case promptProcessing
    case reasoning
    case executingTool
    case receivingOutput
    case waitingUser
    case waitingEvent
    case paused
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .promptProcessing:
            return "Prompt Processing"
        case .executingTool:
            return "Executing Tool"
        case .receivingOutput:
            return "Receiving Output"
        case .waitingUser:
            return "Waiting User"
        case .waitingEvent:
            return "Waiting Event"
        default:
            return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .stopped:
            return "stop.circle"
        case .initializing:
            return "arrow.clockwise.circle"
        case .promptProcessing:
            return "text.append"
        case .reasoning:
            return "brain.head.profile"
        case .executingTool:
            return "wrench.and.screwdriver"
        case .receivingOutput:
            return "text.bubble"
        case .waitingUser:
            return "person.crop.circle.badge.questionmark"
        case .waitingEvent:
            return "clock.badge.exclamationmark"
        case .paused:
            return "pause.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.octagon"
        case .cancelled:
            return "xmark.circle"
        }
    }

    var isRunningLike: Bool {
        switch self {
        case .initializing, .promptProcessing, .reasoning, .executingTool, .receivingOutput, .waitingUser, .waitingEvent:
            return true
        case .stopped, .paused, .completed, .failed, .cancelled:
            return false
        }
    }
}

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

    static func initial(availableToolDefinitions: [AIToolDefinition] = []) -> Self {
        Self(
            runId: nil,
            status: .stopped,
            startedAt: nil,
            endedAt: nil,
            currentPhaseStartedAt: nil,
            systemPrompt: AIConnectionRuntimeService.systemPrompt,
            userPrompt: "",
            assistantText: "",
            reasoningText: "",
            availableToolDefinitions: availableToolDefinitions,
            toolCalls: [],
            usage: AIRunUsageState(),
            errors: [],
            debugEvents: [],
            isLoadingTools: false
        )
    }
}

struct AIRunPromptState {
    let systemPrompt: String
    let userPrompt: String
}

struct AIRunUsageState {
    var inputTokens: Int?
    var outputTokens: Int?
    var reasoningTokens: Int?
    var totalTokens: Int?
    var isOutputTokensEstimated = false
    var tokensPerSecond: Double?
    var timeToFirstToken: TimeInterval?
    var runDuration: TimeInterval?
    var runStartedAt: Date?
    var lastUpdatedAt: Date?
}

struct AIRunToolCallState: Identifiable, Encodable {
    enum Status: String, Encodable {
        case started
        case argumentsStreaming
        case argumentsReady
        case executing
        case completed
        case failed
        case cancelled
    }

    let id: String
    var name: String
    var icon: String?
    var argumentsJSON: String
    var responseText: String?
    var errorText: String?
    var status: Status
    let startedAt: Date
    var endedAt: Date?
    var rawEventSummary: String

    var argumentsPreview: String {
        let compact = argumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return "No arguments yet" }
        return compact.count > 140 ? String(compact.prefix(140)) + "..." : compact
    }

    var durationText: String {
        guard let endedAt else { return "-" }
        return String(format: "%.2fs", endedAt.timeIntervalSince(startedAt))
    }
}

struct AIRunDebugEventState: Identifiable {
    let id = UUID()
    let kind: String
    let summary: String
    let timestamp: Date

    var line: String {
        "\(Self.timestampFormatter.string(from: timestamp)) [\(kind)] \(summary)"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
