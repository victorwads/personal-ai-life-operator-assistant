import Foundation

@MainActor
final class ClientVoiceAskDialogViewModel: ObservableObject {
    @Published var responseText: String = ""
    @Published private(set) var isSpeaking = true
    @Published private(set) var isListening = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?

    let promptText: String

    var askSendMode: ClientVoiceAskSendMode {
        settings.askSendMode
    }

    var dismissActionTitle: String {
        dismissActionTitleProvider()
    }

    private let repository: ClientInteractionRequestRepository
    private let request: ClientInteractionRequest
    private let speakHandler: SpeechSpeakHandler
    private let listenProvider: ListenProvider?
    private let listenConfig: ListenConfig
    private let settings: ClientVoiceSettingsWrapper
    private let dismissActionTitleProvider: () -> String
    private let onSubmitSuccess: @MainActor () async -> Void
    private let onCloseWithoutResponse: @MainActor () async -> Void
    private let closeWindow: @MainActor () -> Void

    private var listener: ListenHandler?
    private var hasStarted = false
    private var hasFinished = false

    init(
        repository: ClientInteractionRequestRepository,
        request: ClientInteractionRequest,
        speakHandler: SpeechSpeakHandler,
        listenProvider: ListenProvider?,
        listenConfig: ListenConfig = .init(),
        settings: ClientVoiceSettingsWrapper,
        dismissActionTitleProvider: @escaping () -> String,
        onSubmitSuccess: @escaping @MainActor () async -> Void,
        onCloseWithoutResponse: @escaping @MainActor () async -> Void,
        closeWindow: @escaping @MainActor () -> Void
    ) {
        self.repository = repository
        self.request = request
        self.speakHandler = speakHandler
        self.listenProvider = listenProvider
        self.listenConfig = listenConfig
        self.settings = settings
        self.dismissActionTitleProvider = dismissActionTitleProvider
        self.onSubmitSuccess = onSubmitSuccess
        self.onCloseWithoutResponse = onCloseWithoutResponse
        self.closeWindow = closeWindow
        self.promptText = request.promptText
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await speakHandler.await()
            guard !hasFinished else { return }

            isSpeaking = false
            guard let listenProvider else { return }

            do {
                let listener = try await SpeechListener.listen(
                    provider: listenProvider,
                    config: listenConfig
                )
                self.listener = listener
                isListening = true

                listener.onPartial { [weak self] text in
                    self?.responseText = text
                }
                listener.onFinal { [weak self] text in
                    self?.responseText = text
                    if self?.settings.askSendMode == .handsFree {
                        self?.submit(autoText: text)
                    } else {
                        self?.isSpeaking = false
                        self?.isListening = false
                    }
                }
            } catch {
                isListening = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func submit() {
        submit(autoText: nil)
    }

    func toggleAskSendMode(_ mode: ClientVoiceAskSendMode) {
        settings.askSendMode = mode
    }

    func cancelListening() {
        listener?.cancel()
        listener = nil
        isListening = false
    }

    func dismissWithoutResponse() {
        Task {
            await prepareForCloseWithoutResponse()
            closeWindow()
        }
    }

    func handleSystemClose() {
        Task {
            await prepareForCloseWithoutResponse()
        }
    }

    private func submit(autoText: String?) {
        guard !isSubmitting, !hasFinished else { return }
        guard let requestID = request.id else {
            errorMessage = "This request cannot be submitted because it has no saved id yet."
            return
        }

        let rawText = autoText ?? responseText
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = "Enter a response before submitting."
            return
        }

        isSubmitting = true
        errorMessage = nil
        hasFinished = true
        speakHandler.cancel()
        cancelListening()

        Task {
            do {
                _ = try await repository.markWaitingAgent(
                    id: requestID,
                    responseText: trimmedText
                )
                await onSubmitSuccess()
                closeWindow()
            } catch {
                isSubmitting = false
                hasFinished = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareForCloseWithoutResponse() async {
        guard !hasFinished else { return }
        hasFinished = true
        speakHandler.cancel()
        cancelListening()
        await onCloseWithoutResponse()
    }
}
