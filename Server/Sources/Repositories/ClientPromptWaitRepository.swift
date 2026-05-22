import Foundation

actor ClientPromptWaitRepository {
    static let shared = ClientPromptWaitRepository()

    private struct PromptEntry: Codable, Equatable {
        let id: UUID
        let createdAt: Date
        let text: String
    }

    private var activeWaitIDs: Set<UUID> = []

    private let defaults: UserDefaults
    private let queueStorageKey = "clientPromptQueue.v1"
    private let draftStorageKey = "clientPromptDraft.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func beginWait() -> UUID {
        let id = UUID()
        activeWaitIDs.insert(id)
        return id
    }

    func endWait(id: UUID) {
        activeWaitIDs.remove(id)
    }

    func pendingWaitCount() -> Int {
        // Keep the badge visible if we have a queued prompt even when no wait is active.
        let queued = queuedPromptCount()
        return max(activeWaitIDs.count, queued > 0 ? 1 : 0)
    }

    func submitPrompt(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        enqueuePrompt(trimmed)
        clearDraft()
    }

    func consumePrompt() -> String? {
        dequeuePrompt()
    }

    // MARK: - Draft (hands-free prompt window)

    func setDraft(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Don't clear draft on empty partials; caller can explicitly clear.
            return
        }
        defaults.set(trimmed, forKey: draftStorageKey)
    }

    func getDraft() -> String? {
        let value = (defaults.string(forKey: draftStorageKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func clearDraft() {
        defaults.removeObject(forKey: draftStorageKey)
    }

    // MARK: - Queue (durable client prompts)

    func queuedPromptCount() -> Int {
        loadQueue().count
    }

    private func enqueuePrompt(_ text: String) {
        var queue = loadQueue()
        queue.append(PromptEntry(id: UUID(), createdAt: Date(), text: text))
        persistQueue(queue)
    }

    private func dequeuePrompt() -> String? {
        var queue = loadQueue()
        guard !queue.isEmpty else { return nil }
        let first = queue.removeFirst()
        persistQueue(queue)
        return first.text
    }

    private func loadQueue() -> [PromptEntry] {
        guard let data = defaults.data(forKey: queueStorageKey) else { return [] }
        return (try? JSONDecoder().decode([PromptEntry].self, from: data)) ?? []
    }

    private func persistQueue(_ queue: [PromptEntry]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        defaults.set(data, forKey: queueStorageKey)
    }
}
