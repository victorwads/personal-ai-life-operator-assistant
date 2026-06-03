import Foundation

struct SharedLockEvent: Sendable, Equatable {
    enum Kind: String, Sendable {
        case locked
        case unlocked
    }

    let kind: Kind
    let id: String
}

actor SharedLockRegistry {
    private struct SharedLockState {
        let id: String
        var waiters: [UUID: WaiterState] = [:]
    }

    private enum WaiterState {
        case pending
        case waiting(CheckedContinuation<Void, Error>)
    }

    private enum DeferredResolution {
        case unlocked
        case cancelled
    }

    private var locks: [String: SharedLockState] = [:]
    private var deferredResolutions: [UUID: DeferredResolution] = [:]
    private var eventListeners: [UUID: AsyncStream<SharedLockEvent>.Continuation] = [:]

    func lockAndWait(id: String) async throws {
        try Task.checkCancellation()

        let waiterID = UUID()
        registerWaiter(id: id, waiterID: waiterID)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await attachContinuation(
                        id: id,
                        waiterID: waiterID,
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: id, waiterID: waiterID)
            }
        }
    }

    func unlock(id: String) {
        guard let state = locks.removeValue(forKey: id) else {
            debugLog("unlock no-op for inactive lock '\(id)'")
            return
        }

        for (waiterID, waiter) in state.waiters {
            switch waiter {
            case .pending:
                deferredResolutions[waiterID] = .unlocked
            case let .waiting(continuation):
                continuation.resume()
            }
        }

        broadcast(.init(kind: .unlocked, id: id))
        debugLog("unlocked '\(id)' and resumed \(state.waiters.count) waiter(s)")
    }

    func isLocked(id: String) -> Bool {
        locks[id] != nil
    }

    func activeLockIDs() -> [String] {
        locks.keys.sorted()
    }

    func events() -> AsyncStream<SharedLockEvent> {
        let listenerID = UUID()

        return AsyncStream { continuation in
            addEventListener(continuation, listenerID: listenerID)

            continuation.onTermination = { _ in
                Task {
                    await self.removeEventListener(listenerID: listenerID)
                }
            }
        }
    }

    private func registerWaiter(id: String, waiterID: UUID) {
        let wasLocked = locks[id] != nil
        var state = locks[id] ?? SharedLockState(id: id)
        state.waiters[waiterID] = .pending
        locks[id] = state
        debugLog("registered waiter \(waiterID) for '\(id)'")

        if !wasLocked {
            broadcast(.init(kind: .locked, id: id))
        }
    }

    private func attachContinuation(
        id: String,
        waiterID: UUID,
        continuation: CheckedContinuation<Void, Error>
    ) {
        if let resolution = deferredResolutions.removeValue(forKey: waiterID) {
            resume(continuation, with: resolution)
            return
        }

        guard var state = locks[id], let waiter = state.waiters[waiterID] else {
            assertionFailure("SharedLockRegistry lost waiter \(waiterID) for lock '\(id)' before continuation attachment.")
            continuation.resume()
            return
        }

        switch waiter {
        case .pending:
            state.waiters[waiterID] = .waiting(continuation)
            locks[id] = state
            debugLog("attached continuation for waiter \(waiterID) on '\(id)'")
        case .waiting:
            assertionFailure("SharedLockRegistry attempted to attach the same waiter twice for lock '\(id)'.")
            continuation.resume()
        }
    }

    private func cancelWaiter(id: String, waiterID: UUID) {
        guard var state = locks[id] else {
            deferredResolutions[waiterID] = deferredResolutions[waiterID] ?? .cancelled
            return
        }

        guard let waiter = state.waiters.removeValue(forKey: waiterID) else {
            deferredResolutions[waiterID] = deferredResolutions[waiterID] ?? .cancelled
            return
        }

        locks[id] = state

        switch waiter {
        case .pending:
            deferredResolutions[waiterID] = .cancelled
        case let .waiting(continuation):
            continuation.resume(throwing: CancellationError())
        }

        debugLog("cancelled waiter \(waiterID) for '\(id)'")
    }

    private func addEventListener(
        _ continuation: AsyncStream<SharedLockEvent>.Continuation,
        listenerID: UUID
    ) {
        eventListeners[listenerID] = continuation
        debugLog("added event listener \(listenerID)")
    }

    private func removeEventListener(listenerID: UUID) {
        guard eventListeners.removeValue(forKey: listenerID) != nil else { return }
        debugLog("removed event listener \(listenerID)")
    }

    private func broadcast(_ event: SharedLockEvent) {
        for continuation in eventListeners.values {
            continuation.yield(event)
        }

        debugLog("broadcast event '\(event.kind.rawValue)' for '\(event.id)' to \(eventListeners.count) listener(s)")
    }

    private func resume(
        _ continuation: CheckedContinuation<Void, Error>,
        with resolution: DeferredResolution
    ) {
        switch resolution {
        case .unlocked:
            continuation.resume()
        case .cancelled:
            continuation.resume(throwing: CancellationError())
        }
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("SharedLockRegistry: \(message)")
#endif
    }
}
