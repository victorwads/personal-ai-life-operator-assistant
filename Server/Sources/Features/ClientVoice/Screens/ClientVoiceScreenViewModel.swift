import SwiftUI

@MainActor
final class ClientVoiceScreenViewModel: ObservableObject {
    @Published private(set) var requests: [ClientInteractionRequest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var creationErrorMessage: String?
    @Published private(set) var isCreatingRequest = false

    var initializedRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .initialized }
    }

    var waitingAgentRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .waitingAgent }
    }

    var speakingRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .speaking }
    }

    var waitingUserRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .waitingUser }
    }

    var historyRequests: [ClientInteractionRequest] {
        requests.filter { [.completed, .cancelled].contains($0.status) }
    }

    private let repository: ClientInteractionRequestRepository
    private let createManualRequestAction: @MainActor () async throws -> Void
    private var listenerToken: FirestoreListenerToken?
    private var hasLoaded = false
    @Published private var submissionErrors: [String: String] = [:]
    @Published private var submittingRequestIDs: Set<String> = []
    @Published private(set) var speakingRequestID: String? = nil
    private var speakingHandler: SpeechSpeakHandler? = nil


    init(
        repository: ClientInteractionRequestRepository,
        createManualRequestAction: @escaping @MainActor () async throws -> Void
    ) {
        self.repository = repository
        self.createManualRequestAction = createManualRequestAction
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        refresh()
    }

    func refresh() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                requests = try await repository.listRequests()
                hasLoaded = true
                isLoading = false
                ensureObservation()
            } catch {
                errorMessage = error.localizedDescription
                requests = []
                isLoading = false
            }
        }
    }

    func submissionError(for requestID: String?) -> String? {
        guard let requestID else { return "This request cannot be updated because it has no saved id yet." }
        return submissionErrors[requestID]
    }

    func isSubmitting(requestID: String?) -> Bool {
        guard let requestID else { return false }
        return submittingRequestIDs.contains(requestID)
    }

    func markSpeakCompleted(_ request: ClientInteractionRequest) {
        guard request.status == .initialized, request.kind == .speak else { return }
        guard let requestID = request.id else { return }

        submittingRequestIDs.insert(requestID)
        submissionErrors[requestID] = nil

        Task {
            do {
                _ = try await repository.markCompleted(id: requestID)
                await MainActor.run {
                    self.submissionErrors[requestID] = nil
                    self.submittingRequestIDs.remove(requestID)
                }
            } catch {
                await MainActor.run {
                    self.submissionErrors[requestID] = error.localizedDescription
                    self.submittingRequestIDs.remove(requestID)
                }
            }
        }
    }

    func speakRequest(_ request: ClientInteractionRequest) {
        guard let requestID = request.id else { return }
        let textToSpeak = request.promptText
        Task {
            if let oldHandler = self.speakingHandler {
                oldHandler.cancel()
            }
            let handler = try await SpeechSpeaker.speak(text: textToSpeak, config: nil)
            speakingHandler = handler
            
            await MainActor.run { self.speakingRequestID = requestID }
            await handler.await()
            await MainActor.run {
                if (self.speakingRequestID == requestID ) {
                    self.speakingRequestID = nil
                }
            }
        }
    }

    func createManualRequest() {
        guard !isCreatingRequest else { return }

        creationErrorMessage = nil
        isCreatingRequest = true

        Task {
            do {
                try await createManualRequestAction()
                await MainActor.run {
                    self.creationErrorMessage = nil
                    self.isCreatingRequest = false
                }
            } catch {
                await MainActor.run {
                    self.creationErrorMessage = error.localizedDescription
                    self.isCreatingRequest = false
                }
            }
        }
    }

    private func ensureObservation() {
        guard listenerToken == nil else { return }
        listenerToken = repository.observeRequests { [weak self] requests in
            Task { @MainActor in
                self?.requests = requests
            }
        }
    }
}
