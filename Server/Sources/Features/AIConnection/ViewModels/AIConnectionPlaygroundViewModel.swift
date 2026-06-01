import Foundation

@MainActor
final class AIConnectionPlaygroundViewModel: ObservableObject {
    @Published var prompt = "start your job"
    @Published private(set) var runStatus: AIRunStatus = .idle
    @Published private(set) var promptState = AIRunPromptState(systemPrompt: AIConnectionPlaygroundViewModel.systemPrompt, userPrompt: "")
    @Published private(set) var assistantText = ""
    @Published private(set) var reasoningText = ""
    @Published private(set) var tools: [AIToolDefinition] = []
    @Published private(set) var toolCalls: [AIRunToolCallState] = []
    @Published private(set) var usageState = AIRunUsageState()
    @Published private(set) var debugEvents: [AIRunDebugEventState] = []
    @Published private(set) var isLoadingTools = false
    @Published private(set) var providerError: String?

    private let feature: AIConnectionFeature
    private var activeStreamingTask: Task<Void, Never>?
    private var runStartedAt: Date?
    private var firstTokenAt: Date?
    private var toolCallIndexByID: [String: Int] = [:]
    private static let maxDebugEvents = 200

    init(feature: AIConnectionFeature) {
        self.feature = feature
    }

    var isStreaming: Bool {
        runStatus == .running
    }

    var hasTools: Bool {
        !tools.isEmpty
    }

