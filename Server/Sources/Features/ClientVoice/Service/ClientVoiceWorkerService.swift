import Foundation

final class ClientVoiceWorkerService: @unchecked Sendable {
    private let repository: ClientInteractionRequestRepository
    private let sharedLocks: SharedLockRegistry
    
    private var listenerToken: FirestoreListenerToken?
    private let lock = NSLock()
    private var unlockedLockIds: Set<String> = []
    
    init(repository: ClientInteractionRequestRepository, sharedLocks: SharedLockRegistry) {
        self.repository = repository
        self.sharedLocks = sharedLocks
    }
    
    func start() {
        print("ClientVoice worker started")
        listenerToken = repository.observeRequests { [weak self] requests in
            self?.handleRequestChange(requests)
        }
    }
    
    func stop() {
        print("ClientVoice worker stopped")
        listenerToken?.cancel()
        listenerToken = nil
    }
    
    private func handleRequestChange(_ requests: [ClientInteractionRequest]) {
        for request in requests { 
            switch request.status {
            case .waitingAgent:
                handleWaitingAgent(request)
            case .completed:
                handleCompleted(request)
            case .initialized:
                handleInit(request)
            default:
                // No action for initialized. Optional for cancelled.
                break
            }
        }
    }
    
    private func handleInit(_ request: ClientInteractionRequest) {
        guard let id = request.id else { return }
        if (request.kind == .speak) {
            Task {
                _ = try await repository.markSpeaking(id: id)

                let handler = try await SpeechSpeaker.speak(text: request.promptText)
                await handler.await()

                let lockId = "speak_to_client:\(id)"
                unlock(lockId: lockId)

                _ = try await repository.markCompleted(id: id)
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
}
