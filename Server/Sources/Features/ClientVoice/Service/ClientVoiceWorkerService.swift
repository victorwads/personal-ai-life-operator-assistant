import Foundation
import Combine

@MainActor
final class ClientVoiceWorkerService: ProfileRuntimeService, @unchecked Sendable {
    typealias SpeakPerformer = @Sendable (String) async throws -> SpeechSpeakHandler
    typealias PresentAskDialog = @MainActor (ClientInteractionRequest, SpeechSpeakHandler) -> Void

    let id: String
    let title: String

    private let repository: ClientInteractionRequestRepository
    private let sharedLocks: SharedLockRegistry
    private let presenceService: ClientVoicePresenceService
    private let speakPerformer: SpeakPerformer
    private let presentAskDialog: PresentAskDialog
    private(set) var state: ProfileRuntimeServiceState = .stopped

    private var listenerToken: FirestoreListenerToken?
    private var presenceCancellable: AnyCancellable?
    private var currentRequests: [ClientInteractionRequest] = []
    private let lock = NSLock()
    private var unlockedLockIds: Set<String> = []
    private var processingRequestIDs: Set<String> = []

    init(
        id: String,
        title: String,
        repository: ClientInteractionRequestRepository,
        sharedLocks: SharedLockRegistry,
        presenceService: ClientVoicePresenceService,
        presentAskDialog: @escaping PresentAskDialog = { _, _ in },
        speakPerformer: @escaping SpeakPerformer = { text in
            try await SpeechSpeaker.speak(text: text)
        }
    ) {
        self.id = id
        self.title = title
        self.repository = repository
        self.sharedLocks = sharedLocks
        self.presenceService = presenceService
        self.speakPerformer = speakPerformer
        self.presentAskDialog = presentAskDialog
    }

    func start() async {
        guard canStart else { return }

        state = .starting
        unlockedLockIds.removeAll()
        processingRequestIDs.removeAll()
        print("ClientVoice worker started")
        presenceCancellable = presenceService.$isPresent.sink { [weak self] isPresent in
            Task { @MainActor in
                self?.handlePresenceChange(isPresent: isPresent)
            }
        }
        listenerToken = repository.observeRequests { [weak self] requests in
            Task { @MainActor in
                self?.handleRequestChange(requests)
            }
        }
        state = .running
    }

    func stop() async {
        guard canStop else { return }

        state = .stopping
        print("ClientVoice worker stopped")
        listenerToken?.cancel()
        listenerToken = nil
        presenceCancellable = nil
        currentRequests = []
        unlockedLockIds.removeAll()
        processingRequestIDs.removeAll()
        state = .stopped
    }

    private func handleRequestChange(_ requests: [ClientInteractionRequest]) {
        guard isActive else { return }
        currentRequests = requests

        for request in requests {
            switch request.status {
            case .waitingAgent:
                handleWaitingAgent(request)
            case .completed:
                handleCompleted(request)
            case .initialized:
                handleInit(request)
            default:
                break
            }
        }
    }

    private func handlePresenceChange(isPresent: Bool) {
        guard isActive, isPresent else { return }
        for request in currentRequests where request.status == .initialized {
            handleInit(request)
        }
    }

    private func handleInit(_ request: ClientInteractionRequest) {
        guard let id = request.id else { return }
        guard presenceService.isPresent else { return }
        guard beginProcessing(requestID: id) else { return }

        Task { @MainActor in
            defer { finishProcessing(requestID: id) }

            do {
                _ = try await repository.markSpeaking(id: id)
                let handler = try await speakPerformer(request.promptText)

                switch request.kind {
                case .speak:
                    await handler.await()
                    _ = try await repository.markCompleted(id: id)
                    unlock(lockId: "speak_to_client:\(id)")
                case .ask:
                    presentAskDialog(request, handler)
                    await handler.await()
                    _ = try await repository.markWaitingUser(id: id)
                }
            } catch {
                handleFailure(message: "Voice Worker failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleWaitingAgent(_ request: ClientInteractionRequest) {
        guard request.kind == .ask, let id = request.id else { return }
        print("ClientVoice worker observed request status \(request.status) for \(id)")

        let lockId = "ask_to_client:\(id)"
        unlock(lockId: lockId)
    }

    private func handleCompleted(_ request: ClientInteractionRequest) {
        guard request.kind == .speak, let id = request.id else { return }
        print("ClientVoice worker observed request status \(request.status) for \(id)")

        let lockId = "speak_to_client:\(id)"
        unlock(lockId: lockId)
    }

    private func unlock(lockId: String) {
        lock.lock()
        let isAlreadyUnlocked = unlockedLockIds.contains(lockId)
        if !isAlreadyUnlocked {
            unlockedLockIds.insert(lockId)
        }
        lock.unlock()

        if isAlreadyUnlocked {
            print("ClientVoice worker skipping already unlocked lock \(lockId)")
            return
        }

        print("ClientVoice worker unlocking \(lockId)")

        Task {
            await sharedLocks.unlock(id: lockId)
        }
    }

    private func beginProcessing(requestID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let inserted = processingRequestIDs.insert(requestID).inserted
        return inserted
    }

    private func finishProcessing(requestID: String) {
        lock.lock()
        processingRequestIDs.remove(requestID)
        lock.unlock()
    }

    private var canStart: Bool {
        switch state {
        case .stopped, .failed:
            return true
        case .starting, .running, .stopping:
            return false
        }
    }

    private var canStop: Bool {
        switch state {
        case .starting, .running:
            return true
        case .stopped, .stopping, .failed:
            return false
        }
    }

    private var isActive: Bool {
        switch state {
        case .starting, .running:
            return true
        case .stopped, .stopping, .failed:
            return false
        }
    }

    private func handleFailure(message: String) {
        listenerToken?.cancel()
        listenerToken = nil
        state = .failed(message)
    }
}
