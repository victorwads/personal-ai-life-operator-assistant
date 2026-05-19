import Combine
import Foundation

@MainActor
final class LMStudioSessionManager: ObservableObject {
    enum ActivityPhase: String, Sendable {
        case idle
        case modelLoading
        case promptProcessing
        case reasoning
        case toolCall
        case message
        case error
    }

    private let apiClient = LMStudioAPIClient()
    private let credentialsRepository = LMStudioCredentialsRepository.shared
    private let defaults = UserDefaults.standard
    private let selectedModelKeyDefaultsKey = "lmStudio.selectedModelKey.v1"
    private let apiBaseURLDefaultsKey = "lmStudio.apiBaseURL.v1"
    private let autoRunEnabledDefaultsKey = "lmStudio.autoRunEnabled.v1"
    private var cancellables: Set<AnyCancellable> = []
    private var sessionTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var activeSessionID: UUID?
    private var logHandler: ((String, LogLevel) -> Void)?
    private var lastMCPServerURL: URL?
    private var didUserPause = false
    // Append-only timeline: never auto-trim. Keep this as a reference in case we
    // ever want to reintroduce a soft cap for memory reasons.
    // private let maxTimelineEvents = 1000
    // LM Studio does not currently support a per-request MCP timeout override via API.
    // Keep this here as a reference for a future server-side capability.
    // private let mcpTimeoutMs = 600_000

    @Published var apiBaseURLText: String
    @Published var apiToken: String = ""
    @Published var selectedModelKey: String
    @Published var autoRunEnabled: Bool
    @Published private(set) var models: [LMStudioModelSummary] = []
    @Published private(set) var sessionState: LMStudioSessionState = .idle
    @Published private(set) var isRefreshingModels = false
    @Published private(set) var activityPhase: ActivityPhase = .idle
    @Published private(set) var timeline: [LMStudioEventRecord] = []
    @Published private(set) var liveReasoningText = ""
    @Published private(set) var liveMessageText = ""
    @Published private(set) var lastCompletedText = ""
    @Published private(set) var activeResponseID: String?
    @Published private(set) var activeModelInstanceID: String?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var promptSourceDescription: String

    init() {
        apiBaseURLText = defaults.string(forKey: apiBaseURLDefaultsKey) ?? "http://localhost:1234"
        selectedModelKey = defaults.string(forKey: selectedModelKeyDefaultsKey) ?? ""
        autoRunEnabled = defaults.bool(forKey: autoRunEnabledDefaultsKey)
        apiToken = (try? credentialsRepository.loadAPIToken()) ?? ""
        promptSourceDescription = LMStudioPromptLoader.sourceDescription

        $apiBaseURLText
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                self.defaults.set(value, forKey: self.apiBaseURLDefaultsKey)
            }
            .store(in: &cancellables)