    var normalizedPrompt: String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "start your job" : trimmed
    }

    func loadTools() async {
        isLoadingTools = true
        providerError = nil
        defer { isLoadingTools = false }

        let loadedTools = await feature.streamingService.availableTools()
        tools = loadedTools.sorted { $0.name < $1.name }
        appendDebug(kind: "tools.loaded", summary: "Loaded \(loadedTools.count) tool definition(s).")
    }

    func startJob() {
        cancelStreamTaskIfNeeded()
        resetRunStateForNewJob()

        let configuration = feature.settings.providerConfiguration
        let actualUserPrompt = normalizedPrompt
        let request = AIProviderRequest(
            model: configuration.model,
            messages: [
                AIConversationMessage(role: .system, content: Self.systemPrompt),
                AIConversationMessage(role: .user, content: actualUserPrompt)
            ],
            tools: tools,
            temperature: configuration.temperature,
            maxOutputTokens: configuration.maxOutputTokens,
            cacheMode: configuration.cacheMode
        )

        promptState = AIRunPromptState(systemPrompt: Self.systemPrompt, userPrompt: actualUserPrompt)
        runStatus = .running
        runStartedAt = Date()
        usageState.runStartedAt = runStartedAt

        appendDebug(
            kind: "request.created",
            summary: "Built streaming request for provider \(configuration.providerKind.displayName)."
        )

        activeStreamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in self.feature.streamingService.streamEvents(for: request) {
                    if Task.isCancelled {
                        return
                    }
                    await self.handle(event: event)
                }
                await self.finalizeUsageOnRunEnd()
            } catch is CancellationError {
                await self.markCancelled()
            } catch {
                await self.handleStreamFailure(message: error.localizedDescription)
            }
            await self.finishStreamTask()
        }
    }

    func cancelRun() {
        guard isStreaming else { return }
        activeStreamingTask?.cancel()
        markCancelled()
    }

    func clear() {
        cancelStreamTaskIfNeeded()
        runStatus = .idle
        promptState = AIRunPromptState(systemPrompt: Self.systemPrompt, userPrompt: "")
        assistantText = ""
        reasoningText = ""
        toolCalls = []
        debugEvents = []
        usageState = AIRunUsageState()
        providerError = nil
        toolCallIndexByID = [:]
        runStartedAt = nil
        firstTokenAt = nil
    }

    private func resetRunStateForNewJob() {
        providerError = nil
        assistantText = ""
        reasoningText = ""
        toolCalls = []
        debugEvents = []
        usageState = AIRunUsageState()
        toolCallIndexByID = [:]
        firstTokenAt = nil
    }

    private func finishStreamTask() {
        activeStreamingTask = nil
        if runStatus == .running {
            runStatus = .completed
        }
    }

    private func handleStreamFailure(message: String) {
        providerError = message
        runStatus = .failed
        appendDebug(kind: "stream.error", summary: message)
        finalizeUsageOnRunEnd()
    }

    private func cancelStreamTaskIfNeeded() {
        activeStreamingTask?.cancel()
        activeStreamingTask = nil
    }

    private func markCancelled() {
        if runStatus == .running {
            runStatus = .cancelled
            appendDebug(kind: "stream.cancelled", summary: "Run was cancelled.")
            finalizeToolCallsAsCancelledIfNeeded()
            finalizeUsageOnRunEnd()
        }
    }

    private func handle(event: AIStreamEvent) {
        let now = Date()
        switch event {
        case let .requestStarted(provider, model):
            appendDebug(kind: "stream.request_started", summary: "\(provider.displayName) / \(model)")
        case let .responseStarted(id):
            appendDebug(kind: "stream.response_started", summary: "responseId=\(id ?? "nil")")
        case let .textDelta(delta):
            assistantText += delta
            recordFirstTokenIfNeeded(at: now)
            updateUsageEstimates(at: now)
        case let .reasoningDelta(delta):
            reasoningText += delta
            recordFirstTokenIfNeeded(at: now)
            updateUsageEstimates(at: now)
        case let .toolCallStarted(id, name):
            upsertToolCallStarted(id: id, name: name, at: now)
        case let .toolCallArgumentsDelta(id, delta):
            upsertToolCallArgumentsDelta(id: id, delta: delta)
        case let .toolCallCompleted(toolCall):
            upsertToolCallCompleted(toolCall: toolCall, at: now)
        case let .usage(usage):
            usageState.inputTokens = usage.promptTokens
            usageState.outputTokens = usage.completionTokens
            usageState.totalTokens = usage.totalTokens
            usageState.isOutputTokensEstimated = false
            usageState.lastUpdatedAt = now
            updateUsageLiveMetrics(at: now)
        case let .completed(response):
            if !response.text.isEmpty {
                assistantText = response.text
            }
            if !response.reasoning.isEmpty {
                reasoningText = response.reasoning
            }
            if let usage = response.usage {
                usageState.inputTokens = usage.promptTokens
                usageState.outputTokens = usage.completionTokens
                usageState.totalTokens = usage.totalTokens
                usageState.isOutputTokensEstimated = false
            }
            finalizeToolCallsAsCompletedIfNeeded(at: now)
            usageState.lastUpdatedAt = now
            updateUsageLiveMetrics(at: now)
            appendDebug(kind: "stream.completed", summary: "finishReason=\(response.finishReason ?? "nil")")
        case let .failed(message):
            providerError = message
            runStatus = .failed
            appendDebug(kind: "stream.failed", summary: message)
        }
    }

    private func upsertToolCallStarted(id: String, name: String, at time: Date) {
        if let index = toolCallIndexByID[id] {
            toolCalls[index].name = name
            toolCalls[index].status = .started
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

        toolCalls.append(call)
        toolCallIndexByID[id] = toolCalls.count - 1
    }

    private func upsertToolCallArgumentsDelta(id: String, delta: String) {
        guard let index = toolCallIndexByID[id] else { return }
        toolCalls[index].argumentsJSON += delta
        toolCalls[index].status = .argumentsStreaming
    }

    private func upsertToolCallCompleted(toolCall: AIRequestedToolCall, at time: Date) {
        if let index = toolCallIndexByID[toolCall.id] {
            toolCalls[index].name = toolCall.name
            toolCalls[index].argumentsJSON = toolCall.argumentsJSON
            toolCalls[index].status = .completed
            toolCalls[index].endedAt = time
            toolCalls[index].icon = toolDefinition(named: toolCall.name)?.icon
            toolCalls[index].rawEventSummary = "tool call completed"
            return
        }

        let call = AIRunToolCallState(
            id: toolCall.id,
            name: toolCall.name,
            icon: toolDefinition(named: toolCall.name)?.icon,
            argumentsJSON: toolCall.argumentsJSON,
            responseText: nil,
            errorText: nil,
            status: .completed,
            startedAt: time,
            endedAt: time,
            rawEventSummary: "tool call completed"
        )
        toolCalls.append(call)
        toolCallIndexByID[toolCall.id] = toolCalls.count - 1
    }

    private func finalizeToolCallsAsCompletedIfNeeded(at time: Date) {
        for index in toolCalls.indices {
            if toolCalls[index].status == .argumentsStreaming || toolCalls[index].status == .started {
                toolCalls[index].status = .argumentsReady
            }
            if toolCalls[index].status != .failed && toolCalls[index].status != .cancelled {
                toolCalls[index].status = .completed
                toolCalls[index].endedAt = toolCalls[index].endedAt ?? time
            }
        }
    }

    private func finalizeToolCallsAsCancelledIfNeeded() {
        let now = Date()
        for index in toolCalls.indices where toolCalls[index].status != .completed && toolCalls[index].status != .failed {
            toolCalls[index].status = .cancelled
            toolCalls[index].endedAt = now
        }
    }

    private func recordFirstTokenIfNeeded(at time: Date) {
        guard firstTokenAt == nil else { return }
        firstTokenAt = time
        if let runStartedAt {
            usageState.timeToFirstToken = time.timeIntervalSince(runStartedAt)
        }
    }

    private func updateUsageEstimates(at time: Date) {
        guard usageState.outputTokens == nil else {
            updateUsageLiveMetrics(at: time)
            return
        }

        let estimatedTokens = Self.estimateTokenCount(text: assistantText + reasoningText)
        usageState.outputTokens = estimatedTokens
        usageState.isOutputTokensEstimated = true

        if let input = usageState.inputTokens {
            usageState.totalTokens = input + estimatedTokens
        }

        usageState.lastUpdatedAt = time
        updateUsageLiveMetrics(at: time)
    }

    private func updateUsageLiveMetrics(at time: Date) {
        guard let runStartedAt else { return }
        usageState.runDuration = time.timeIntervalSince(runStartedAt)

        if let outputTokens = usageState.outputTokens,
           let firstTokenAt,
           time > firstTokenAt {
            let elapsed = time.timeIntervalSince(firstTokenAt)
            usageState.tokensPerSecond = elapsed > 0 ? Double(outputTokens) / elapsed : nil
        }
    }

    private func finalizeUsageOnRunEnd() {
        updateUsageLiveMetrics(at: Date())
    }

    private func toolDefinition(named name: String) -> AIToolDefinition? {
        tools.first(where: { $0.name == name })
    }

    private static func estimateTokenCount(text: String) -> Int {
        let chars = max(text.count, 0)
        return max(1, Int((Double(chars) / 4.0).rounded(.up)))
    }

    private func appendDebug(kind: String, summary: String) {
        debugEvents.append(
            AIRunDebugEventState(
                kind: kind,
                summary: summary,
                timestamp: Date()
            )
        )

        if debugEvents.count > Self.maxDebugEvents {
            debugEvents.removeFirst(debugEvents.count - Self.maxDebugEvents)
        }
    }

    static let systemPrompt = """
You are running inside the AI Connection Playground of a local-first macOS personal assistant app.

Your current job is NOT to operate the user’s life yet.
Your job is to validate the AI provider integration.

Act as a diagnostic assistant.

You must:
- confirm that you received the system prompt
- explain that streaming is working if your text is appearing incrementally
- briefly describe what you would do in a real assistant loop
- inspect the available tool definitions if they are provided
- if tools are available, mention which tool you would call first in a real run
- do not claim that you executed any tool
- do not invent tool results
- keep the response short and structured

If tool calling is available, you may emit a small harmless tool call only for validation, but the app must not execute it automatically in this task.
"""
}

enum AIRunStatus: String {
    case idle
    case running
    case completed
    case failed
    case cancelled
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
