import Foundation

@MainActor
final class WhatsAppCrawlingPollingService: ObservableObject, WhatsAppCrawlingService {
    private let profileId: String
    private let settings: WhatsAppCrawlingSettingsWrapper
    private weak var webViewService: WebViewWhatsAppCrawlingService?
    private let logStore: WhatsAppCrawlingLogStore
    private let orchestrator: WhatsAppChatCrawlingOrchestrator

    private var pollingTask: Task<Void, Never>?
    private var completedCycleCount = 0

    // TODO: Replace `[String]` with `Set<String>` or a typed pause token.
    // Current array-based pause tracking allows duplicate reasons and fallback removal
    // may resume the wrong caller if reasons get out of sync.
    private var pauseReasons: [String] = []

    @Published private(set) var state: WhatsAppCrawlingServiceState = .stopped
    @Published private(set) var statusText: String? = "Stopped"

    let activeIntegration: WhatsAppCrawlingActiveIntegration = .webView

    // TODO: Revisit this protocol requirement.
    // This service is clearly WebView-based, but `integration` always returns nil.
    // Either the protocol is carrying legacy abstraction, or this should expose a real integration.
    var integration: (any WhatsAppCrawlingIntegration)? { nil }

    init(
        profileId: String,
        settings: WhatsAppCrawlingSettingsWrapper,
        webViewService: WebViewWhatsAppCrawlingService,
        chatRepositoryProvider: @escaping @MainActor () -> any ChatRepository,
        aiImageExtractorProvider: @escaping @MainActor () -> (any AIImageExtracting)?,
        audioTranscriptionServiceProvider: @escaping @MainActor () -> WhatsAppAudioTranscriptionService,
        logStore: WhatsAppCrawlingLogStore,
        sharedLocks: SharedLockRegistry
    ) throws {
        self.profileId = profileId
        self.settings = settings

        // TODO: Revisit ownership.
        // If polling cannot work without WebViewWhatsAppCrawlingService, `weak` may hide lifecycle bugs
        // by turning the loop into "Waiting for WebView" forever.
        self.webViewService = webViewService

        self.logStore = logStore

        let yamlText = try WebYAMLSelectorLoader.loadBundledYAML()
        self.orchestrator = WhatsAppChatCrawlingOrchestrator(
            profileId: profileId,
            chatRepositoryProvider: chatRepositoryProvider,
            permissionModeProvider: { settings.chatPermissionMode },
            aiImageExtractorProvider: aiImageExtractorProvider,
            audioTranscriptionServiceProvider: audioTranscriptionServiceProvider,
            yamlText: yamlText,
            logStore: logStore,
            sharedLocks: sharedLocks
        )
    }

    func start() async {
        guard state == .stopped || isFailed else { return }

        if state == .stopped {
            completedCycleCount = 0
        }

        state = .starting
        statusText = "Starting"

        logStore.append(source: "Polling", "Started profile=\(profileId)")
        logStore.append(source: "Polling", "Auto-start/manual start reached")

        orchestrator.setStatusUpdateHandler { [weak self] status in
            Task { @MainActor [weak self] in
                self?.statusText = status
            }
        }

        // TODO: Extract this polling loop into private methods.
        // This method currently mixes lifecycle, pause handling, WebView lookup,
        // orchestration, logging, sleep, and status updates in one large block.
        //
        // Suggested future split:
        // - runPollingLoop()
        // - runPollingCycle()
        // - waitForNextCycle()
        // - updateStatus(_:)
        // - appendLog(source:_:)
        pollingTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.state = .started
                self.statusText = "Started"
            }

            while !Task.isCancelled {
                let shouldPause = await MainActor.run {
                    self.state == .started && !self.pauseReasons.isEmpty
                }

                if shouldPause {
                    await MainActor.run { self.statusText = "Paused" }

                    // TODO: Do not swallow cancellation silently.
                    // Prefer `do/catch` and break on cancellation so loop shutdown is explicit.
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue
                }

                if let webView = await MainActor.run(body: { self.webViewService?.webView }) {
                    await MainActor.run { self.statusText = "Starting cycle" }

                    // TODO: Reduce log noise or guard cycle-level logs behind a debug setting.
                    // This loop can generate a lot of repetitive logs over time.
                    await MainActor.run {
                        self.logStore.append(source: "Polling", "WebView available")
                        self.logStore.append(source: "Polling", "Cycle started")
                    }

                    let result = await orchestrator.runCycle(
                        in: webView,
                        completedCycleCount: await MainActor.run { self.completedCycleCount },
                        shouldContinue: { [weak self] in
                            guard let self else { return false }
                            return self.state == .started
                                && self.pauseReasons.isEmpty
                                && !(self.pollingTask?.isCancelled ?? false)
                        }
                    )

                    switch result {
                    case .success:
                        await MainActor.run { self.statusText = "Cycle finished" }
                        await MainActor.run {
                            self.logStore.append(source: "Polling", "Cycle success")
                        }

                    case .failure(let error):
                        // TODO: Decide whether repeated cycle failures should move service state to `.failed`.
                        // Today failures only update statusText/logs, so `isFailed` may never become useful.
                        await MainActor.run {
                            self.statusText = "Failed: \(error.localizedDescription)"
                            self.logStore.append(source: "Error", "Cycle failed: \(error.localizedDescription)")
                        }
                    }

                    await MainActor.run { self.completedCycleCount += 1 }
                } else {
                    await MainActor.run { self.statusText = "Waiting for WebView" }
                    await MainActor.run {
                        self.logStore.append(source: "Polling", "Waiting for WebView")
                    }
                }

                let intervalSeconds = await MainActor.run {
                    max(1, self.settings.pollingIntervalSeconds)
                }

                await MainActor.run { self.statusText = "Sleeping \(intervalSeconds)s" }
                await MainActor.run {
                    self.logStore.append(source: "Polling", "Sleeping \(intervalSeconds)s")
                }

                // TODO: Do not swallow cancellation silently.
                // Prefer a helper like `sleep(seconds:) -> Bool` returning false on cancellation.
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
            }

            await MainActor.run { self.statusText = "Stopped" }
            await MainActor.run {
                self.logStore.append(source: "Polling", "Stopped/cancelled")
            }
        }
    }

    func stop() async {
        guard state == .started || state == .starting || isFailed else { return }

        state = .stopping
        pollingTask?.cancel()
        pollingTask = nil

        // TODO: If pause reasons become typed tokens, stopping should invalidate all outstanding tokens.
        pauseReasons.removeAll()

        state = .stopped
        statusText = "Stopped"
        logStore.append(source: "Polling", "Stopped")
    }

    func pauseCrawling(reason: String) async {
        guard state == .started else { return }

        // TODO: Replace append with token/set semantics.
        // Repeated calls with the same reason currently create multiple pauses.
        pauseReasons.append(reason)

        statusText = "Paused"
        logStore.append(source: "Polling", "Paused reason=\(reason)")
    }

    func resumeCrawling(reason: String) async {
        guard !pauseReasons.isEmpty else { return }

        // TODO: Avoid fallback `removeLast()`.
        // If a caller resumes with a reason that was not registered, this may release another caller's pause.
        // Prefer strict removal from Set<Token> or log/ignore unknown resume requests.
        if let index = pauseReasons.lastIndex(of: reason) {
            pauseReasons.remove(at: index)
        } else {
            pauseReasons.removeLast()
        }

        if pauseReasons.isEmpty, state == .started {
            statusText = "Started"
        }

        logStore.append(source: "Polling", "Resumed reason=\(reason) remainingPauses=\(pauseReasons.count)")
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}