        $selectedModelKey
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                self.defaults.set(value, forKey: self.selectedModelKeyDefaultsKey)
            }
            .store(in: &cancellables)

        $autoRunEnabled
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                self.defaults.set(value, forKey: self.autoRunEnabledDefaultsKey)
            }
            .store(in: &cancellables)

        $apiToken
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                do {
                    try self.credentialsRepository.saveAPIToken(value)
                } catch {
                    self.appendLog("Failed to persist LM Studio API token: \(error.localizedDescription)", level: .error)
                }
            }
            .store(in: &cancellables)
    }

    func clearTimeline() {
        timeline.removeAll()
    }

    var isSessionActive: Bool {
        switch sessionState {
        case .starting, .running, .pausing:
            return true
        case .idle, .refreshingModels, .paused, .completed, .failed:
            return false
        }
    }

    var statusTitle: String {
        if isRefreshingModels && !isSessionActive {
            return "Refreshing"
        }
        switch sessionState {
        case .idle:
            return "Idle"
        case .refreshingModels:
            return "Refreshing"
        case .starting:
            return "Starting"
        case .running:
            switch activityPhase {
            case .idle:
                return "Running"
            case .modelLoading:
                return "Model loading"
            case .promptProcessing:
                return "Prompt"
            case .reasoning:
                return "Reasoning"
            case .toolCall:
                return "Tool call"
            case .message:
                return "Message"
            case .error:
                return "Error"
            }
        case .pausing:
            return "Pausing"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    var statusDetail: String {
        if isRefreshingModels && !isSessionActive {
            return "Reading the local model catalog."
        }
        switch sessionState {
        case .idle:
            return "Ready to launch a fresh LM Studio conversation."
        case .refreshingModels:
            return "Reading the local model catalog."
        case .starting:
            return "Sending the bootstrap prompt."
        case .running:
            if let activeModelInstanceID {
                return "Streaming on \(activeModelInstanceID)."
            }
            return "Streaming the assistant session."
        case .pausing:
            return "Cancelling the in-flight request."
        case .paused:
            return "The next start will create a fresh conversation."
        case .completed:
            return "The last session finished cleanly."
        case .failed(let message):
            return message
        }
    }

    var statusSymbolName: String {
        if isRefreshingModels && !isSessionActive {
            return "arrow.clockwise"
        }
        switch sessionState {
        case .idle:
            return "circle.dashed"
        case .refreshingModels:
            return "arrow.clockwise"
        case .starting:
            return "play.circle"
        case .running:
            switch activityPhase {
            case .idle:
                return "waveform"
            case .modelLoading:
                return "arrow.down.circle"
            case .promptProcessing:
                return "text.append"
            case .reasoning:
                return "brain"
            case .toolCall:
                return "wrench.and.screwdriver"
            case .message:
                return "bubble.left.and.bubble.right"
            case .error:
                return "xmark.octagon"
            }
        case .pausing:
            return "pause.circle"
        case .paused:
            return "pause.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var selectedModel: LMStudioModelSummary? {
        models.first { $0.key == selectedModelKey }
    }

    var selectedModelLabel: String {
        selectedModel?.displayName ?? (selectedModelKey.isEmpty ? "No model selected" : selectedModelKey)
    }

    var selectedModelSubtitle: String {
        if selectedModelKey.isEmpty {
            return "Select a model from the list below."
        }
        return "Uses the selected LM Studio model."
    }

    var selectedModelContextLength: Int? { nil }

    var latestOutputText: String {
        if !liveMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return liveMessageText
        }
        if !lastCompletedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return lastCompletedText
        }
        return "No assistant output yet."
    }

    func setLogHandler(_ handler: @escaping (String, LogLevel) -> Void) {
        logHandler = handler
    }

    func refreshModels() async {
        guard !isRefreshingModels else { return }
        isRefreshingModels = true
        defer { isRefreshingModels = false }

        do {
            let fetched = try await apiClient.fetchModels(
                baseURLText: apiBaseURLText,
                apiToken: apiToken
            )
            models = fetched
            // Intentionally do not mutate `selectedModelKey` here.
            // The UI is responsible for selection; refresh should only mirror the server catalog.
            lastErrorMessage = nil
            let previewKeys = fetched.prefix(5).map(\.key).joined(separator: ", ")
            if previewKeys.isEmpty {
                appendLog("Loaded \(fetched.count) LM Studio model(s).")
            } else {
                appendLog("Loaded \(fetched.count) LM Studio model(s): \(previewKeys)")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog("Failed to refresh LM Studio models: \(error.localizedDescription)", level: .error)
        }
    }

    func startFreshSession(mcpServerURL: URL) async {
        if isSessionActive {
            await restartFreshSession(mcpServerURL: mcpServerURL)
            return
        }
        await startSession(mcpServerURL: mcpServerURL)
    }

    func restartFreshSession(mcpServerURL: URL) async {
        await pauseSession()
        await startSession(mcpServerURL: mcpServerURL)
    }

    func pauseSession() async {
        guard isSessionActive else {
            return
        }

        didUserPause = true
        restartTask?.cancel()
        restartTask = nil
        sessionState = .pausing
        activeSessionID = nil
        sessionTask?.cancel()
        sessionTask = nil
        appendLog("Requested LM Studio session pause.", level: .warning)
        sessionState = .paused
    }

    private func startSession(mcpServerURL: URL) async {
        guard !apiBaseURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let message = "LM Studio base URL is empty."
            sessionState = .failed(message: message)
            lastErrorMessage = message
            appendLog(message, level: .error)
            return
        }

        let trimmedModelKey = selectedModelKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModelKey.isEmpty else {
            let message = "No LM Studio model selected. Download a model in LM Studio, then pick it from the Model menu."
            sessionState = .failed(message: message)
            lastErrorMessage = message
            appendLog(message, level: .error)
            return
        }

        sessionState = .starting

            let sessionID = UUID()
            activeSessionID = sessionID
            didUserPause = false
            lastMCPServerURL = mcpServerURL
            restartTask?.cancel()
            restartTask = nil
            activeResponseID = nil
            activeModelInstanceID = nil
            liveReasoningText = ""
            liveMessageText = ""
            lastCompletedText = ""
            lastErrorMessage = nil
            activityPhase = .idle
            timeline.append(
                LMStudioEventRecord(
                    type: "session.start",
                    title: "Session started",
                    detail: "model=\(trimmedModelKey)",
                    severity: .neutral
                )
            )

            let systemPrompt = LMStudioPromptLoader.startupPromptText()
            let mcpServerLabel = Self.mcpServerLabel(for: mcpServerURL)
            let requestBody = LMStudioChatRequestBody(
                model: trimmedModelKey,
                input: LMStudioPromptLoader.startupInputText,
                systemPrompt: systemPrompt,
                integrations: [
                    LMStudioEphemeralMCPIntegration(
                        serverLabel: mcpServerLabel,
                        serverURL: mcpServerURL.absoluteString,
                        allowedTools: nil,
                        headers: nil,
                        timeout: nil // (was: mcpTimeoutMs)
                    )
                ],
                stream: true,
                store: nil,
                previousResponseID: nil,
                contextLength: nil
            )

            appendLog("Starting a fresh LM Studio session with model \(trimmedModelKey) using MCP bridge \(mcpServerLabel).")

            let apiClient = apiClient
            let baseURLText = apiBaseURLText
            let apiToken = self.apiToken
            sessionTask = Task { [weak self] in
                do {
                    let result = try await apiClient.streamChat(
                        baseURLText: baseURLText,
                        apiToken: apiToken,
                        requestBody: requestBody,
                        debugHandler: { [weak self] message in
                            await self?.appendDebugEvent(message, sessionID: sessionID)
                        },
                        eventHandler: { [weak self] event in
                            await self?.handle(event: event, sessionID: sessionID)
                        }
                    )
                    await self?.finishSession(result: result, sessionID: sessionID)
                } catch is CancellationError {
                    await self?.handleCancellation(sessionID: sessionID)
                } catch {
                    await self?.handleFailure(error, sessionID: sessionID)
                }
            }
    }

    private func handle(event: LMStudioEventRecord, sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        timeline.append(event)

        switch event.type {
        case "chat.start":
            sessionState = .running
            activityPhase = .idle
            if let detail = event.detail, !detail.isEmpty {
                activeModelInstanceID = detail
            }
        case "model_load.start", "model_load.progress", "model_load.end":
            sessionState = .running
            activityPhase = .modelLoading
        case "prompt_processing.start", "prompt_processing.progress", "prompt_processing.end":
            sessionState = .running
            activityPhase = .promptProcessing
        case "reasoning.start":
            activityPhase = .reasoning
            liveReasoningText = ""
        case "reasoning.delta":
            activityPhase = .reasoning
            appendLiveText(&liveReasoningText, fragment: event.detail ?? "")
        case "reasoning.end":
            activityPhase = .idle
        case "tool_call.start", "tool_call.arguments", "tool_call.success", "tool_call.failure":
            activityPhase = .toolCall
        case "message.start":
            activityPhase = .message
            liveMessageText = ""
        case "message.delta":
            activityPhase = .message
            appendLiveText(&liveMessageText, fragment: event.detail ?? "")
        case "message.end":
            activityPhase = .idle
            if !liveMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lastCompletedText = liveMessageText
            }
        case "chat.end":
            activityPhase = .idle
            break
        case "error":
            activityPhase = .error
            lastErrorMessage = event.detail
            sessionState = .failed(message: event.detail ?? "LM Studio reported an error.")
        default:
            break
        }
    }

    private func appendDebugEvent(_ message: String, sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        timeline.append(
            LMStudioEventRecord(
                type: "debug.sse",
                title: "SSE",
                detail: message,
                severity: .neutral
            )
        )
        appendLog(message)
    }

    private func finishSession(result: LMStudioChatFinalResult, sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        sessionTask = nil
        sessionState = .completed
        activityPhase = .idle
        activeModelInstanceID = result.modelInstanceID
        activeResponseID = result.responseID
        if !result.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastCompletedText = result.finalText
        }
        if let responseID = result.responseID {
            appendLog("LM Studio session completed with response_id \(responseID).")
        } else {
            appendLog("LM Studio session completed.")
        }

        // If auto-run is enabled, the agent prompt is expected to run "forever". If the
        // streaming session ends cleanly, start a fresh session again.
        guard autoRunEnabled, !didUserPause, let lastMCPServerURL else { return }
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            await self?.startFreshSession(mcpServerURL: lastMCPServerURL)
        }
    }

    private func handleCancellation(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        sessionTask = nil
        sessionState = .paused
        appendLog("LM Studio session cancelled.", level: .warning)
    }

    private func handleFailure(_ error: Error, sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        sessionTask = nil
        let message = error.localizedDescription
        sessionState = .failed(message: message)
        lastErrorMessage = message
        appendLog("LM Studio session failed: \(message)", level: .error)
    }

    private func appendLiveText(_ text: inout String, fragment: String) {
        guard !fragment.isEmpty else { return }
        text.append(fragment)
        if text.count > 12_000 {
            text = String(text.suffix(12_000))
        }
    }

    private func appendLog(_ message: String, level: LogLevel = .info) {
        logHandler?(message, level)
    }

    func handleMCPServerReady(mcpServerURL: URL) async {
        lastMCPServerURL = mcpServerURL
        guard autoRunEnabled else { return }
        guard !isSessionActive else { return }
        await startFreshSession(mcpServerURL: mcpServerURL)
    }

    private static func mcpServerLabel(for url: URL) -> String {
        let portSuffix: String
        if let port = url.port {
            portSuffix = "\(port)"
        } else {
            portSuffix = "default"
        }
        return "assistant_whatsapp_\(portSuffix)"
    }
}

private enum LMStudioPromptLoader {
    static let startupInputText = "start assistant job"
    private static let primaryPromptFileName = "Assistant System prompt.md"

    static var sourceDescription: String {
        if let url = findPromptURL(named: primaryPromptFileName) {
            return url.lastPathComponent
        }
        return "Built-in fallback prompt"
    }

    static func startupPromptText() -> String {
        if let url = findPromptURL(named: primaryPromptFileName),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return fallbackPromptText
    }

    private static var fallbackPromptText: String {
        """
        Voce e um assistente executivo local que executa continuamente.

        Sua funcao e manter o trabalho do cliente em movimento com continuidade,
        clareza e execucao.

        Use as ferramentas MCP para agir, atualize o estado local quando preciso e
        aguarde eventos quando nao houver mais nada a fazer.
        """
    }

    private static func findPromptURL(named fileName: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == fileName {
            return url
        }
        return nil
    }
}
