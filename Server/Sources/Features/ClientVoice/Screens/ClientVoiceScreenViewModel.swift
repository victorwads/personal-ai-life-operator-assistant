import SwiftUI

@MainActor
final class ClientVoiceScreenViewModel: ObservableObject {
    @Published private(set) var requests: [ClientInteractionRequest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var initializedRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .initialized }
    }

    var waitingAgentRequests: [ClientInteractionRequest] {
        requests.filter { $0.status == .waitingAgent }
    }

    var historyRequests: [ClientInteractionRequest] {
        requests.filter { [.completed, .cancelled].contains($0.status) }
    }

    private let repository: ClientInteractionRequestRepository
    private let sharedLocks: SharedLockRegistry
    private var listenerToken: FirestoreListenerToken?
    private var hasLoaded = false
    @Published private var responseDrafts: [String: String] = [:]
    @Published private var submissionErrors: [String: String] = [:]
    @Published private var submittingRequestIDs: Set<String> = []

    init(
        repository: ClientInteractionRequestRepository,
        sharedLocks: SharedLockRegistry
    ) {
        self.repository = repository
        self.sharedLocks = sharedLocks
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

    func bindingForResponseDraft(requestID: String?) -> Binding<String> {
        Binding(
            get: {
                guard let requestID else { return "" }
                return self.responseDrafts[requestID] ?? ""
            },
            set: { newValue in
                guard let requestID else { return }
                self.responseDrafts[requestID] = newValue
                self.submissionErrors[requestID] = nil
            }
        )
    }

    func canSubmitResponse(for request: ClientInteractionRequest) -> Bool {
        guard request.status == .initialized, request.kind == .ask, let requestID = request.id else {
            return false
        }

        let draft = responseDrafts[requestID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !draft.isEmpty && !submittingRequestIDs.contains(requestID)
    }

    func submissionError(for requestID: String?) -> String? {
        guard let requestID else { return "This request cannot be updated because it has no saved id yet." }
        return submissionErrors[requestID]
    }

    func isSubmitting(requestID: String?) -> Bool {
        guard let requestID else { return false }
        return submittingRequestIDs.contains(requestID)
    }

    func submitResponse(for request: ClientInteractionRequest) {
        guard request.status == .initialized, request.kind == .ask else { return }
        guard let requestID = request.id else { return }

        let responseText = responseDrafts[requestID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !responseText.isEmpty else {
            submissionErrors[requestID] = "Enter a response before submitting."
            return
        }

        submittingRequestIDs.insert(requestID)
        submissionErrors[requestID] = nil

        Task {
            do {
                _ = try await repository.markWaitingAgent(
                    id: requestID,
                    responseText: responseText,
                    source: .desktop
                )
                await sharedLocks.unlock(id: askLockID(for: requestID))

                await MainActor.run {
                    self.responseDrafts[requestID] = nil
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

    func markSpeakCompleted(_ request: ClientInteractionRequest) {
        guard request.status == .initialized, request.kind == .speak else { return }
        guard let requestID = request.id else { return }

        submittingRequestIDs.insert(requestID)
        submissionErrors[requestID] = nil

        Task {
            do {
                _ = try await repository.markCompleted(id: requestID, source: .desktop)
                await sharedLocks.unlock(id: speakLockID(for: requestID))
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

    private func ensureObservation() {
        guard listenerToken == nil else { return }
        listenerToken = repository.observeRequests { [weak self] requests in
            Task { @MainActor in
                self?.requests = requests
            }
        }
    }

    private func askLockID(for requestID: String) -> String {
        "ask_to_client:\(requestID)"
    }

    private func speakLockID(for requestID: String) -> String {
        "speak_to_client:\(requestID)"
    }
}
