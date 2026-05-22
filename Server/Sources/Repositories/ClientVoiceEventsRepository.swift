import Foundation

actor ClientVoiceEventsRepository {
    static let shared = ClientVoiceEventsRepository()

    private let defaults: UserDefaults
    private let storageKey = "clientVoiceEvents.v1"
    private var pendingWaitersById: [UUID: CheckedContinuation<String, Error>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func list(limit: Int = 200) -> [ClientVoiceEvent] {
        Array(loadAll().sorted { $0.createdAt > $1.createdAt }.prefix(max(1, limit)))
    }

    func pendingAskCount() -> Int {
        loadAll().filter { $0.kind == .ask && $0.askStatus == .pending }.count
    }

    func markPendingAsLost() -> Int {
        var events = loadAll()
        var changedCount = 0

        // Only mark *stale* pending asks as lost. Restarts should not immediately
        // discard pending items; we want a chance to recover drafts.
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for index in events.indices where events[index].kind == .ask && events[index].askStatus == .pending && events[index].createdAt < cutoff {
            events[index].askStatus = .lost
            events[index].draftTranscript = nil
            changedCount += 1
        }

        guard changedCount > 0 else {
            return 0
        }

        persistAll(events)
        return changedCount
    }

    func clearAll() {
        defaults.removeObject(forKey: storageKey)
        NotificationCenter.default.post(name: .clientVoiceEventsRepositoryDidChange, object: nil)
        let waiters = pendingWaitersById
        pendingWaitersById.removeAll()
        waiters.values.forEach { $0.resume(throwing: CancellationError()) }
    }

    func appendSpeak(text: String) -> ClientVoiceEvent {
        var events = loadAll()
        let event = ClientVoiceEvent(
            id: UUID(),
            kind: .speak,
            createdAt: Date(),
            text: text,
            prompt: nil,
            transcript: nil,
            draftTranscript: nil,
            askStatus: nil,
            answeredAt: nil
        )
        events.append(event)
        persistAll(events)
        return event
    }

    func appendAsk(prompt: String) -> ClientVoiceEvent {
        var events = loadAll()
        let event = ClientVoiceEvent(
            id: UUID(),
            kind: .ask,
            createdAt: Date(),
            text: nil,
            prompt: prompt,
            transcript: nil,
            draftTranscript: nil,
            askStatus: .pending,
            answeredAt: nil
        )
        events.append(event)
        persistAll(events)
        return event
    }

    func draftForAsk(id: UUID) -> String? {
        let existing = loadAll().first(where: { $0.id == id })
        let value = (existing?.draftTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func updateAskDraft(id: UUID, draft: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var events = loadAll()
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        var event = events[index]
        guard event.kind == .ask, event.askStatus == .pending else { return }

        event.draftTranscript = trimmed
        events[index] = event
        persistAll(events)
    }

    func answerAsk(id: UUID, response: String) throws -> ClientVoiceEvent {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw NSError(domain: "ClientVoiceEventsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transcript cannot be empty"])
        }

        var events = loadAll()
        guard let index = events.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "ClientVoiceEventsRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }

        var event = events[index]
        guard event.kind == .ask else {
            throw NSError(domain: "ClientVoiceEventsRepository", code: 3, userInfo: [NSLocalizedDescriptionKey: "Not an ask event"])
        }

        event.transcript = trimmed
        event.draftTranscript = nil
        event.askStatus = .answered
        event.answeredAt = Date()
        events[index] = event
        persistAll(events)

        if let waiter = pendingWaitersById.removeValue(forKey: id) {
            waiter.resume(returning: trimmed)
        }

        return event
    }

    func waitForAnswer(id: UUID) async throws -> String {
        let existing = loadAll().first(where: { $0.id == id })
        if let existing, existing.kind == .ask, existing.askStatus == .answered, let transcript = existing.transcript, !transcript.isEmpty {
            return transcript
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingWaitersById[id] = continuation
            }
        } onCancel: {
            Task { await cancelWaiter(id: id) }
        }
    }

    func cancelWaiter(id: UUID) {
        pendingWaitersById.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func loadAll() -> [ClientVoiceEvent] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ClientVoiceEvent].self, from: data)) ?? []
    }

    private func persistAll(_ events: [ClientVoiceEvent]) {
        guard let data = try? JSONEncoder().encode(events) else {
            return
        }
        defaults.set(data, forKey: storageKey)
        NotificationCenter.default.post(name: .clientVoiceEventsRepositoryDidChange, object: nil)
    }
}
