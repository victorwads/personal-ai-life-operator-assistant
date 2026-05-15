import Foundation

actor ClientVoiceEventsRepository {
    static let shared = ClientVoiceEventsRepository()

    private let defaults: UserDefaults
    private let storageKey = "clientVoiceEvents.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func list(limit: Int = 200) -> [ClientVoiceEvent] {
        Array(loadAll().sorted { $0.createdAt > $1.createdAt }.prefix(max(1, limit)))
    }

    func pendingAskCount() -> Int {
        loadAll().filter { $0.kind == .ask && $0.askStatus == .pending }.count
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
            askStatus: .pending,
            answeredAt: nil
        )
        events.append(event)
        persistAll(events)
        return event
    }

    func answerAsk(id: UUID, transcript: String) throws -> ClientVoiceEvent {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
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
        event.askStatus = .answered
        event.answeredAt = Date()
        events[index] = event
        persistAll(events)
        return event
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
    }
}

